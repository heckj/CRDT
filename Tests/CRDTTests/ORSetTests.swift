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

    func testDeltaState_mergeDeltas() async {
        // equiv direct merge
        // let c = a.merged(with: b)
        let delta = await b.delta(a.state)
        let c = await a.mergeDelta(delta)
        XCTAssertEqual(c.values, b.values)
    }

    func testDeltaState_mergeDelta() async {
        // equiv direct merge
        // let c = a.merged(with: b)
        let delta = await b.delta(a.state)
        let c = await a.mergeDelta(delta)
        XCTAssertEqual(c.values, b.values)
    }
}
