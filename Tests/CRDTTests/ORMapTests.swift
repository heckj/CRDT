//
//  ORSetTests.swift
//

@testable import CRDT
import XCTest

final class ORMapTests: XCTestCase {
    var a: ORMap<String, String, Int>!
    var b: ORMap<String, String, Int>!

    override func setUp() async throws {
        a = ORMap(actorId: "a", ["alpha": 1])
        b = ORMap(actorId: "b", ["alpha": 1, "beta": 2, "gamma": 3, "delta": 4])
    }

    func testInitialCreation() {
        XCTAssertEqual(a.values.count, 1)
        XCTAssertEqual(a.currentTimestamp.actorId, "a")
        XCTAssertEqual(a.currentTimestamp.clock, 1)
        XCTAssertEqual(a.count, 1)
        XCTAssertEqual(a["alpha"], 1)
        XCTAssertNil(a["beta"])

        XCTAssertEqual(b.count, 4)
        XCTAssertEqual(b["alpha"], 1)
        XCTAssertNotNil(b["beta"])
        XCTAssertEqual(b["beta"], 2)
    }

    func testSettingValue() {
        a["beta"]=3
        XCTAssertEqual(a.values.sorted(), [1, 3].sorted())
        XCTAssertEqual(a.keys.sorted(), ["alpha", "beta"].sorted())
        a["zeta"]=100
        XCTAssertEqual(a.values.sorted(), [1, 3, 100].sorted())
        XCTAssertEqual(a.keys.sorted(), ["alpha", "beta", "zeta"].sorted())
    }

    func testSettingValueAlreadyThere() {
        b["delta"] = -1
        XCTAssertEqual(b.count, 4)
        XCTAssertEqual(b.values.sorted(), [-1, 1, 2, 3].sorted())
        XCTAssertEqual(b.keys.sorted(), ["alpha", "beta", "gamma", "delta"].sorted())
    }

    func testRemovingValue() {
        b["delta"]=nil
        XCTAssertEqual(b.count, 3)
        XCTAssertEqual(b.values.sorted(), [1, 2, 3].sorted())
        XCTAssertEqual(b.keys.sorted(), ["alpha", "beta", "gamma"].sorted())
    }

    func testRemovingValueNotThere() {
        a["zeta"]=nil
        XCTAssertEqual(a.count, 1)
        XCTAssertEqual(a.values.sorted(), [1].sorted())
        XCTAssertEqual(a.keys.sorted(), ["alpha"].sorted())
    }

    func testCount() {
        XCTAssertEqual(b.count, 4)
    }

    func testMergeOfInitiallyUnrelated() {
        let c = a.merged(with: b)
        XCTAssertEqual(c.values.sorted(), b.values.sorted())
        XCTAssertEqual(c.keys.sorted(), b.keys.sorted())
    }

    func testIdempotency() {
        a["zeta"]=100
        let c = a.merged(with: b)
        let d = c.merged(with: b)
        let e = c.merged(with: a)
        XCTAssertEqual(c.values.sorted(), d.values.sorted())
        XCTAssertEqual(c.values.sorted(), e.values.sorted())
        XCTAssertEqual(c.keys.sorted(), d.keys.sorted())
        XCTAssertEqual(c.keys.sorted(), e.keys.sorted())
    }

    func testCommutativity() {
        let c = a.merged(with: b)
        let d = b.merged(with: a)
        XCTAssertEqual(d.values.sorted(), c.values.sorted())
        XCTAssertEqual(d.keys.sorted(), c.keys.sorted())
    }

    func testAssociativity() {
        let c = ORMap(actorId: "c", ["one": 1, "two": 2])
        let e = a.merged(with: b).merged(with: c)
        let f = a.merged(with: b.merged(with: c))
        XCTAssertEqual(e.values.sorted(), f.values.sorted())
        XCTAssertEqual(e.keys.sorted(), f.keys.sorted())
    }

