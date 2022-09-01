//
//  ListTests.swift
//

@testable import CRDT
import XCTest

extension List {
    func verifyListConsistency() {
        if let msg = Metadata.verifyCausalTreeConsistency(self.tombstones + self.activeValues) {
            XCTFail(msg)
        }
    }
}

final class ListTests: XCTestCase {
    var a: List<String, String>!
    var b: List<String, String>!

    override func setUp() async throws {
        a = List(actorId: "a", ["a"])
        b = List(actorId: "b", ["h", "e", "l", "l", "o"])
        b.append("!")
        b.remove(at: 5)
    }
    
    func testBareInit() {
        let z = List<String, String>(actorId: "∂")
        XCTAssertEqual(z.values.count, 0)
        XCTAssertEqual(z.currentTimestamp.actorId, "∂")
        XCTAssertEqual(z.currentTimestamp.clock, 0)
        XCTAssertEqual(z.count, 0)
        XCTAssertEqual(z.values, [])
        XCTAssertEqual(z.tombstones.count, 0)
        z.verifyListConsistency()
    }

    func testInitialCreation() {
        XCTAssertEqual(a.values.count, 1)
        XCTAssertEqual(a.currentTimestamp.actorId, "a")
        XCTAssertEqual(a.currentTimestamp.clock, 1)
        XCTAssertEqual(a.count, 1)
        XCTAssertEqual(a.values, ["a"])
        XCTAssertEqual(a.tombstones.count, 0)
        a.verifyListConsistency()
        
        XCTAssertEqual(b.count, 5)
        XCTAssertEqual(b.currentTimestamp.clock, 6)
        XCTAssertEqual(b.tombstones.count, 1)
        b.verifyListConsistency()
    }

    func testAppendingValue() {
        b.append("!")
        XCTAssertEqual(b.values, ["h", "e", "l", "l", "o", "!"])
        b.verifyListConsistency()
    }

    func testGettingBySubscript() {
        XCTAssertEqual(b[1], "e")
    }

    func testUpdatingBySubscript() {
        b[1] = "a"
        XCTAssertEqual(b.values, ["h", "a", "l", "l", "o"])

        XCTAssertEqual(b.count, 5)
        XCTAssertEqual(b.currentTimestamp.clock, 7)
        XCTAssertEqual(b.tombstones.count, 2)
        b.verifyListConsistency()
    }

    func testRemovingValue() {
        b.remove(at: 4)
        XCTAssertEqual(b.values, ["h", "e", "l", "l"])
        XCTAssertEqual(b.activeValues.count, 4)
        XCTAssertEqual(b.tombstones.count, 2)
        b.verifyListConsistency()
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
        c.verifyListConsistency()
        d.verifyListConsistency()
        e.verifyListConsistency()
    }

    func testCommutativity() {
        let c = a.merged(with: b)
        let d = b.merged(with: a)
        XCTAssertEqual(d.values, c.values)
        c.verifyListConsistency()
        d.verifyListConsistency()
    }

    func testAssociativity() {
        let c = List(actorId: "c", ["z", "y", "x"])
        let e = a.merged(with: b).merged(with: c)
        let f = a.merged(with: b.merged(with: c))
        XCTAssertEqual(e.values, f.values)
        c.verifyListConsistency()
        e.verifyListConsistency()
        f.verifyListConsistency()
    }

    func testInplaceMerging() {
        let c = a.merged(with: b)
        a.merging(with: b)
        XCTAssertEqual(c.values, a.values)
        c.verifyListConsistency()
    }

    func testCodable() {
        let data = try! JSONEncoder().encode(b)
        let d = try! JSONDecoder().decode(List<String, String>.self, from: data)
        XCTAssertEqual(b, d)
        d.verifyListConsistency()
    }

    func testMetadataDescription() {
        XCTAssertEqual(a.activeValues[0].description, "[nil<-[1-a], deleted: false, value: a]")
        XCTAssertEqual(b.activeValues[4].description, "[[4-b]<-[5-b], deleted: false, value: o]")
    }

    func testDeltaState_stateA() async {
        let state = a.state
        XCTAssertNotNil(state)
        XCTAssertEqual(Array(state.maxActiveClockValueByActor.keys), [a.currentTimestamp.actorId])
        XCTAssertEqual(Array(state.maxActiveClockValueByActor.values), [a.currentTimestamp.clock])
        XCTAssertEqual(Array(state.maxTombstoneClockValueByActor.keys), [])
        XCTAssertEqual(Array(state.maxTombstoneClockValueByActor.values), [])
    }

    func testDeltaState_stateB() async {
        let state = b.state
        XCTAssertNotNil(state)
        XCTAssertEqual(Array(state.maxActiveClockValueByActor.keys), ["b"])
        XCTAssertEqual(Array(state.maxActiveClockValueByActor.values), [5])
        XCTAssertEqual(Array(state.maxTombstoneClockValueByActor.keys), ["b"])
        XCTAssertEqual(Array(state.maxTombstoneClockValueByActor.values), [6])
    }

    func testDeltaState_nilDelta() async {
        let a_nil_delta = a.delta(nil)
        // print(a_nil_delta)
        XCTAssertNotNil(a_nil_delta)
        XCTAssertEqual(a_nil_delta.values.count, 1)
        XCTAssertEqual(a_nil_delta.values, a.activeValues)
    }

    func testDeltaState_deltaFromA() async {
        let a_delta = a.delta(b.state)
        XCTAssertEqual(a_delta.values.count, 1)
        XCTAssertEqual(a_delta.values.filter(\.isDeleted).map(\.value), [])
        XCTAssertEqual(a_delta.values.filter { !$0.isDeleted }.map(\.value), ["a"])
    }

