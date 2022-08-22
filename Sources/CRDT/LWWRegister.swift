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
        internal var value: T
        internal var clockId: WallclockTimestamp<ActorID>

        /// The identity of the counter metadata (atom) computed from the actor Id and a current timestamp.
        public var id: String {
            clockId.id
        }

        init(value: T, id: ActorID, timestamp: TimeInterval = Date().timeIntervalSinceReferenceDate) {
            self.value = value
            clockId = WallclockTimestamp(actorId: id, timestamp: timestamp)
        }

        // MARK: Conformance of LWWRegister.Atom to PartiallyOrderable

        public static func <= (lhs: Self, rhs: Self) -> Bool {
            // functionally equivalent to say rhs instance is ordered after lhs instance
            // print("lhs \(lhs.timestamp), \(lhs.id) <=? rhs \(rhs.timestamp), \(rhs.id)")
            lhs.clockId <= rhs.clockId
        }
    }

    private var _storage: Atom
    internal let selfId: ActorID

    public var value: T {
        get {
            _storage.value
        }
        set {
            _storage = Atom(value: newValue, id: selfId)
        }
    }

    public init(_ value: T, actorID: ActorID, timestamp: TimeInterval? = nil) {
        selfId = actorID
        if let timestamp = timestamp {
            _storage = Atom(value: value, id: selfId, timestamp: timestamp)
        } else {
            _storage = Atom(value: value, id: selfId)
        }
    }
}

extension LWWRegister: Replicable {
    public func merged(with other: LWWRegister) -> LWWRegister {
        // ternary operator, since I can never entirely remember the sequence:
        // expression ? valueIfTrue : valueIfFalse
        _storage <= other._storage ? other : self
    }
}

extension LWWRegister: DeltaCRDT {
//    public typealias DeltaState = Self.Atom
//    public typealias Delta = Self.Atom
    public var state: Atom {
        _storage
    }

    public func delta(_: Atom?) -> [Atom] {
        [_storage]
    }

    public func mergeDelta(_ delta: [Atom]) -> Self {
        var newLWW = self
        if let lastDelta = delta.last {
            newLWW._storage = _storage <= lastDelta ? lastDelta : _storage
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

#if DEBUG
    extension LWWRegister: ApproxSizeable {
        public func sizeInBytes() -> Int {
            _storage.sizeInBytes() + MemoryLayout<ActorID>.size(ofValue: selfId)
        }
    }

    extension LWWRegister.Atom: ApproxSizeable {
        public func sizeInBytes() -> Int {
            clockId.sizeInBytes() + MemoryLayout<T>.size(ofValue: value)
        }
    }
#endif
