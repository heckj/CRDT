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
        XCTAssertEqual(a_nil_delta.updates, a.metadataByDictKey)
    }

    func testDeltaState_delta() async {
        let a_delta = await a.delta(b.state)
        XCTAssertEqual(a_delta.updates.count, 1)
        XCTAssertEqual(a_delta.updates, a.metadataByDictKey)
    }

    func testDeltaState_mergeDeltas() async throws {
        // equiv direct merge
        // let c = a.merged(with: b)
        let delta = await b.delta(a.state)
        let c = try await a.mergeDelta(delta)
        XCTAssertEqual(c.values.sorted(), b.values.sorted())
        XCTAssertEqual(c.keys.sorted(), b.keys.sorted())
    }

    func testDeltaState_mergeDelta() async throws {
        // equiv direct merge
        // let c = a.merged(with: b)
        let delta = await b.delta(a.state)
        let c = try await a.mergeDelta(delta)
        XCTAssertEqual(c.values.sorted(), b.values.sorted())
        XCTAssertEqual(c.keys.sorted(), b.keys.sorted())
    }

    func testUnrelatedMerges() async throws {
        let ormap_1 = ORMap(actorId: UInt(31), ["a": 1, "b": 2, "c": 3, "d": 4])
        let ormap_2 = ORMap(actorId: UInt(13), ["e": 5, "f": 6])

        let diff_a = await ormap_1.delta(await ormap_2.state)
        // diff_a is the delta from map 1
        XCTAssertNotNil(diff_a)
        XCTAssertEqual(diff_a.updates.count, 4)

        let diff_b = await ormap_2.delta(await ormap_1.state)
        // diff_b is the delta from map 2
        XCTAssertNotNil(diff_b)
        XCTAssertEqual(diff_b.updates.count, 2)

        // merge the diff from map 1 into map 2
        let mergedFrom1 = try await ormap_2.mergeDelta(diff_a)
        XCTAssertEqual(mergedFrom1.count, 6)

        // merge the diff from map 2 into map 1
        let mergedFrom2 = try await ormap_1.mergeDelta(diff_b)
        XCTAssertEqual(mergedFrom2.count, 6)

        XCTAssertEqual(mergedFrom1.values.sorted(), mergedFrom2.values.sorted())
        XCTAssertEqual(mergedFrom1.keys.sorted(), mergedFrom2.keys.sorted())
    }

    func testConflictingUnrelatedMerges() async throws {
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

        let diff_a = await ormap_1.delta(await ormap_2.state)
        // diff_a is the delta from map 1
        XCTAssertNotNil(diff_a)
        XCTAssertEqual(diff_a.updates.count, 3)

        let diff_b = await ormap_2.delta(await ormap_1.state)
        // diff_b is the delta from map 2
        XCTAssertNotNil(diff_b)
        XCTAssertEqual(diff_b.updates.count, 2)

        // merge the diff from map 1 into map 2

        do {
//            print(ormap_2)
//            ORMap<UInt, String, Int>(
//                currentTimestamp: LamportTimestamp<3, 13>,
//                metadataByDictKey: [
//                    "d": [[2-13], deleted: false, value: 4],
//                    "c": [[3-13], deleted: true, value: 3]
//                ])
//            print(diff_a)
//            ORMapDelta(updates: [
//                "b": [[2-31], deleted: false, value: 2],
//                "a": [[1-31], deleted: false, value: 1],
//                "c": [[3-31], deleted: false, value: 3]
//            ])
            let _ = try await ormap_2.mergeDelta(diff_a)
            XCTFail("When merging map 1 into map 2, the value `c` has conflicting metadata (one is deleted, the other not) so it should throw an exception.")
        } catch let CRDTMergeError.conflictingHistory(msg) {
            XCTAssertNotNil(msg)
            // print("error: \(msg)")
//        error: The metadata for the map key c is conflicting.
//                local: [[3-31], deleted: true, value: 3],
//                remote: [[3-13], deleted: false, value: 3].
        }

        // merge the diff from map 2 into map 1

        do {
//            print(ormap_1)
//            ORMap<UInt, String, Int>(
//                currentTimestamp: LamportTimestamp<3, 31>,
//                metadataByDictKey: [
//                    "c": [[3-31], deleted: false, value: 3],
//                    "a": [[1-31], deleted: false, value: 1],
//                    "b": [[2-31], deleted: false, value: 2]
//                ])
//            print(diff_b)
//            ORMapDelta(updates: [
//                "d": [[2-13], deleted: false, value: 4],
//                "c": [[3-13], deleted: true, value: 3]
//            ])
            let _ = try await ormap_1.mergeDelta(diff_b)
            XCTFail("When merging map 1 into map 2, the value `c` has conflicting metadata (one is deleted, the other not) so it should throw an exception.")
        } catch let CRDTMergeError.conflictingHistory(msg) {
            XCTAssertNotNil(msg)
            // print("error: \(msg)")
            // Example message:
            // The metadata for the set value 3 has conflicting timestamps. local: [[3-31], deleted: false], remote: [[3-13], deleted: true].
        }
    }

    func testMergeCausalUpdateMerge() async throws {
        var ormap_1 = ORMap<UInt, String, Int>(actorId: UInt(31), ["a": 1, "b": 2, "c": 3])
        var ormap_2 = ORMap<UInt, String, Int>(actorId: UInt(13))
        XCTAssertEqual(ormap_1.count, 3)
        XCTAssertEqual(ormap_2.count, 0)

        let replicatedDeltaFromInitial1 = await ormap_1.delta(await ormap_2.state)
        // diff_a is the delta from map 1
        XCTAssertNotNil(replicatedDeltaFromInitial1)
        XCTAssertEqual(replicatedDeltaFromInitial1.updates.count, 3)

        // overwrite ormap_2 with the version merged with 1
        ormap_2 = try await ormap_2.mergeDelta(replicatedDeltaFromInitial1)
        XCTAssertEqual(ormap_2.count, 3)
        XCTAssertEqual(ormap_2.values.sorted(), ormap_1.values.sorted())
        XCTAssertEqual(ormap_2.keys.sorted(), ormap_1.keys.sorted())

        // Update the first and second independently with the same 'causal' ordering and values
        ormap_2["d"] = 4
        ormap_1["d"] = 4
        XCTAssertEqual(ormap_1.count, 4)
        XCTAssertEqual(ormap_2.count, 4)

        // check the delta's in both directions:
        let replicatedDeltaFrom1 = await ormap_1.delta(await ormap_2.state)
        let replicatedDeltaFrom2 = await ormap_2.delta(await ormap_1.state)

        XCTAssertNotNil(replicatedDeltaFrom1)
        XCTAssertNotNil(replicatedDeltaFrom2)
        XCTAssertEqual(replicatedDeltaFrom1.updates.count, 1)
        XCTAssertEqual(replicatedDeltaFrom1.updates.count, 1)

        // This *should* be a legit merge, since the metadata isn't in conflict.
        do {
            ormap_2 = try await ormap_2.mergeDelta(replicatedDeltaFrom1)
            ormap_1 = try await ormap_1.mergeDelta(replicatedDeltaFrom2)
        } catch {
            // print(error)
            XCTFail()
        }
        XCTAssertEqual(ormap_2.values.sorted(), ormap_1.values.sorted())
        XCTAssertEqual(ormap_2.keys.sorted(), ormap_1.keys.sorted())
    }
}
