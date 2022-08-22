//
//  PNCounter.swift
//

import Foundation

/// Implements a Positive-Negative Counter
/// Based on GCounter implementation as described in "Convergent and Commutative Replicated Data Types"
/// - SeeAlso: [A comprehensive study of Convergent and Commutative Replicated Data Types](https://hal.inria.fr/inria-00555588/document)” by Marc Shapiro, Nuno Preguiça, Carlos Baquero, and Marek Zawirski (2011).
public struct PNCounter<ActorID: Hashable & Comparable> {
    /// The replicated state structure for PNCounter
    public struct Atom: Identifiable, PartiallyOrderable {
        internal var pos_value: UInt
        internal var neg_value: UInt
        internal var timestamp: TimeInterval
        public var id: ActorID

        init(pos: UInt, neg: UInt, id: ActorID, timestamp: TimeInterval = Date().timeIntervalSinceReferenceDate) {
            pos_value = pos
            neg_value = neg
            self.timestamp = timestamp
            self.id = id
        }

        // Note: this particular CRDT implementation doesn't rely on partial order of updates,
        // so this additional constraint (and implementation) could be dropped - but then we'd have
        // to have a looser definition of delta-CRDT.

        // MARK: Conformance of LWWRegister.Atom to PartiallyOrderable

        public static func <= (lhs: Self, rhs: Self) -> Bool {
            // functionally equivalent to say rhs instance is ordered after lhs instance
            (lhs.timestamp, lhs.id) <= (rhs.timestamp, rhs.id)
        }
    }

    private var _storage: Atom
    internal let selfId: ActorID

    public var value: Int {
        // ternary operator, since I can never entirely remember the sequence:
        // expression ? valueIfTrue : valueIfFalse

        // clamp UInt values to maximum Int values to avoid overflowing the runtime conversion
        let pos_int: Int = _storage.pos_value <= Int.max ? Int(_storage.pos_value) : Int.max
        let neg_int: Int = _storage.neg_value <= Int.max ? Int(_storage.neg_value) : Int.max

        return pos_int - neg_int
    }

    public mutating func increment() {
        let newAtom = Atom(pos: _storage.pos_value + 1, neg: _storage.neg_value, id: selfId)
        _storage = newAtom
    }

    public mutating func decrement() {
        let newAtom = Atom(pos: _storage.pos_value, neg: _storage.neg_value + 1, id: selfId)
        _storage = newAtom
    }

    public init(_ value: Int = 0, actorID: ActorID, timestamp: TimeInterval? = nil) {
        selfId = actorID
        let pos: UInt
        let neg: UInt
        if value >= 0 {
            pos = UInt(value)
            neg = 0
        } else {
            pos = 0
            neg = value > Int.min ? UInt(abs(value)) : UInt(abs(Int.min + 1))
        }
        if let timestamp = timestamp {
            _storage = Atom(pos: pos, neg: neg, id: selfId, timestamp: timestamp)
        } else {
            _storage = Atom(pos: pos, neg: neg, id: selfId)
        }
    }
}

extension PNCounter: Replicable {
    public func merged(with other: Self) -> Self {
        var copy = self
        copy._storage = Atom(pos: max(other._storage.pos_value, _storage.pos_value), neg: max(other._storage.neg_value, _storage.neg_value), id: selfId)
        return copy
    }
}

extension PNCounter: DeltaCRDT {
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
        let maxPosValue = withLocalValue.reduce(into: 0) { partialResult, atom in
            partialResult = max(partialResult, atom.pos_value)
        }
        let maxNegValue = withLocalValue.reduce(into: 0) { partialResult, atom in
            partialResult = max(partialResult, atom.neg_value)
        }
        copy._storage = Atom(pos: maxPosValue, neg: maxNegValue, id: selfId)
        return copy
    }
}

extension PNCounter: Codable where ActorID: Codable {}

extension PNCounter.Atom: Codable where ActorID: Codable {}

extension PNCounter: Equatable {}

extension PNCounter.Atom: Equatable {}

extension PNCounter: Hashable {}

extension PNCounter.Atom: Hashable {}
