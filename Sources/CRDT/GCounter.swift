//
//  GCounter.swift
//

import Foundation

/// Implements a Grow-only Counter
/// Based on GCounter implementation as described in "Convergent and Commutative Replicated Data Types"
/// - SeeAlso: [A comprehensive study of Convergent and Commutative Replicated Data Types](https://hal.inria.fr/inria-00555588/document)” by Marc Shapiro, Nuno Preguiça, Carlos Baquero, and Marek Zawirski (2011).
public struct GCounter<ActorID: Hashable & Comparable, T: BinaryInteger> {
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

        // Note: this particular CRDT implementation doesn't rely on partial order of updates,
        // so this additional constraint (and implementation) could be dropped.

        // MARK: Conformance of LWWRegister.Atom to PartiallyOrderable

        public static func <= (lhs: Self, rhs: Self) -> Bool {
            // functionally equivalent to say rhs instance is ordered after lhs instance
            (lhs.timestamp, lhs.id) <= (rhs.timestamp, rhs.id)
        }
    }

    private var _storage: Atom
    internal let selfId: ActorID

    public var value: T {
        _storage.value
    }

    public mutating func increment() {
        let newAtom = Atom(value: _storage.value + T(1), id: selfId)
        _storage = newAtom
    }

    public init(_ value: T, actorID: ActorID, timestamp: TimeInterval? = nil) {
        selfId = actorID
        if let timestamp {
            _storage = Atom(value: value, id: selfId, timestamp: timestamp)
        } else {
            _storage = Atom(value: value, id: selfId)
        }
    }
}

extension GCounter: Replicable {
    public func merged(with other: Self) -> Self {
        var copy = self
        copy._storage = Atom(value: max(other.value, value), id: selfId)
        return copy
    }
}

extension GCounter: DeltaCRDT {
//    public typealias DeltaState = Self.Atom
//    public typealias Delta = Self.Atom
    public var state: Atom {
        _storage
    }

    public func delta(_: Atom?) -> [Atom] {
        [_storage]
    }

    public func mergeDelta(_ delta: [Atom]) -> Self {
        var copy = self
        var withLocalValue = delta
        withLocalValue.append(_storage)
        let maxValue = withLocalValue.reduce(into: T(0)) { partialResult, atom in
            partialResult = max(partialResult, atom.value)
        }
        copy._storage = Atom(value: maxValue, id: selfId)
        return copy
    }
}

extension GCounter: Codable where T: Codable, ActorID: Codable {}

extension GCounter.Atom: Codable where T: Codable, ActorID: Codable {}

extension GCounter: Equatable where T: Equatable {}

extension GCounter.Atom: Equatable where T: Equatable {}

extension GCounter: Hashable where T: Hashable {}

extension GCounter.Atom: Hashable where T: Hashable {}
