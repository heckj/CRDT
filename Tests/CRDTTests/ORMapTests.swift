//
//  ORMapTests.swift
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
        a["beta"] = 3
        XCTAssertEqual(a.values.sorted(), [1, 3].sorted())
        XCTAssertEqual(a.keys.sorted(), ["alpha", "beta"].sorted())
        a["zeta"] = 100
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
        b["delta"] = nil
        XCTAssertEqual(b.count, 3)
        XCTAssertEqual(b.values.sorted(), [1, 2, 3].sorted())
        XCTAssertEqual(b.keys.sorted(), ["alpha", "beta", "gamma"].sorted())
    }

    func testRemovingValueNotThere() {
        a["zeta"] = nil
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
        a["zeta"] = 100
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

    func testDeltaState_state() async {
        let state = a.state
        XCTAssertNotNil(state)
        XCTAssertEqual(Array(state.maxClockValueByActor.keys), [a.currentTimestamp.actorId])
        XCTAssertEqual(Array(state.maxClockValueByActor.values), [a.currentTimestamp.clock])
    }

    func testDeltaState_nilDelta() async {
        guard let a_nil_delta = a.delta(nil) else {
            XCTFail("incorrectly returned no differences to replicate")
            return
        }
        // print(a_nil_delta)
        XCTAssertNotNil(a_nil_delta)
        XCTAssertEqual(a_nil_delta.updates.count, 1)
        XCTAssertEqual(a_nil_delta.updates, a.metadataByDictKey)
    }

    func testDeltaState_delta() async {
        guard let a_delta = a.delta(b.state) else {
            XCTFail("incorrectly returned no differences to replicate")
            return
        }
        XCTAssertEqual(a_delta.updates.count, 1)
        XCTAssertEqual(a_delta.updates, a.metadataByDictKey)
    }

    func testDeltaState_mergeDeltas() async throws {
        // equiv direct merge
        // let c = a.merged(with: b)
        guard let delta = b.delta(a.state) else {
            XCTFail("incorrectly returned no differences to replicate")
            return
        }
        let c = try a.mergeDelta(delta)
        XCTAssertEqual(c.values.sorted(), b.values.sorted())
        XCTAssertEqual(c.keys.sorted(), b.keys.sorted())
    }

    func testDeltaState_mergeDelta() async throws {
        // equiv direct merge
        // let c = a.merged(with: b)
        guard let delta = b.delta(a.state) else {
            XCTFail("incorrectly returned no differences to replicate")
            return
        }
        let c = try a.mergeDelta(delta)
        XCTAssertEqual(c.values.sorted(), b.values.sorted())
        XCTAssertEqual(c.keys.sorted(), b.keys.sorted())
    }

    func testUnrelatedMerges() async throws {
        let ormap_1 = ORMap(actorId: UInt(31), ["a": 1, "b": 2, "c": 3, "d": 4])
        let ormap_2 = ORMap(actorId: UInt(13), ["e": 5, "f": 6])

        guard let diff_a = ormap_1.delta(ormap_2.state) else {
            XCTFail("incorrectly returned no differences to replicate")
            return
        }
        // diff_a is the delta from map 1
        XCTAssertNotNil(diff_a)
        XCTAssertEqual(diff_a.updates.count, 4)

        guard let diff_b = ormap_2.delta(ormap_1.state) else {
            XCTFail("incorrectly returned no differences to replicate")
            return
        }
        // diff_b is the delta from map 2
        XCTAssertNotNil(diff_b)
        XCTAssertEqual(diff_b.updates.count, 2)

        // merge the diff from map 1 into map 2
        let mergedFrom1 = try ormap_2.mergeDelta(diff_a)
        XCTAssertEqual(mergedFrom1.count, 6)

        // merge the diff from map 2 into map 1
        let mergedFrom2 = try ormap_1.mergeDelta(diff_b)
        XCTAssertEqual(mergedFrom2.count, 6)

        XCTAssertEqual(mergedFrom1.values.sorted(), mergedFrom2.values.sorted())
        XCTAssertEqual(mergedFrom1.keys.sorted(), mergedFrom2.keys.sorted())
    }

    func testCorruptedHistoryMerge() async throws {
        // actor id's intentionally identical, but with different data inside them,
        // which *shouldn't* happen in practice, but this represents a throwing case
        // I wanted to get correctly established.
        var ormap_1 = ORMap<UInt, String, Int>(actorId: UInt(13))
        ormap_1["a"] = 1
        ormap_1["b"] = 2
        var ormap_2 = ORMap<UInt, String, Int>(actorId: UInt(13))
        ormap_2["a"] = 1
        ormap_2["b"] = 99

        // The state's alone _won't_ show any changes, as the state
        // doesn't have any detail about the *content*.

        let diff_a = ormap_1.delta(ormap_2.state)
        // diff_a is the delta from map 1
        XCTAssertNil(diff_a)

        let diff_b = ormap_2.delta(ormap_1.state)
        // diff_b is the delta from map 2
        XCTAssertNil(diff_b)

        // If we take the full replicate anywhere (ask for a delta
        // with a nil state) and then merge that, it'll throw the
        // exception related to corrupted/conflicting history.

        guard let diff_full_a = ormap_1.delta(nil) else {
            XCTFail("incorrectly returned no differences to replicate")
            return
        }
        XCTAssertNotNil(diff_full_a)
        XCTAssertEqual(diff_full_a.updates.count, 2)

        guard let diff_full_b = ormap_2.delta(nil) else {
            XCTFail("incorrectly returned no differences to replicate")
            return
        }
        XCTAssertNotNil(diff_full_b)
        XCTAssertEqual(diff_full_b.updates.count, 2)

        do {
            //  I intentionally left these comments inline to make it easier
            //  for future-me to understand the data structure's being returned
            //  and reason about how it _should_ work.
//
//            print(ormap_2)
//            ORMap<UInt, String, Int>(
//                currentTimestamp: LamportTimestamp<2, 13>,
//                metadataByDictKey: [
//                    "a": [[1-13], deleted: false, value: 1],
//                    "b": [[2-13], deleted: false, value: 99]
//                ])
//
//            print(diff_full_a)
//            ORMapDelta(updates: [
//                "a": [[1-13], deleted: false, value: 1],
//                "b": [[2-13], deleted: false, value: 2]
//            ])

            let _ = try ormap_2.mergeDelta(diff_full_a)
            XCTFail("When merging a full delta from map 1 into map 2, the value `b` has conflicting metadata so it should throw an exception.")
        } catch let CRDTMergeError.conflictingHistory(msg) {
            XCTAssertNotNil(msg)
            // print("error: \(msg)")
//        error: The metadata for the map key c is conflicting.
//                local: [[3-31], deleted: true, value: 3],
//                remote: [[3-13], deleted: false, value: 3].
        }
    }

    func testPreviousUnsyncedMergeWithConflictingMetadata() async throws {
        var ormap_1 = ORMap<UInt, String, Int>(actorId: UInt(13))
        ormap_1["a"] = 1
        ormap_1["b"] = 2
        ormap_1["c"] = 3
        var ormap_2 = ORMap<UInt, String, Int>(actorId: UInt(31))
        ormap_2["c"] = 3
        ormap_2["d"] = 4
        ormap_2["c"] = nil
        // the metadata for the entry for `c` is going to be in conflict, both by
        // Lamport timestamps ('2' vs '3') and the metadata in question (deleted vs not)

        guard let diff_a = ormap_1.delta(ormap_2.state) else {
            XCTFail("incorrectly returned no differences to replicate")
            return
        }
        // diff_a is the delta from map 1
        XCTAssertNotNil(diff_a)
        XCTAssertEqual(diff_a.updates.count, 3)

        guard let diff_b = ormap_2.delta(ormap_1.state) else {
            XCTFail("incorrectly returned no differences to replicate")
            return
        }
        // diff_b is the delta from map 2
        XCTAssertNotNil(diff_b)
        XCTAssertEqual(diff_b.updates.count, 2)

        // merge the diff from map 1 into map 2

        do {
            let result = try ormap_2.mergeDelta(diff_a)
            XCTAssertNotNil(result)
            XCTAssertEqual(result.count, 3)
        } catch CRDTMergeError.conflictingHistory(_) {
            XCTFail("When merging map 1 into map 2, the value `c` has conflicting metadata (one is deleted, the other not) so it should throw an exception.")
        }

        // merge the diff from map 2 into map 1

        do {
            let result = try ormap_1.mergeDelta(diff_b)
            XCTAssertNotNil(result)
            XCTAssertEqual(result.count, 3)
        } catch CRDTMergeError.conflictingHistory(_) {
            XCTFail("When merging map 1 into map 2, the value `c` has conflicting metadata (one is deleted, the other not) so it should throw an exception.")
        }
    }

    func testMergeSameCausalUpdateMerge() async throws {
        var ormap_1 = ORMap<UInt, String, Int>(actorId: UInt(31), ["a": 1, "b": 2, "c": 3])
        var ormap_2 = ORMap<UInt, String, Int>(actorId: UInt(13))
        XCTAssertEqual(ormap_1.count, 3)
        XCTAssertEqual(ormap_2.count, 0)

        guard let replicatedDeltaFromInitial1 = ormap_1.delta(ormap_2.state) else {
            XCTFail("incorrectly returned no differences to replicate")
            return
        }
        // diff_a is the delta from map 1
        XCTAssertNotNil(replicatedDeltaFromInitial1)
        XCTAssertEqual(replicatedDeltaFromInitial1.updates.count, 3)

        // overwrite ormap_2 with the version merged with 1
        ormap_2 = try ormap_2.mergeDelta(replicatedDeltaFromInitial1)
        XCTAssertEqual(ormap_2.count, 3)
        XCTAssertEqual(ormap_2.values.sorted(), ormap_1.values.sorted())
        XCTAssertEqual(ormap_2.keys.sorted(), ormap_1.keys.sorted())

        // Update the first and second independently with the same 'causal' ordering and values
        ormap_2["d"] = 4
        ormap_1["d"] = 4
        XCTAssertEqual(ormap_1.count, 4)
        XCTAssertEqual(ormap_2.count, 4)

        // check the delta's in both directions:
        guard let replicatedDeltaFrom1 = ormap_1.delta(ormap_2.state) else {
            XCTFail("incorrectly returned no differences to replicate")
            return
        }
        guard let replicatedDeltaFrom2 = ormap_2.delta(ormap_1.state) else {
            XCTFail("incorrectly returned no differences to replicate")
            return
        }

        XCTAssertNotNil(replicatedDeltaFrom1)
        XCTAssertNotNil(replicatedDeltaFrom2)
        XCTAssertEqual(replicatedDeltaFrom1.updates.count, 1)
        XCTAssertEqual(replicatedDeltaFrom2.updates.count, 1)

        // This *should* be a legit merge, since the metadata isn't in conflict.
        do {
            ormap_2 = try ormap_2.mergeDelta(replicatedDeltaFrom1)
            ormap_1 = try ormap_1.mergeDelta(replicatedDeltaFrom2)
        } catch {
            // print(error)
            XCTFail()
        }
        XCTAssertEqual(ormap_2.values.sorted(), ormap_1.values.sorted())
        XCTAssertEqual(ormap_2.keys.sorted(), ormap_1.keys.sorted())
    }

    func testMergeDifferentCausalUpdateMerge() async throws {
        var ormap_1 = ORMap<UInt, String, Int>(actorId: UInt(31), ["a": 1, "b": 2, "c": 3])
        var ormap_2 = ORMap<UInt, String, Int>(actorId: UInt(13))
        XCTAssertEqual(ormap_1.count, 3)
        XCTAssertEqual(ormap_2.count, 0)

        guard let replicatedDeltaFromInitial1 = ormap_1.delta(ormap_2.state) else {
            XCTFail("incorrectly returned no differences to replicate")
            return
        }
        // diff_a is the delta from map 1
        XCTAssertNotNil(replicatedDeltaFromInitial1)
        XCTAssertEqual(replicatedDeltaFromInitial1.updates.count, 3)

        // overwrite ormap_2 with the version merged with 1
        ormap_2 = try ormap_2.mergeDelta(replicatedDeltaFromInitial1)
        XCTAssertEqual(ormap_2.count, 3)
        XCTAssertEqual(ormap_2.values.sorted(), ormap_1.values.sorted())
        XCTAssertEqual(ormap_2.keys.sorted(), ormap_1.keys.sorted())

        // Update the first and second independently with the same 'causal' ordering and values
        ormap_2["c"] = 99
        ormap_1["c"] = 100
        XCTAssertEqual(ormap_1.count, 3)
        XCTAssertEqual(ormap_2.count, 3)

        // check the delta's in both directions:
        guard let replicatedDeltaFrom1 = ormap_1.delta(ormap_2.state) else {
            XCTFail("incorrectly returned no differences to replicate")
            return
        }
        guard let replicatedDeltaFrom2 = ormap_2.delta(ormap_1.state) else {
            XCTFail("incorrectly returned no differences to replicate")
            return
        }

        XCTAssertNotNil(replicatedDeltaFrom1)
        XCTAssertNotNil(replicatedDeltaFrom2)
        XCTAssertEqual(replicatedDeltaFrom1.updates.count, 1)
        XCTAssertEqual(replicatedDeltaFrom2.updates.count, 1)

        // This *should* be a legit merge, since the metadata isn't in conflict.
        do {
            ormap_2 = try ormap_2.mergeDelta(replicatedDeltaFrom1)
            ormap_1 = try ormap_1.mergeDelta(replicatedDeltaFrom2)
        } catch {
            // print(error)
            XCTFail()
        }
        XCTAssertEqual(ormap_2.values.sorted(), ormap_1.values.sorted())
        XCTAssertEqual(ormap_2.keys.sorted(), ormap_1.keys.sorted())
    }
}
