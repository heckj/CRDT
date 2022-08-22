//
//  GCounterTests.swift
//

@testable import CRDT
import XCTest

final class GCounterTests: XCTestCase {
    var a: GCounter<String>!
    var b: GCounter<String>!

    override func setUp() {
        super.setUp()
        a = .init(1, actorID: UUID().uuidString, timestamp: Date().timeIntervalSinceReferenceDate - 1.0)
        b = .init(2, actorID: UUID().uuidString)
    }

    func testInitialCreation() {
        XCTAssertEqual(a.value, 1)
    }

    func testIncrementingValue() {
        a.increment()
        XCTAssertEqual(a.value, 2)
        a.increment()
        XCTAssertEqual(a.value, 3)
    }

    func testIncrementOverflow() {
        var x = GCounter(UInt.max, actorID: UUID().uuidString)
        x.increment()
        XCTAssertEqual(x.value, UInt.max)
    }

    func testMergeOfInitiallyUnrelated() {
        let c = a.merged(with: b)
        XCTAssertEqual(c.value, b.value)
    }

    func testLastChangeWins() {
        a.increment()
        a.increment()
        let c = a.merged(with: b)
        XCTAssertEqual(c.value, a.value)
    }

    func testIdempotency() {
        let c = a.merged(with: b)
        let d = c.merged(with: b)
        let e = c.merged(with: a)
        XCTAssertEqual(c.value, d.value)
        XCTAssertEqual(c.value, e.value)
    }

    func testCommutativity() {
        let c = a.merged(with: b)
        let d = b.merged(with: a)
        XCTAssertEqual(d.value, c.value)
    }

    func testAssociativity() {
        let c: GCounter<String> = .init(3, actorID: UUID().uuidString)
        let e = a.merged(with: b).merged(with: c)
        let f = a.merged(with: b.merged(with: c))
        XCTAssertEqual(e.value, f.value)
    }

    func testCodable() {
        let data = try! JSONEncoder().encode(a)
        let d = try! JSONDecoder().decode(GCounter<String>.self, from: data)
        XCTAssertEqual(a, d)
    }

    func testDeltaState_state() {
        let atom = a.state
        XCTAssertNotNil(atom)
        XCTAssertEqual(atom.value, a.value)
        XCTAssertNotNil(atom.id)
        XCTAssertEqual(atom.clockId.actorId, a.selfId)
    }

    func testDeltaState_delta() {
        let a_nil_delta = a.delta(nil)
        // print(a_nil_delta)
        XCTAssertNotNil(a_nil_delta)
        XCTAssertEqual(a_nil_delta.count, 1)
        XCTAssertEqual(a_nil_delta[0].value, 1)
        XCTAssertEqual(a_nil_delta[0], a.state)

        let a_delta = a.delta(b.state)
        XCTAssertNotNil(a_delta)
        XCTAssertEqual(a_delta.count, 1)
        XCTAssertEqual(a_delta[0].value, 1)
        XCTAssertEqual(a_delta[0], a.state)
    }

    func testDeltaState_mergeDeltas() {
        // equiv direct merge
        // let c = a.merged(with: b)
        let c = a.mergeDelta([b.state])
        XCTAssertEqual(c.value, b.value)
    }

    func testDeltaState_mergeEmptyDeltas() {
        let c = a.mergeDelta([])
        XCTAssertEqual(c.value, a.value)
    }

    func testDeltaState_mergeDelta() {
        // equiv direct merge
        // let c = a.merged(with: b)
        let c = a.mergeDelta(b.state)
        XCTAssertEqual(c.value, b.value)
    }
}
