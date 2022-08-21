//
//  LWWRegister.swift
//
// Based on code written by Drew McCormack on 29/04/2020.
// Used under MIT License
// Source: https://github.com/appdecentral/replicatingtypes/blob/master/Sources/ReplicatingTypes/ReplicatingRegister.swift

import Foundation
/// Implements Last-Writer-Wins Register
/// Based on LWWRegister implementation as described in "Convergent and Commutative Replicated Data Types"
/// - SeeAlso: [A comprehensive study of Convergent and Commutative Replicated Data Types](https://hal.inria.fr/inria-00555588/document)” by Marc Shapiro, Nuno Preguiça, Carlos Baquero, and Marek Zawirski (2011).
public struct LWWRegister<ActorID: Hashable & Comparable, T> {
    public struct Atom: Identifiable, PartiallyOrderable {
        var value: T
        var timestamp: TimeInterval
        public var id: ActorID

        init(value: T, id: ActorID, timestamp: TimeInterval = Date().timeIntervalSinceReferenceDate) {
            self.value = value
            self.timestamp = timestamp
            self.id = id
        }

        public static func <= (lhs: LWWRegister<ActorID, T>.Atom, rhs: LWWRegister<ActorID, T>.Atom) -> Bool {
            // functionally equivalent to say rhs instance is ordered after lhs instance
            (lhs.timestamp, lhs.id) <= (rhs.timestamp, rhs.id)
        }

        // not using Comparable because that requires T to be 'comparable' as well, but we want to be able to assert
        // partial ordering here
        func isOrdered(after other: Atom) -> Bool {
            (timestamp, id) > (other.timestamp, other.id)
        }
    }

    private var entry: Atom
    private var selfId: ActorID

    public var value: T {
        get {
            entry.value
        }
        set {
            entry = Atom(value: newValue, id: selfId)
        }
    }

    public init(_ value: T, actorID: ActorID) {
        selfId = actorID
        entry = Atom(value: value, id: selfId)
    }
}

extension LWWRegister: Replicable {
    public func merged(with other: LWWRegister) -> LWWRegister {
        // ternary operator:
        // expression ? valueIfTrue : valueIfFalse
        entry <= other.entry ? other : self
//        entry.isOrdered(after: other.entry) ? self : other
    }
}

extension LWWRegister: DeltaCRDT {
//    public typealias DeltaState = Self.Atom
//    public typealias Delta = Self.Atom
    public var state: Atom {
        entry
    }

    public func delta(_: Atom?) -> [Atom] {
        [entry]
    }

    public mutating func mergeDelta(_ delta: [Atom]) {
        if let lastDelta = delta.last {
            entry = entry <= lastDelta ? lastDelta : entry
        }
    }
}

extension LWWRegister: Codable where T: Codable, ActorID: Codable {}

extension LWWRegister.Atom: Codable where T: Codable, ActorID: Codable {}

extension LWWRegister: Equatable where T: Equatable {}

extension LWWRegister.Atom: Equatable where T: Equatable {}

extension LWWRegister: Hashable where T: Hashable {}

extension LWWRegister.Atom: Hashable where T: Hashable {}