    func testDeltaState_deltaFromB() async {
        let b_delta = b.delta(a.state)
        XCTAssertEqual(b_delta.values.count, 6)
        XCTAssertEqual(b_delta.values.filter(\.isDeleted).map(\.value), ["!"])
        XCTAssertEqual(b_delta.values.filter { !$0.isDeleted }.map(\.value), ["h", "e", "l", "l", "o"])
    }

    func testDeltaState_mergeDeltasFromB() async throws {
        // equiv direct merge
        // let c = a.merged(with: b)
        let delta = b.delta(a.state)
        let c = try a.mergeDelta(delta)
        XCTAssertEqual(c.values, ["h", "e", "l", "l", "o", "a"])
        XCTAssertEqual(c.tombstones.count, 1)
        c.verifyListConsistency()
    }

    func testDeltaState_mergeDeltaFromA() async throws {
        // equiv direct merge
        // let c = a.merged(with: b)
        let delta = b.delta(a.state)
        let c = try a.mergeDelta(delta)
        XCTAssertEqual(c.values, ["h", "e", "l", "l", "o", "a"])
        XCTAssertEqual(c.tombstones.count, 1)
        c.verifyListConsistency()
    }

    func testCorruptedDeltaMerge() async throws {
        let delta = b.delta(a.state)
        let corruptedDeltaValues = Array(delta.values.dropFirst(1))
        let corruptedDelta = List.CausalTreeDelta(values: corruptedDeltaValues)
        do {
            let _ = try a.mergeDelta(corruptedDelta)
            XCTFail("Allowed corrupted merge to go through")
        } catch {
            XCTAssertNotNil(error)
            print(error)
        }
    }
    
    func testMergeSameCausalUpdateMerge() async throws {
        var list1 = List<Int, Int>(actorId: 13, [1, 2, 3, 4, 5])
        var list2 = List<Int, Int>(actorId: 22)

        XCTAssertEqual(list1.count, 5)
        XCTAssertEqual(list2.count, 0)

        let replicatedDeltaFromInitial1 = list1.delta(list2.state)
        // diff_a is the delta from map 1
        XCTAssertNotNil(replicatedDeltaFromInitial1)
        XCTAssertEqual(replicatedDeltaFromInitial1.values.count, 5)

        // overwrite list2 with the version merged with 1
        list2 = try list2.mergeDelta(replicatedDeltaFromInitial1)
        XCTAssertEqual(list2.count, 5)
        XCTAssertEqual(list2.values, list1.values)

        // Update the first and second independently with the same 'causal' ordering and values
        list1.append(4)
        list2.append(5)
        XCTAssertEqual(list1.count, 6)
        XCTAssertEqual(list2.count, 6)

        // check the delta's in both directions:
        let replicatedDeltaFrom1 = list1.delta(list2.state)
        let replicatedDeltaFrom2 = list2.delta(list1.state)

        XCTAssertNotNil(replicatedDeltaFrom1)
        XCTAssertNotNil(replicatedDeltaFrom2)
        XCTAssertEqual(replicatedDeltaFrom1.values.count, 1)
        XCTAssertEqual(replicatedDeltaFrom2.values.count, 1)

        // This *should* be a legit merge, since the metadata isn't in conflict.
        do {
            list2 = try list2.mergeDelta(replicatedDeltaFrom1)
            list1 = try list1.mergeDelta(replicatedDeltaFrom2)
        } catch {
            // print(error)
            XCTFail()
        }
        XCTAssertEqual(list2.values, list1.values)
        list1.verifyListConsistency()
        list2.verifyListConsistency()
    }

    func testMergeDifferentCausalUpdateMerge() async throws {
        var list1 = List<Int, Int>(actorId: 13, [1, 2, 3, 4, 5])
        var list2 = List<Int, Int>(actorId: 22)
        XCTAssertEqual(list1.count, 5)
        XCTAssertEqual(list2.count, 0)

        let replicatedDeltaFromInitial1 = list1.delta(list2.state)
        // diff_a is the delta from map 1
        XCTAssertNotNil(replicatedDeltaFromInitial1)
        XCTAssertEqual(replicatedDeltaFromInitial1.values.count, 5)

        // overwrite list2 with the version merged with 1
        list2 = try list2.mergeDelta(replicatedDeltaFromInitial1)
        XCTAssertEqual(list2.count, 5)
        XCTAssertEqual(list2.values, list1.values)

        list1.append(4)
        list2.remove(at: 0)
        XCTAssertEqual(list1.count, 6)
        XCTAssertEqual(list2.count, 4)

        // check the delta's in both directions:
        let replicatedDeltaFrom1 = list1.delta(list2.state)
        let replicatedDeltaFrom2 = list2.delta(list1.state)

        XCTAssertNotNil(replicatedDeltaFrom1)
        XCTAssertNotNil(replicatedDeltaFrom2)
        XCTAssertEqual(replicatedDeltaFrom1.values.count, 1)
        XCTAssertEqual(replicatedDeltaFrom2.values.count, 1)

        // This *should* be a legit merge, since the metadata isn't in conflict.
        do {
            list2 = try list2.mergeDelta(replicatedDeltaFrom1)
            list1 = try list1.mergeDelta(replicatedDeltaFrom2)
        } catch {
            // print(error)
            XCTFail()
        }
        XCTAssertEqual(list2.values, list1.values)
        list1.verifyListConsistency()
        list2.verifyListConsistency()
    }
}
