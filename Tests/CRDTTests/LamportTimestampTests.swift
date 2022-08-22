//
//  LamportTimestampTests.swift
//

@testable import CRDT
import XCTest

final class LamportTimestampTests: XCTestCase {
    func testInitialization() throws {
        let ts = LamportTimestamp(id: 1)
        XCTAssertEqual(ts.clock, 0)
        XCTAssertEqual(ts.id, 1)
    }

    func testTick() throws {
        var ts = LamportTimestamp(id: 1)
        XCTAssertEqual(ts.clock, 0)
        XCTAssertEqual(ts.id, 1)
        ts.tick()
        XCTAssertEqual(ts.clock, 1)
        XCTAssertEqual(ts.id, 1)
    }

    func testComparison() throws {
        var ts1 = LamportTimestamp(id: 1)
        var ts2 = LamportTimestamp(id: 2)
        // partial ordering is by count FIRST, then by ID if equal
        XCTAssertTrue(ts1 < ts2)
        XCTAssertEqual(ts1.clock, ts2.clock)

        ts1.tick()
        XCTAssertTrue(ts1.clock > ts2.clock)
        XCTAssertFalse(ts1 < ts2)

        ts2.tick()
        XCTAssertTrue(ts1 < ts2)
        XCTAssertEqual(ts1.clock, ts2.clock)
    }
}
