//
//  LWWRegister.swift
//
// Based on code written by Drew McCormack on 29/04/2020.
// Used under MIT License
// Source: https://github.com/appdecentral/replicatingtypes/blob/master/Sources/ReplicatingTypes/ReplicatingRegister.swift

import Foundation
/// Implements Last-Writer-Wins Register
/// Based on Convergent and commutative replicated data types by M Shapiro, N Preguiça, C Baquero, M Zawirski - 2011 - hal.inria.fr
public struct LWWRegister<T> {
    fileprivate struct Entry: Identifiable {
        var value: T
        var timestamp: TimeInterval
        var id: UUID

        init(value: T, timestamp: TimeInterval = Date().timeIntervalSinceReferenceDate, id: UUID = UUID()) {
            self.value = value
            self.timestamp = timestamp
            self.id = id
        }

        func isOrdered(after other: Entry) -> Bool {
            (timestamp, id.uuidString) > (other.timestamp, other.id.uuidString)
        }
    }

    private var entry: Entry

    public var value: T {
        get {
            entry.value
        }
        set {
            entry = Entry(value: newValue)
        }
    }

    public init(_ value: T) {
        entry = Entry(value: value)
    }
}

extension LWWRegister: Replicable {
    public func merged(with other: LWWRegister) -> LWWRegister {
        entry.isOrdered(after: other.entry) ? self : other
    }
}

extension LWWRegister: Codable where T: Codable {}

extension LWWRegister.Entry: Codable where T: Codable {}

extension LWWRegister: Equatable where T: Equatable {}

extension LWWRegister.Entry: Equatable where T: Equatable {}

extension LWWRegister: Hashable where T: Hashable {}

extension LWWRegister.Entry: Hashable where T: Hashable {}
