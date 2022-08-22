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
    /// The replicated state structure for LWWRegister
    public struct Atom: Identifiable, PartiallyOrderable {
        var value: T
        var timestamp: TimeInterval
        public var id: ActorID

        init(value: T, id: ActorID, timestamp: TimeInterval = Date().timeIntervalSinceReferenceDate) {
            self.value = value
            self.timestamp = timestamp
            self.id = id
        }

        // MARK: Conformance of LWWRegister.Atom to PartiallyOrderable

        public static func <= (lhs: Self, rhs: Self) -> Bool {
            // functionally equivalent to say rhs instance is ordered after lhs instance
            // print("lhs \(lhs.timestamp), \(lhs.id) <=? rhs \(rhs.timestamp), \(rhs.id)")
            (lhs.timestamp, lhs.id) <= (rhs.timestamp, rhs.id)
        }
    }

    private var entry: Atom
    internal let selfId: ActorID

    public var value: T {
        get {
            entry.value
        }
        set {
            entry = Atom(value: newValue, id: selfId)
        }
    }

    public init(_ value: T, actorID: ActorID, timestamp: TimeInterval? = nil) {
        selfId = actorID
        if let timestamp {
            entry = Atom(value: value, id: selfId, timestamp: timestamp)
        } else {
            entry = Atom(value: value, id: selfId)
        }
    }
}

extension LWWRegister: Replicable {
    public func merged(with other: LWWRegister) -> LWWRegister {
        // ternary operator, since I can never entirely remember the sequence:
        // expression ? valueIfTrue : valueIfFalse
        entry <= other.entry ? other : self
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

    public func mergeDelta(_ delta: [Atom]) -> Self {
        var newLWW = self
        if let lastDelta = delta.last {
            newLWW.entry = entry <= lastDelta ? lastDelta : entry
        }
        return newLWW
    }
}

extension LWWRegister: Codable where T: Codable, ActorID: Codable {}

extension LWWRegister.Atom: Codable where T: Codable, ActorID: Codable {}

extension LWWRegister: Equatable where T: Equatable {}

extension LWWRegister.Atom: Equatable where T: Equatable {}

extension LWWRegister: Hashable where T: Hashable {}

extension LWWRegister.Atom: Hashable where T: Hashable {}
