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
        let state = a.state
        XCTAssertNotNil(state)
        XCTAssertEqual(Array(state.maxClockValueByActor.keys), [a.currentTimestamp.actorId])
        XCTAssertEqual(Array(state.maxClockValueByActor.values), [a.currentTimestamp.clock])
    }

    func testDeltaState_nilDelta() async {
        let a_nil_delta = a.delta(nil)
        // print(a_nil_delta)
        XCTAssertNotNil(a_nil_delta)
        XCTAssertEqual(a_nil_delta.updates.count, 1)
        XCTAssertEqual(a_nil_delta.updates, a.metadataByValue)
    }

    func testDeltaState_delta() async {
        let a_delta = a.delta(b.state)
        XCTAssertEqual(a_delta.updates.count, 1)
        XCTAssertEqual(a_delta.updates, a.metadataByValue)
    }

    func testDeltaState_mergeDeltas() async throws {
        // equiv direct merge
        // let c = a.merged(with: b)
        let delta = b.delta(a.state)
        let c = try a.mergeDelta(delta)
        XCTAssertEqual(c.values, b.values)
    }

    func testDeltaState_mergeDelta() async throws {
        // equiv direct merge
        // let c = a.merged(with: b)
        let delta = b.delta(a.state)
        let c = try a.mergeDelta(delta)
        XCTAssertEqual(c.values, b.values)
    }

    func testUnrelatedMerges() async throws {
        let orset_1 = ORSet(actorId: UInt(31), [1, 2, 3, 4])
        let orset_2 = ORSet(actorId: UInt(13), [5, 6])

        let diff_a = orset_1.delta(orset_2.state)
        // diff_a is the delta from set 1
        XCTAssertNotNil(diff_a)
        XCTAssertEqual(diff_a.updates.count, 4)

        let diff_b = orset_2.delta(orset_1.state)
        // diff_b is the delta from set 2
        XCTAssertNotNil(diff_b)
        XCTAssertEqual(diff_b.updates.count, 2)

        // merge the diff from set 1 into set 2
        let mergedFrom1 = try orset_2.mergeDelta(diff_a)
        XCTAssertEqual(mergedFrom1.count, 6)

        // merge the diff from set 2 into set 1
        let mergedFrom2 = try orset_1.mergeDelta(diff_b)
        XCTAssertEqual(mergedFrom2.count, 6)

        XCTAssertEqual(mergedFrom1.values, mergedFrom2.values)
    }

    func testPreviousUnsyncedMergeWithConflictingMetadata() async throws {
        let orset_1 = ORSet(actorId: UInt(31), [1, 2, 3])
        var orset_2 = ORSet(actorId: UInt(13), [3, 4])
        orset_2.remove(3)
        // the metadata for the entry for `3` is going to be in conflict, both by
        // Lamport timestamps ('2' vs '3') and the metadata in question (deleted vs not)

        let diff_a = orset_1.delta(orset_2.state)
        // diff_a is the delta from set 1
        XCTAssertNotNil(diff_a)
        XCTAssertEqual(diff_a.updates.count, 3)

        let diff_b = orset_2.delta(orset_1.state)
        // diff_b is the delta from set 2
        XCTAssertNotNil(diff_b)
        XCTAssertEqual(diff_b.updates.count, 2)

        // merge the diff from set 1 into set 2

        do {
            let result = try orset_2.mergeDelta(diff_a)
            XCTAssertEqual(result.count, 4)
        } catch CRDTMergeError.conflictingHistory(_) {
            XCTFail("When merging set 1 into set 2, the value `3` should has a higher Lamport timestamp, so it should merge cleanly")
        }

        // merge the diff from set 2 into set 1

        do {
            let result = try orset_1.mergeDelta(diff_b)
            XCTAssertEqual(result.count, 4)
        } catch CRDTMergeError.conflictingHistory(_) {
            XCTFail("The merge didn't catch and throw on a failure due to conflicting Lamport timestamps for the value `3`.")
        }
    }

    func testCorruptedHistoryMerge() async throws {
        // actor id's intentionally identical, but with different data inside them,
        // which *shouldn't* happen in practice, but this represents a throwing case
        // I wanted to get correctly established.
        let orset_1 = ORSet(actorId: UInt(13), [1, 2, 3])
        var orset_2 = ORSet(actorId: UInt(13), [3, 4])
        orset_2.remove(3)

        // The state's alone _won't_ show any changes, as the state
        // doesn't have any detail about the *content*.

        let diff_a = orset_1.delta(orset_2.state)
        // diff_a is the delta from map 1
        XCTAssertNotNil(diff_a)
        XCTAssertEqual(diff_a.updates.count, 0)

        let diff_b = orset_2.delta(orset_1.state)
        // diff_b is the delta from map 2
        XCTAssertNotNil(diff_b)
        XCTAssertEqual(diff_b.updates.count, 0)

        // If we take the full replicate anywhere (ask for a delta
        // with a nil state) and then merge that, it'll throw the
        // exception related to corrupted/conflicting history.

        let diff_full_a = orset_1.delta(nil)
        XCTAssertNotNil(diff_full_a)
        XCTAssertEqual(diff_full_a.updates.count, 3)

        let diff_full_b = orset_2.delta(nil)
        XCTAssertNotNil(diff_full_b)
        XCTAssertEqual(diff_full_b.updates.count, 2)

        do {
            let _ = try orset_2.mergeDelta(diff_full_a)
            XCTFail("When merging a full delta from map 1 into map 2, the value `b` has conflicting metadata so it should throw an exception.")
        } catch let CRDTMergeError.conflictingHistory(msg) {
            XCTAssertNotNil(msg)
//            print("error: \(msg)")
//            error: The metadata for the set value of 3 has conflicting metadata. local: [[3-13], deleted: true], remote: [[3-13], deleted: false].
        }
    }

    func testMergeSameCausalUpdateMerge() async throws {
        var orset_1 = ORSet<UInt, Int>(actorId: UInt(31), [1, 2, 3])
        var orset_2 = ORSet<UInt, Int>(actorId: UInt(13))
        XCTAssertEqual(orset_1.count, 3)
        XCTAssertEqual(orset_2.count, 0)

        let replicatedDeltaFromInitial1 = orset_1.delta(orset_2.state)
        // diff_a is the delta from set 1
        XCTAssertNotNil(replicatedDeltaFromInitial1)
        XCTAssertEqual(replicatedDeltaFromInitial1.updates.count, 3)

        // overwrite orset_2 with the version merged with 1
        orset_2 = try orset_2.mergeDelta(replicatedDeltaFromInitial1)
        XCTAssertEqual(orset_2.count, 3)
        XCTAssertEqual(orset_2.values, orset_1.values)

        // Update the first and second independently with the same 'causal' ordering and values
        orset_2.insert(4)
        orset_1.insert(4)
        XCTAssertEqual(orset_1.count, 4)
        XCTAssertEqual(orset_2.count, 4)

        // check the delta's in both directions:
        let replicatedDeltaFrom1 = orset_1.delta(orset_2.state)
        let replicatedDeltaFrom2 = orset_2.delta(orset_1.state)

        XCTAssertNotNil(replicatedDeltaFrom1)
        XCTAssertNotNil(replicatedDeltaFrom2)
        XCTAssertEqual(replicatedDeltaFrom1.updates.count, 1)
        XCTAssertEqual(replicatedDeltaFrom1.updates.count, 1)

        // This *should* be a legit merge, since the metadata isn't in conflict.
        do {
            orset_2 = try orset_2.mergeDelta(replicatedDeltaFrom1)
            orset_1 = try orset_1.mergeDelta(replicatedDeltaFrom2)
        } catch {
            XCTFail()
            // print(error)
        }
        XCTAssertEqual(orset_2.values, orset_1.values)

        //  I intentionally left these comments inline to make it easier
        //  for future-me to understand the data structure's being returned
        //  and reason about how it _should_ work.
//
//        print(orset_1)
//        ORSet<UInt, Int>(currentTimestamp: LamportTimestamp<4, 31>,
//             metadataByValue: [
//                1: [[1-31], deleted: false],
//                2: [[2-31], deleted: false],
//                3: [[3-31], deleted: false],
//                4: [[4-31], deleted: false]
//             ])
//        print(orset_2)
//        ORSet<UInt, Int>(currentTimestamp: LamportTimestamp<1, 13>,
//             metadataByValue: [
//                1: [[1-31], deleted: false],
//                2: [[2-31], deleted: false],
//                3: [[3-31], deleted: false],
//                4: [[4-31], deleted: false]
//             ])
    }

    func testMergeDifferentCausalUpdateMerge() async throws {
        var orset_1 = ORSet<UInt, Int>(actorId: UInt(31), [1, 2, 3])
        var orset_2 = ORSet<UInt, Int>(actorId: UInt(13))
        XCTAssertEqual(orset_1.count, 3)
        XCTAssertEqual(orset_2.count, 0)

        let replicatedDeltaFromInitial1 = orset_1.delta(orset_2.state)
        // diff_a is the delta from set 1
        XCTAssertNotNil(replicatedDeltaFromInitial1)
        XCTAssertEqual(replicatedDeltaFromInitial1.updates.count, 3)

        // Update orset_2 with the version merged with 1
        orset_2 = try orset_2.mergeDelta(replicatedDeltaFromInitial1)
        XCTAssertEqual(orset_2.count, 3)
        XCTAssertEqual(orset_2.values, orset_1.values)

        // Update the first and second independently with the same 'causal' ordering and values
        orset_2.insert(4)
        orset_1.remove(1)
        XCTAssertEqual(orset_1.count, 2)
        XCTAssertEqual(orset_2.count, 4)

        // check the delta's in both directions:
        let replicatedDeltaFrom1 = orset_1.delta(orset_2.state)
        let replicatedDeltaFrom2 = orset_2.delta(orset_1.state)

        XCTAssertNotNil(replicatedDeltaFrom1)
        XCTAssertNotNil(replicatedDeltaFrom2)
        XCTAssertEqual(replicatedDeltaFrom1.updates.count, 1)
        XCTAssertEqual(replicatedDeltaFrom1.updates.count, 1)

        // This *should* be a legit merge, since the metadata isn't in conflict.
        do {
            orset_2 = try orset_2.mergeDelta(replicatedDeltaFrom1)
            orset_1 = try orset_1.mergeDelta(replicatedDeltaFrom2)
        } catch {
            XCTFail()
            // print(error)
        }
        XCTAssertEqual(orset_1.count, 3)
        XCTAssertEqual(orset_2.count, 3)

        //  I intentionally left these comments inline to make it easier
        //  for future-me to understand the data structure's being returned
        //  and reason about how it _should_ work.
//
//        print(orset_1)
//        ORSet<UInt, Int>(currentTimestamp: LamportTimestamp<4, 31>,
//             metadataByValue: [
//                1: [[1-31], deleted: false],
//                2: [[2-31], deleted: false],
//                3: [[3-31], deleted: false],
//                4: [[4-31], deleted: false]
//             ])
//        print(orset_2)
//        ORSet<UInt, Int>(currentTimestamp: LamportTimestamp<1, 13>,
//             metadataByValue: [
//                1: [[1-31], deleted: false],
//                2: [[2-31], deleted: false],
//                3: [[3-31], deleted: false],
//                4: [[4-31], deleted: false]
//             ])
    }
}
