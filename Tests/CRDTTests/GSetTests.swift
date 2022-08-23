//
//  GSetTests.swift
//

@testable import CRDT
import XCTest

final class GSetTests: XCTestCase {
    var a: GSet<String, Int>!
    var b: GSet<String, Int>!

    override func setUp() async throws {
        a = GSet(actorId: "a")
        b = GSet(actorId: "b", [99, 100, 101])
    }

    func testInitialCreation() {
        XCTAssertEqual(a.values.count, 0)
        XCTAssertEqual(a.currentTimestamp.actorId, "a")
        XCTAssertEqual(a.currentTimestamp.clock, 0)
        XCTAssertEqual(a.count, 0)

        XCTAssertEqual(b.count, 3)
        XCTAssertTrue(b.contains(101))
    }

    func testSettingValue() {
        a.insert(2)
        XCTAssertEqual(a.values, [2])
        a.insert(3)
        XCTAssertEqual(a.values, [2, 3])
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
        let c = GSet(actorId: "c", [200, 300, 400])
        let e = a.merged(with: b).merged(with: c)
        let f = a.merged(with: b.merged(with: c))
        XCTAssertEqual(e.values, f.values)
    }

    func testCodable() {
        let data = try! JSONEncoder().encode(b)
        let d = try! JSONDecoder().decode(GSet<String, Int>.self, from: data)
        XCTAssertEqual(b, d)
    }

    func testDeltaState_state() {
        let state = a.state
        XCTAssertNotNil(state)
        XCTAssertEqual(state.values, a.values)
    }

    func testDeltaState_delta() {
        let a_nil_delta = a.delta(nil)
        // print(a_nil_delta)
        XCTAssertNotNil(a_nil_delta)
        XCTAssertEqual(a_nil_delta.values, [])

        let a_delta = a.delta(b.state)
        XCTAssertNotNil(a_delta)
        XCTAssertEqual(a_delta.values, [])
    }

    func testDeltaState_mergeDeltas() {
        // equiv direct merge
        // let c = a.merged(with: b)
        let delta = b.delta(a.state)
        let c = a.mergeDelta(delta)
        XCTAssertEqual(c.values, b.values)
    }

    func testDeltaState_mergeDelta() {
        // equiv direct merge
        // let c = a.merged(with: b)
        let delta = b.delta(a.state)
        let c = a.mergeDelta(delta)
        XCTAssertEqual(c.values, b.values)
    }
}
