//
//  DocTests.swift
//

import CRDT
import Foundation
import XCTest

// These tests are placeholders in order to verify code examples in the documentation work as expected.

// used in ReplicatingCRDTs.md
extension UUID: Comparable {
    public static func < (lhs: UUID, rhs: UUID) -> Bool {
        lhs.uuidString < rhs.uuidString
    }
}

final class DocTests: XCTestCase {
    func testReplicatingCRDTs_1() throws {
        // used in ReplicatingCRDTs.md
        let register = LWWRegister("Hello", actorID: UUID().uuidString)

        XCTAssertNotNil(register)
    }

    func testReplicatingCRDTs_2() throws {
        // used in ReplicatingCRDTs.md
        let register = LWWRegister("Hello", actorID: UUID())

        XCTAssertNotNil(register)
    }

    func testReplicatingCRDTs_3() throws {
        // used in ReplicatingCRDTs.md
        let register = LWWRegister("Hello", actorID: UUID())

        let data = try JSONEncoder().encode(register)
        let strRep = String(decoding: data, as: UTF8.self)
        print(strRep)
        // {"selfId":"89A9244B-2577-484E-9151-0830C8662BD6","_storage":{"value":"Hello","clockId":{"clock":683694177.84892404,"actorId":"89A9244B-2577-484E-9151-0830C8662BD6"}}}

        let regenerated = try JSONDecoder().decode(LWWRegister<UUID, String>.self, from: data)
        XCTAssertEqual(register, regenerated)

        let updated = register.merged(with: regenerated)
        XCTAssertEqual(updated, regenerated)

        var remoteRegister = register
        remoteRegister.merging(with: regenerated)
        XCTAssertEqual(remoteRegister, regenerated)
    }

    func testReplicatingCRDTs_4() throws {
        // used in ReplicatingCRDTs.md
        let register = LWWRegister("Hello", actorID: UUID())

        let data = try JSONEncoder().encode(register.state)
        let strRep = String(decoding: data, as: UTF8.self)
        print(strRep)
        // {"clockId":{"clock":683695946.55028403,"actorId":"C98A69EE-59C5-4739-8395-988B37D8B48B"}}

        let regeneratedState = try JSONDecoder().decode(LWWRegister<UUID, String>.DeltaState.self, from: data)
        XCTAssertEqual(register.state, regeneratedState)

        let remoteRegister = LWWRegister<UUID, String>("", actorID: UUID())
        let delta = register.delta(remoteRegister.state)!

        let updated = register.mergeDelta(delta)
        XCTAssertEqual(updated, register)

        let fullDelta = register.delta(nil)
        XCTAssertNotNil(fullDelta)
    }
}
