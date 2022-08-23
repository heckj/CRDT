//
//  LWWRegisterTests.swift
//

@testable import CRDT
import XCTest

final class LWWRegisterTests: XCTestCase {
    var a: LWWRegister<String, Int>!
    var b: LWWRegister<String, Int>!

    override func setUp() {
        super.setUp()
        a = .init(1, actorID: UUID().uuidString, timestamp: Date().timeIntervalSinceReferenceDate - 1.0)
        b = .init(2, actorID: UUID().uuidString)
    }

    func testInitialCreation() {
        XCTAssertEqual(a.value, 1)
    }

    func testSettingValue() {
        a.value = 2
        XCTAssertEqual(a.value, 2)
        a.value = 3
        XCTAssertEqual(a.value, 3)
    }

    func testMergeOfInitiallyUnrelated() {
        let c = a.merged(with: b)
        XCTAssertEqual(c.value, b.value)
    }

    func testLastChangeWins() {
        a.value = 3
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
        let c: LWWRegister<String, Int> = .init(3, actorID: UUID().uuidString)
        let e = a.merged(with: b).merged(with: c)
        let f = a.merged(with: b.merged(with: c))
        XCTAssertEqual(e.value, f.value)
    }

    func testCodable() {
        let data = try! JSONEncoder().encode(a)
        let d = try! JSONDecoder().decode(LWWRegister<String, Int>.self, from: data)
        XCTAssertEqual(a, d)
    }

    func testDeltaState_state() {
        let atom = a.state
        XCTAssertNotNil(atom)
        XCTAssertEqual(atom.value, a.value)
        XCTAssertEqual(atom.clockId.actorId, a.selfId)
    }

    func testDeltaState_delta() {
        let a_nil_delta = a.delta(nil)
        // print(a_nil_delta)
        XCTAssertNotNil(a_nil_delta)
        XCTAssertEqual(a_nil_delta.value, 1)
        XCTAssertEqual(a_nil_delta, a.state)

        let a_delta = a.delta(b.state)
        XCTAssertNotNil(a_delta)
        XCTAssertEqual(a_delta.value, 1)
        XCTAssertEqual(a_delta, a.state)
    }

    func testDeltaState_mergeDelta() {
        // equiv direct merge
        // let c = a.merged(with: b)
        let delta = b.delta(a.state)
        XCTAssertNotNil(delta)
        let c = a.mergeDelta(delta)
        XCTAssertEqual(c.value, b.value)
    }
}
