//
//  PNCounterTests.swift
//

@testable import CRDT
import XCTest

final class PNCounterTests: XCTestCase {
    var a: PNCounter<String>!
    var b: PNCounter<String>!

    override func setUp() {
        super.setUp()
        a = .init(1, actorID: UUID().uuidString)
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

    func testDecrementingValue() {
        a.decrement()
        XCTAssertEqual(a.value, 0)
        a.decrement()
        XCTAssertEqual(a.value, -1)
        // internals:
        XCTAssertEqual(a.pos_value, 1)
        XCTAssertEqual(a.neg_value, 2)
    }

    func testIncrementOverflow() {
        var x = PNCounter(Int.max, actorID: UUID().uuidString)
        x.increment()
        XCTAssertEqual(x.value, Int.max)
    }

    func testDecrementOverflow() {
        var x = PNCounter(Int.min, actorID: UUID().uuidString)
        x.decrement()
        XCTAssertEqual(x.value, Int.min + 1)
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
        let c: PNCounter<String> = .init(3, actorID: UUID().uuidString)
        let e = a.merged(with: b).merged(with: c)
        let f = a.merged(with: b.merged(with: c))
        XCTAssertEqual(e.value, f.value)
    }

    func testCodable() {
        let data = try! JSONEncoder().encode(a)
        let d = try! JSONDecoder().decode(PNCounter<String>.self, from: data)
        XCTAssertEqual(a, d)
    }

    func testDeltaState_state() async {
        let atom = await a.state
        XCTAssertNotNil(atom)
        XCTAssertEqual(a.value, Int(atom.pos) - Int(atom.neg))
    }

    func testDeltaState_delta() async {
        let a_nil_delta = await a.delta(nil)
        // print(a_nil_delta)
        XCTAssertNotNil(a_nil_delta)
        XCTAssertEqual(a_nil_delta.pos, 1)
        XCTAssertEqual(a_nil_delta.neg, 0)

        let a_delta = await a.delta(b.state)
        XCTAssertNotNil(a_delta)
        XCTAssertEqual(a_delta.pos, 1)
        XCTAssertEqual(a_delta.neg, 0)
    }

    func testDeltaState_mergeDelta() async {
        // equiv direct merge
        // let c = a.merged(with: b)
        let c = await a.mergeDelta(await b.delta(a.state))
        XCTAssertEqual(c.value, b.value)
    }
}
