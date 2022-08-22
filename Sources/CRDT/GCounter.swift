//
//  GCounter.swift
//

import Foundation

/// Implements a Grow-only Counter
/// Based on GCounter implementation as described in "Convergent and Commutative Replicated Data Types"
/// - SeeAlso: [A comprehensive study of Convergent and Commutative Replicated Data Types](https://hal.inria.fr/inria-00555588/document)” by Marc Shapiro, Nuno Preguiça, Carlos Baquero, and Marek Zawirski (2011).
public struct GCounter<ActorID: Hashable & Comparable> {
    /// The replicated state structure for GCounter
    public struct Atom: Identifiable, PartiallyOrderable {
        internal var clockId: WallclockTimestamp<ActorID>
        internal var value: UInt

        /// The identity of the counter metadata (atom) computed from the actor Id and a current timestamp.
        public var id: String {
            clockId.id
        }

        internal init(value: UInt, id: ActorID, timestamp: TimeInterval = Date().timeIntervalSinceReferenceDate) {
            self.value = value
            clockId = WallclockTimestamp(actorId: id, timestamp: timestamp)
        }

        // Note: this particular CRDT implementation doesn't rely on partial order of updates,
        // so this additional constraint (and implementation) could be dropped - but then we'd have
        // to have a looser definition of delta-CRDT.

        // MARK: Conformance of LWWRegister.Atom to PartiallyOrderable

        public static func <= (lhs: Self, rhs: Self) -> Bool {
            // functionally equivalent to say rhs instance is ordered after lhs instance
            lhs.clockId <= rhs.clockId
        }
    }

    private var _storage: Atom
    internal let selfId: ActorID

    public var value: UInt {
        _storage.value
    }

    public mutating func increment() {
        if _storage.value != UInt.max {
            let newAtom = Atom(value: _storage.value + 1, id: selfId)
            _storage = newAtom
        }
    }

    public init(_ value: UInt = 0, actorID: ActorID, timestamp: TimeInterval? = nil) {
        selfId = actorID
        if let timestamp = timestamp {
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
        let maxValue = withLocalValue.reduce(into: 0) { partialResult, atom in
            partialResult = max(partialResult, atom.value)
        }
        copy._storage = Atom(value: maxValue, id: selfId)
        return copy
    }
}

extension GCounter: Codable where ActorID: Codable {}

extension GCounter.Atom: Codable where ActorID: Codable {}

extension GCounter: Equatable {}

extension GCounter.Atom: Equatable {}

extension GCounter: Hashable {}

extension GCounter.Atom: Hashable {}
