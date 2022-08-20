//
//  LWWRegisterTests.swift
//

@testable import CRDT
import XCTest

final class LWWRegisterTests: XCTestCase {
    var a: LWWRegister<Int>!
    var b: LWWRegister<Int>!

    override func setUp() {
        super.setUp()
        a = .init(1)
        b = .init(2)
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
        let c: LWWRegister<Int> = .init(3)
        let e = a.merged(with: b).merged(with: c)
        let f = a.merged(with: b.merged(with: c))
        XCTAssertEqual(e.value, f.value)
    }

    func testCodable() {
        let data = try! JSONEncoder().encode(a)
        let d = try! JSONDecoder().decode(LWWRegister<Int>.self, from: data)
        XCTAssertEqual(a, d)
    }
}
