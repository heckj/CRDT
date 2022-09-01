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

    func testDeltaState_state() async {
        let state = a.state
        XCTAssertNotNil(state)
        XCTAssertEqual(state.clockId.actorId, a.selfId)
    }

    func testDeltaState_delta() async {
        guard let a_nil_delta = a.delta(nil) else {
            XCTFail("incorrectly returned no differences to replicate")
            return
        }
        // print(a_nil_delta)
        XCTAssertNotNil(a_nil_delta)
        XCTAssertEqual(a_nil_delta.value, 1)
        let a_state = a.state
        XCTAssertEqual(a_state.clockId.actorId, a.selfId)

        guard let a_delta = a.delta(b.state) else {
            XCTFail("incorrectly returned no differences to replicate")
            return
        }
        XCTAssertNotNil(a_delta)
        XCTAssertEqual(a_delta.value, 1)
    }

    func testDeltaState_mergeDelta() async {
        // equiv direct merge
        // let c = a.merged(with: b)
        guard let delta = b.delta(a.state) else {
            XCTFail("incorrectly returned no differences to replicate")
            return
        }
        XCTAssertNotNil(delta)
        let c = a.mergeDelta(delta)
        XCTAssertEqual(c.value, b.value)
    }
}
