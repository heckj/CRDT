//
//  ORSetTests.swift
//

@testable import CRDT
import XCTest

final class ORSetTests: XCTestCase {
    var a: ORSet<String, Int>!
    var b: ORSet<String, Int>!

    override func setUp() async throws {
        a = ORSet(actorId: "a", [1])
        b = ORSet(actorId: "b", [1, 99, 100, 101])
    }

    func testInitialCreation() {
        XCTAssertEqual(a.values.count, 1)
        XCTAssertEqual(a.currentTimestamp.actorId, "a")
        XCTAssertEqual(a.currentTimestamp.clock, 1)
        XCTAssertEqual(a.count, 1)

        XCTAssertEqual(b.count, 4)
        XCTAssertTrue(b.contains(101))
    }

    func testSettingValue() {
        a.insert(2)
        XCTAssertEqual(a.values, [1, 2])
        a.insert(3)
        XCTAssertEqual(a.values, [1, 2, 3])
    }

    func testRemovingValue() {
        var result: Bool
        result = a.insert(2)
        XCTAssertEqual(a.values, [1, 2])
        XCTAssertTrue(result)

        result = a.insert(3)
        XCTAssertTrue(result)
        XCTAssertEqual(a.values, [1, 2, 3])

        let oldValue = a.remove(1)
        XCTAssertEqual(a.values, [2, 3])
        XCTAssertNotNil(oldValue)
        XCTAssertEqual(oldValue, 1)

        let anotherOldValue = a.remove(1)
        XCTAssertEqual(a.values, [2, 3])
        XCTAssertNil(anotherOldValue)
    }

    func testCount() {
        XCTAssertEqual(b.count, 4)
    }

    func testContains() {
        XCTAssertTrue(b.contains(101))
        XCTAssertFalse(b.contains(5))
    }

    func testMergeOfInitiallyUnrelated() {
        let c = a.merged(with: b)
        XCTAssertEqual(c.values, b.values)
    }

    func testIdempotency() {
        a.insert(1)
        let c = a.merged(with: b)
        let d = c.merged(with: b)
        let e = c.merged(with: a)
        XCTAssertEqual(c.values, d.values)
        XCTAssertEqual(c.values, e.values)
    }

    func testCommutativity() {
        let c = a.merged(with: b)
        let d = b.merged(with: a)
        XCTAssertEqual(d.values, c.values)
    }

    func testAssociativity() {
        let c = ORSet(actorId: "c", [200, 300, 400])
        let e = a.merged(with: b).merged(with: c)
        let f = a.merged(with: b.merged(with: c))
        XCTAssertEqual(e.values, f.values)
    }

    func testCodable() {
        let data = try! JSONEncoder().encode(b)
        let d = try! JSONDecoder().decode(ORSet<String, Int>.self, from: data)
        XCTAssertEqual(b, d)
    }

    func testDeltaState_state() async {
        let state = await a.state
        XCTAssertNotNil(state)
        XCTAssertEqual(Array(state.maxClockValueByActor.keys), [a.currentTimestamp.actorId])
        XCTAssertEqual(Array(state.maxClockValueByActor.values), [a.currentTimestamp.clock])
    }

    func testDeltaState_nilDelta() async {
        let a_nil_delta = await a.delta(nil)
        // print(a_nil_delta)
        XCTAssertNotNil(a_nil_delta)
        XCTAssertEqual(a_nil_delta.updates.count, 1)
        XCTAssertEqual(a_nil_delta.updates, a.metadataByValue)
    }

    func testDeltaState_delta() async {
        let a_delta = await a.delta(b.state)
        XCTAssertEqual(a_delta.updates.count, 1)
        XCTAssertEqual(a_delta.updates, a.metadataByValue)
    }

    func testDeltaState_mergeDeltas() async throws {
        // equiv direct merge
        // let c = a.merged(with: b)
        let delta = await b.delta(a.state)
        let c = try await a.mergeDelta(delta)
        XCTAssertEqual(c.values, b.values)
    }

    func testDeltaState_mergeDelta() async throws {
        // equiv direct merge
        // let c = a.merged(with: b)
        let delta = await b.delta(a.state)
        let c = try await a.mergeDelta(delta)
        XCTAssertEqual(c.values, b.values)
    }

    func testUnrelatedMerges() async throws {
        let orset_1 = ORSet(actorId: UInt(31), [1, 2, 3, 4])
        let orset_2 = ORSet(actorId: UInt(13), [5, 6])

        let diff_a = await orset_1.delta(await orset_2.state)
        // diff_a is the delta from set 1
        XCTAssertNotNil(diff_a)
        XCTAssertEqual(diff_a.updates.count, 4)

        let diff_b = await orset_2.delta(await orset_1.state)
        // diff_b is the delta from set 2
        XCTAssertNotNil(diff_b)
        XCTAssertEqual(diff_b.updates.count, 2)

        // merge the diff from set 1 into set 2
        let mergedFrom1 = try await orset_2.mergeDelta(diff_a)
        XCTAssertEqual(mergedFrom1.count, 6)

        // merge the diff from set 2 into set 1
        let mergedFrom2 = try await orset_1.mergeDelta(diff_b)
        XCTAssertEqual(mergedFrom2.count, 6)

        XCTAssertEqual(mergedFrom1.values, mergedFrom2.values)
    }

    func testConflictingUnrelatedMerges() async throws {
        let orset_1 = ORSet(actorId: UInt(31), [1, 2, 3])
        let orset_2 = ORSet(actorId: UInt(13), [3, 4])
        // the metadata for the entry for `3` is going to be in conflict.

        let diff_a = await orset_1.delta(await orset_2.state)
        // diff_a is the delta from set 1
        XCTAssertNotNil(diff_a)
        XCTAssertEqual(diff_a.updates.count, 3)

        let diff_b = await orset_2.delta(await orset_1.state)
        // diff_b is the delta from set 2
        XCTAssertNotNil(diff_b)
        XCTAssertEqual(diff_b.updates.count, 2)

        // merge the diff from set 1 into set 2

        do {
            let mergedFrom1 = try await orset_2.mergeDelta(diff_a)
            XCTAssertEqual(mergedFrom1.count, 4)
        } catch CRDTMergeError.conflictingHistory(_) {
            // print("error: \(msg)")
            XCTFail("When merging set 1 into set 2, the value `3` should have a higher lamport timestamp, so it should merge cleanly")
        }

        // merge the diff from set 2 into set 1
        do {
            let _ = try await orset_1.mergeDelta(diff_b)
            XCTFail("The merge didn't catch and throw on a failure due to conflicting lamport timestamps for the value `3`.")
        } catch let CRDTMergeError.conflictingHistory(msg) {
            // print("error: \(msg)")
            XCTAssertNotNil(msg)
        }
    }
}