    func testCodable() {
        let data = try! JSONEncoder().encode(b)
        let d = try! JSONDecoder().decode(ORMap<String, String, Int>.self, from: data)
        XCTAssertEqual(b, d)
    }

//    func testDeltaState_state() async {
//        let state = await a.state
//        XCTAssertNotNil(state)
//        XCTAssertEqual(Array(state.maxClockValueByActor.keys), [a.currentTimestamp.actorId])
//        XCTAssertEqual(Array(state.maxClockValueByActor.values), [a.currentTimestamp.clock])
//    }
//
//    func testDeltaState_nilDelta() async {
//        let a_nil_delta = await a.delta(nil)
//        // print(a_nil_delta)
//        XCTAssertNotNil(a_nil_delta)
//        XCTAssertEqual(a_nil_delta.updates.count, 1)
//        XCTAssertEqual(a_nil_delta.updates, a.metadataByValue)
//    }
//
//    func testDeltaState_delta() async {
//        let a_delta = await a.delta(b.state)
//        XCTAssertEqual(a_delta.updates.count, 1)
//        XCTAssertEqual(a_delta.updates, a.metadataByValue)
//    }
//
//    func testDeltaState_mergeDeltas() async throws {
//        // equiv direct merge
//        // let c = a.merged(with: b)
//        let delta = await b.delta(a.state)
//        let c = try await a.mergeDelta(delta)
//        XCTAssertEqual(c.values, b.values)
//    }
//
//    func testDeltaState_mergeDelta() async throws {
//        // equiv direct merge
//        // let c = a.merged(with: b)
//        let delta = await b.delta(a.state)
//        let c = try await a.mergeDelta(delta)
//        XCTAssertEqual(c.values, b.values)
//    }
//
//    func testUnrelatedMerges() async throws {
//        let orset_1 = ORSet(actorId: UInt(31), [1, 2, 3, 4])
//        let orset_2 = ORSet(actorId: UInt(13), [5, 6])
//
//        let diff_a = await orset_1.delta(await orset_2.state)
//        // diff_a is the delta from set 1
//        XCTAssertNotNil(diff_a)
//        XCTAssertEqual(diff_a.updates.count, 4)
//
//        let diff_b = await orset_2.delta(await orset_1.state)
//        // diff_b is the delta from set 2
//        XCTAssertNotNil(diff_b)
//        XCTAssertEqual(diff_b.updates.count, 2)
//
//        // merge the diff from set 1 into set 2
//        let mergedFrom1 = try await orset_2.mergeDelta(diff_a)
//        XCTAssertEqual(mergedFrom1.count, 6)
//
//        // merge the diff from set 2 into set 1
//        let mergedFrom2 = try await orset_1.mergeDelta(diff_b)
//        XCTAssertEqual(mergedFrom2.count, 6)
//
//        XCTAssertEqual(mergedFrom1.values, mergedFrom2.values)
//    }
//
//    func testConflictingUnrelatedMerges() async throws {
//        let orset_1 = ORSet(actorId: UInt(31), [1, 2, 3])
//        var orset_2 = ORSet(actorId: UInt(13), [3, 4])
//        orset_2.remove(3)
//        // the metadata for the entry for `3` is going to be in conflict, both by
//        // Lamport timestamps ('2' vs '3') and the metadata in question (deleted vs not)
//
//        let diff_a = await orset_1.delta(await orset_2.state)
//        // diff_a is the delta from set 1
//        XCTAssertNotNil(diff_a)
//        XCTAssertEqual(diff_a.updates.count, 3)
//
//        let diff_b = await orset_2.delta(await orset_1.state)
//        // diff_b is the delta from set 2
//        XCTAssertNotNil(diff_b)
//        XCTAssertEqual(diff_b.updates.count, 2)
//
//        // merge the diff from set 1 into set 2
//
//        do {
//            let mergedFrom1 = try await orset_2.mergeDelta(diff_a)
//            XCTAssertEqual(mergedFrom1.count, 4)
//        } catch CRDTMergeError.conflictingHistory(_) {
//            // print("error: \(msg)")
//            XCTFail("When merging set 1 into set 2, the value `3` should has a higher Lamport timestamp, so it should merge cleanly")
//        }
//
//        // merge the diff from set 2 into set 1
//
//        do {
//            let _ = try await orset_1.mergeDelta(diff_b)
//            XCTFail("The merge didn't catch and throw on a failure due to conflicting Lamport timestamps for the value `3`.")
//        } catch let CRDTMergeError.conflictingHistory(msg) {
//            XCTAssertNotNil(msg)
//            // print("error: \(msg)")
//            // Example message:
//            // The metadata for the set value 3 has conflicting timestamps. local: [[3-31], deleted: false], remote: [[3-13], deleted: true].
//        }
//    }
//
//    func testMergeCausalUpdateMerge() async throws {
//        var orset_1 = ORSet<UInt, Int>(actorId: UInt(31), [1, 2, 3])
//        var orset_2 = ORSet<UInt, Int>(actorId: UInt(13))
//        XCTAssertEqual(orset_1.count, 3)
//        XCTAssertEqual(orset_2.count, 0)
//
//        let replicatedDeltaFromInitial1 = await orset_1.delta(await orset_2.state)
//        // diff_a is the delta from set 1
//        XCTAssertNotNil(replicatedDeltaFromInitial1)
//        XCTAssertEqual(replicatedDeltaFromInitial1.updates.count, 3)
//
//        // overwrite orset_2 with the version merged with 1
//        orset_2 = try await orset_2.mergeDelta(replicatedDeltaFromInitial1)
//        XCTAssertEqual(orset_2.count, 3)
//        XCTAssertEqual(orset_2.values, orset_1.values)
//
//        // Update the first and second independently with the same 'causal' ordering and values
//        orset_2.insert(4)
//        orset_1.insert(4)
//        XCTAssertEqual(orset_1.count, 4)
//        XCTAssertEqual(orset_2.count, 4)
//
//        // check the delta's in both directions:
//        let replicatedDeltaFrom1 = await orset_1.delta(await orset_2.state)
//        let replicatedDeltaFrom2 = await orset_2.delta(await orset_1.state)
//
//        XCTAssertNotNil(replicatedDeltaFrom1)
//        XCTAssertNotNil(replicatedDeltaFrom2)
//        XCTAssertEqual(replicatedDeltaFrom1.updates.count, 1)
//        XCTAssertEqual(replicatedDeltaFrom1.updates.count, 1)
//
//        // This *should* be a legit merge, since the metadata isn't in conflict.
//        do {
//            orset_2 = try await orset_2.mergeDelta(replicatedDeltaFrom1)
//            orset_1 = try await orset_1.mergeDelta(replicatedDeltaFrom2)
//        } catch {
//            print(error)
//            XCTFail()
//        }
//        XCTAssertEqual(orset_2.values, orset_1.values)
////        print(orset_1)
////        ORSet<UInt, Int>(currentTimestamp: LamportTimestamp<4, 31>,
////             metadataByValue: [
////                1: [[1-31], deleted: false],
////                2: [[2-31], deleted: false],
////                3: [[3-31], deleted: false],
////                4: [[4-31], deleted: false]
////             ])
////        print(orset_2)
////        ORSet<UInt, Int>(currentTimestamp: LamportTimestamp<1, 13>,
////             metadataByValue: [
////                1: [[1-31], deleted: false],
////                2: [[2-31], deleted: false],
////                3: [[3-31], deleted: false],
////                4: [[4-31], deleted: false]
////             ])
//    }
}
