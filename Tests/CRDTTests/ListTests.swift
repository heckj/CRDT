//
//  ListTests.swift
//

@testable import CRDT
import XCTest

final class ListTests: XCTestCase {
    var a: List<String, String>!
    var b: List<String, String>!

    override func setUp() async throws {
        a = List(actorId: "a", ["a"])
        b = List(actorId: "b", ["h", "e", "l", "l", "o"])
    }

    func testInitialCreation() {
        XCTAssertEqual(a.values.count, 1)
        XCTAssertEqual(a.currentTimestamp.actorId, "a")
        XCTAssertEqual(a.currentTimestamp.clock, 1)
        XCTAssertEqual(a.count, 1)
        XCTAssertEqual(a.values, ["a"])
        XCTAssertEqual(a.tombstones.count, 0)

        XCTAssertEqual(b.count, 5)
        XCTAssertEqual(b.currentTimestamp.clock, 5)
        XCTAssertEqual(b.tombstones.count, 0)
    }

    func testAppendingValue() {
        b.append("!")
        XCTAssertEqual(b.values, ["h", "e", "l", "l", "o", "!"])
    }

    func testUpdatingValue() {
        b[1] = "a"
        XCTAssertEqual(b.values, ["h", "a", "l", "l", "o"])
    }

    func testRemovingValue() {
        b.remove(at: 4)
        XCTAssertEqual(b.values, ["h", "e", "l", "l"])
        XCTAssertEqual(b.activeValues.count, 4)
        XCTAssertEqual(b.tombstones.count, 1)
    }

    func testCount() {
        XCTAssertEqual(b.count, 5)
    }

    func testIdempotency() {
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
        let c = List(actorId: "c", ["z", "y", "x"])
        let e = a.merged(with: b).merged(with: c)
        let f = a.merged(with: b.merged(with: c))
        XCTAssertEqual(e.values, f.values)
    }

    func testCodable() {
        let data = try! JSONEncoder().encode(b)
        let d = try! JSONDecoder().decode(List<String, String>.self, from: data)
        XCTAssertEqual(b, d)
    }
//
//    func testDeltaState_state() async {
//        let state = a.state
//        XCTAssertNotNil(state)
//        XCTAssertEqual(Array(state.maxClockValueByActor.keys), [a.currentTimestamp.actorId])
//        XCTAssertEqual(Array(state.maxClockValueByActor.values), [a.currentTimestamp.clock])
//    }
//
//    func testDeltaState_nilDelta() async {
//        let a_nil_delta = a.delta(nil)
//        // print(a_nil_delta)
//        XCTAssertNotNil(a_nil_delta)
//        XCTAssertEqual(a_nil_delta.updates.count, 1)
//        XCTAssertEqual(a_nil_delta.updates, a.metadataByDictKey)
//    }
//
//    func testDeltaState_delta() async {
//        let a_delta = a.delta(b.state)
//        XCTAssertEqual(a_delta.updates.count, 1)
//        XCTAssertEqual(a_delta.updates, a.metadataByDictKey)
//    }
//
//    func testDeltaState_mergeDeltas() async throws {
//        // equiv direct merge
//        // let c = a.merged(with: b)
//        let delta = b.delta(a.state)
//        let c = try a.mergeDelta(delta)
//        XCTAssertEqual(c.values.sorted(), b.values.sorted())
//        XCTAssertEqual(c.keys.sorted(), b.keys.sorted())
//    }
//
//    func testDeltaState_mergeDelta() async throws {
//        // equiv direct merge
//        // let c = a.merged(with: b)
//        let delta = b.delta(a.state)
//        let c = try a.mergeDelta(delta)
//        XCTAssertEqual(c.values.sorted(), b.values.sorted())
//        XCTAssertEqual(c.keys.sorted(), b.keys.sorted())
//    }
//
//    func testUnrelatedMerges() async throws {
//        let ormap_1 = ORMap(actorId: UInt(31), ["a": 1, "b": 2, "c": 3, "d": 4])
//        let ormap_2 = ORMap(actorId: UInt(13), ["e": 5, "f": 6])
//
//        let diff_a = ormap_1.delta(ormap_2.state)
//        // diff_a is the delta from map 1
//        XCTAssertNotNil(diff_a)
//        XCTAssertEqual(diff_a.updates.count, 4)
//
//        let diff_b = ormap_2.delta(ormap_1.state)
//        // diff_b is the delta from map 2
//        XCTAssertNotNil(diff_b)
//        XCTAssertEqual(diff_b.updates.count, 2)
//
//        // merge the diff from map 1 into map 2
//        let mergedFrom1 = try ormap_2.mergeDelta(diff_a)
//        XCTAssertEqual(mergedFrom1.count, 6)
//
//        // merge the diff from map 2 into map 1
//        let mergedFrom2 = try ormap_1.mergeDelta(diff_b)
//        XCTAssertEqual(mergedFrom2.count, 6)
//
//        XCTAssertEqual(mergedFrom1.values.sorted(), mergedFrom2.values.sorted())
//        XCTAssertEqual(mergedFrom1.keys.sorted(), mergedFrom2.keys.sorted())
//    }
//
//    func testCorruptedHistoryMerge() async throws {
//        // actor id's intentionally identical, but with different data inside them,
//        // which *shouldn't* happen in practice, but this represents a throwing case
//        // I wanted to get correctly established.
//        var ormap_1 = ORMap<UInt, String, Int>(actorId: UInt(13))
//        ormap_1["a"] = 1
//        ormap_1["b"] = 2
//        var ormap_2 = ORMap<UInt, String, Int>(actorId: UInt(13))
//        ormap_2["a"] = 1
//        ormap_2["b"] = 99
//
//        // The state's alone _won't_ show any changes, as the state
//        // doesn't have any detail about the *content*.
//
//        let diff_a = ormap_1.delta(ormap_2.state)
//        // diff_a is the delta from map 1
//        XCTAssertNotNil(diff_a)
//        XCTAssertEqual(diff_a.updates.count, 0)
//
//        let diff_b = ormap_2.delta(ormap_1.state)
//        // diff_b is the delta from map 2
//        XCTAssertNotNil(diff_b)
//        XCTAssertEqual(diff_b.updates.count, 0)
//
//        // If we take the full replicate anywhere (ask for a delta
//        // with a nil state) and then merge that, it'll throw the
//        // exception related to corrupted/conflicting history.
//
//        let diff_full_a = ormap_1.delta(nil)
//        XCTAssertNotNil(diff_full_a)
//        XCTAssertEqual(diff_full_a.updates.count, 2)
//
//        let diff_full_b = ormap_2.delta(nil)
//        XCTAssertNotNil(diff_full_b)
//        XCTAssertEqual(diff_full_b.updates.count, 2)
//
//        do {
//            //  I intentionally left these comments inline to make it easier
//            //  for future-me to understand the data structure's being returned
//            //  and reason about how it _should_ work.
    ////
    ////            print(ormap_2)
    ////            ORMap<UInt, String, Int>(
    ////                currentTimestamp: LamportTimestamp<2, 13>,
    ////                metadataByDictKey: [
    ////                    "a": [[1-13], deleted: false, value: 1],
    ////                    "b": [[2-13], deleted: false, value: 99]
    ////                ])
    ////
    ////            print(diff_full_a)
    ////            ORMapDelta(updates: [
    ////                "a": [[1-13], deleted: false, value: 1],
    ////                "b": [[2-13], deleted: false, value: 2]
    ////            ])
//
//            let _ = try ormap_2.mergeDelta(diff_full_a)
//            XCTFail("When merging a full delta from map 1 into map 2, the value `b` has conflicting metadata so it should throw an exception.")
//        } catch let CRDTMergeError.conflictingHistory(msg) {
//            XCTAssertNotNil(msg)
//            // print("error: \(msg)")
    ////        error: The metadata for the map key c is conflicting.
    ////                local: [[3-31], deleted: true, value: 3],
    ////                remote: [[3-13], deleted: false, value: 3].
//        }
//    }
//
//    func testPreviousUnsyncedMergeWithConflictingMetadata() async throws {
//        var ormap_1 = ORMap<UInt, String, Int>(actorId: UInt(13))
//        ormap_1["a"] = 1
//        ormap_1["b"] = 2
//        ormap_1["c"] = 3
//        var ormap_2 = ORMap<UInt, String, Int>(actorId: UInt(31))
//        ormap_2["c"] = 3
//        ormap_2["d"] = 4
//        ormap_2["c"] = nil
//        // the metadata for the entry for `c` is going to be in conflict, both by
//        // Lamport timestamps ('2' vs '3') and the metadata in question (deleted vs not)
//
//        let diff_a = ormap_1.delta(ormap_2.state)
//        // diff_a is the delta from map 1
//        XCTAssertNotNil(diff_a)
//        XCTAssertEqual(diff_a.updates.count, 3)
//
//        let diff_b = ormap_2.delta(ormap_1.state)
//        // diff_b is the delta from map 2
//        XCTAssertNotNil(diff_b)
//        XCTAssertEqual(diff_b.updates.count, 2)
//
//        // merge the diff from map 1 into map 2
//
//        do {
//            let result = try ormap_2.mergeDelta(diff_a)
//            XCTAssertNotNil(result)
//            XCTAssertEqual(result.count, 3)
//        } catch CRDTMergeError.conflictingHistory(_) {
//            XCTFail("When merging map 1 into map 2, the value `c` has conflicting metadata (one is deleted, the other not) so it should throw an exception.")
//        }
//
//        // merge the diff from map 2 into map 1
//
//        do {
//            let result = try ormap_1.mergeDelta(diff_b)
//            XCTAssertNotNil(result)
//            XCTAssertEqual(result.count, 3)
//        } catch CRDTMergeError.conflictingHistory(_) {
//            XCTFail("When merging map 1 into map 2, the value `c` has conflicting metadata (one is deleted, the other not) so it should throw an exception.")
//        }
//    }
//
//    func testMergeSameCausalUpdateMerge() async throws {
//        var ormap_1 = ORMap<UInt, String, Int>(actorId: UInt(31), ["a": 1, "b": 2, "c": 3])
//        var ormap_2 = ORMap<UInt, String, Int>(actorId: UInt(13))
//        XCTAssertEqual(ormap_1.count, 3)
//        XCTAssertEqual(ormap_2.count, 0)
//
//        let replicatedDeltaFromInitial1 = ormap_1.delta(ormap_2.state)
//        // diff_a is the delta from map 1
//        XCTAssertNotNil(replicatedDeltaFromInitial1)
//        XCTAssertEqual(replicatedDeltaFromInitial1.updates.count, 3)
//
//        // overwrite ormap_2 with the version merged with 1
//        ormap_2 = try ormap_2.mergeDelta(replicatedDeltaFromInitial1)
//        XCTAssertEqual(ormap_2.count, 3)
//        XCTAssertEqual(ormap_2.values.sorted(), ormap_1.values.sorted())
//        XCTAssertEqual(ormap_2.keys.sorted(), ormap_1.keys.sorted())
//
//        // Update the first and second independently with the same 'causal' ordering and values
//        ormap_2["d"] = 4
//        ormap_1["d"] = 4
//        XCTAssertEqual(ormap_1.count, 4)
//        XCTAssertEqual(ormap_2.count, 4)
//
//        // check the delta's in both directions:
//        let replicatedDeltaFrom1 = ormap_1.delta(ormap_2.state)
//        let replicatedDeltaFrom2 = ormap_2.delta(ormap_1.state)
//
//        XCTAssertNotNil(replicatedDeltaFrom1)
//        XCTAssertNotNil(replicatedDeltaFrom2)
//        XCTAssertEqual(replicatedDeltaFrom1.updates.count, 1)
//        XCTAssertEqual(replicatedDeltaFrom1.updates.count, 1)
//
//        // This *should* be a legit merge, since the metadata isn't in conflict.
//        do {
//            ormap_2 = try ormap_2.mergeDelta(replicatedDeltaFrom1)
//            ormap_1 = try ormap_1.mergeDelta(replicatedDeltaFrom2)
//        } catch {
//            // print(error)
//            XCTFail()
//        }
//        XCTAssertEqual(ormap_2.values.sorted(), ormap_1.values.sorted())
//        XCTAssertEqual(ormap_2.keys.sorted(), ormap_1.keys.sorted())
//    }
//
//    func testMergeDifferentCausalUpdateMerge() async throws {
//        var ormap_1 = ORMap<UInt, String, Int>(actorId: UInt(31), ["a": 1, "b": 2, "c": 3])
//        var ormap_2 = ORMap<UInt, String, Int>(actorId: UInt(13))
//        XCTAssertEqual(ormap_1.count, 3)
//        XCTAssertEqual(ormap_2.count, 0)
//
//        let replicatedDeltaFromInitial1 = ormap_1.delta(ormap_2.state)
//        // diff_a is the delta from map 1
//        XCTAssertNotNil(replicatedDeltaFromInitial1)
//        XCTAssertEqual(replicatedDeltaFromInitial1.updates.count, 3)
//
//        // overwrite ormap_2 with the version merged with 1
//        ormap_2 = try ormap_2.mergeDelta(replicatedDeltaFromInitial1)
//        XCTAssertEqual(ormap_2.count, 3)
//        XCTAssertEqual(ormap_2.values.sorted(), ormap_1.values.sorted())
//        XCTAssertEqual(ormap_2.keys.sorted(), ormap_1.keys.sorted())
//
//        // Update the first and second independently with the same 'causal' ordering and values
//        ormap_2["c"] = 99
//        ormap_1["c"] = 100
//        XCTAssertEqual(ormap_1.count, 3)
//        XCTAssertEqual(ormap_2.count, 3)
//
//        // check the delta's in both directions:
//        let replicatedDeltaFrom1 = ormap_1.delta(ormap_2.state)
//        let replicatedDeltaFrom2 = ormap_2.delta(ormap_1.state)
//
//        XCTAssertNotNil(replicatedDeltaFrom1)
//        XCTAssertNotNil(replicatedDeltaFrom2)
//        XCTAssertEqual(replicatedDeltaFrom1.updates.count, 1)
//        XCTAssertEqual(replicatedDeltaFrom1.updates.count, 1)
//
//        // This *should* be a legit merge, since the metadata isn't in conflict.
//        do {
//            ormap_2 = try ormap_2.mergeDelta(replicatedDeltaFrom1)
//            ormap_1 = try ormap_1.mergeDelta(replicatedDeltaFrom2)
//        } catch {
//            // print(error)
//            XCTFail()
//        }
//        XCTAssertEqual(ormap_2.values.sorted(), ormap_1.values.sorted())
//        XCTAssertEqual(ormap_2.keys.sorted(), ormap_1.keys.sorted())
//    }
}
