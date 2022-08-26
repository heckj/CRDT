//
//  LWWRegister.swift
//
// Based on code written by Drew McCormack on 29/04/2020.
// Used under MIT License
// Source: https://github.com/appdecentral/replicatingtypes/blob/master/Sources/ReplicatingTypes/ReplicatingRegister.swift

import Foundation

/// A Last-Writer-Wins Register.
///
/// The `LWWRegister` implementation is based on an optimized CRDT register type as described in
/// [A comprehensive study of Convergent and Commutative Replicated Data Types](https://hal.inria.fr/inria-00555588/document)”
/// by Marc Shapiro, Nuno Preguiça, Carlos Baquero, and Marek Zawirski (2011).
public struct LWWRegister<ActorID: Hashable & Comparable, T> {
    /// A struct that represents the state of an LWWRegister
    public struct Atom {
        internal var value: T
        internal var clockId: WallclockTimestamp<ActorID>

        init(value: T, id: ActorID, timestamp: TimeInterval = Date().timeIntervalSinceReferenceDate) {
            self.value = value
            clockId = WallclockTimestamp(actorId: id, timestamp: timestamp)
        }

        // MARK: Conformance of LWWRegister.Atom to PartiallyOrderable

        /// Returns a Boolean value that indicates if the atom is less-than or equal to another atom.
        /// - Parameters:
        ///   - lhs: The first atom to compare.
        ///   - rhs: The second atom to compare.
        public static func <= (lhs: Self, rhs: Self) -> Bool {
            // functionally equivalent to say rhs instance is ordered after lhs instance
            // print("lhs \(lhs.timestamp), \(lhs.id) <=? rhs \(rhs.timestamp), \(rhs.id)")
            lhs.clockId <= rhs.clockId
        }
    }

    private var _storage: Atom
    internal let selfId: ActorID

    /// The value of the register.
    public var value: T {
        get {
            _storage.value
        }
        set {
            _storage = Atom(value: newValue, id: selfId)
        }
    }

    /// Creates a new last-write-wins register.
    /// - Parameters:
    ///   - value: The initial register value.
    ///   - actorID: The identity of the collaborator for this register..
    ///   - timestamp: An optional wall clock timestamp for this register.
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
    public mutating func merging(with other: LWWRegister<ActorID, T>) {
        if _storage <= other._storage {
            _storage = other._storage
        }
    }
    
    /// Returns a new counter by merging two counter instances.
    /// - Parameter other: The counter to merge.
    public func merged(with other: LWWRegister) -> LWWRegister {
        // ternary operator, since I can never entirely remember the sequence:
        // expression ? valueIfTrue : valueIfFalse
        _storage <= other._storage ? other : self
    }
}

extension LWWRegister: DeltaCRDT {
//    public typealias DeltaState = Self.Atom
//    public typealias Delta = Self.Atom

    /// The current state of the CRDT.
    public var state: Atom {
        get {
            _storage
        }
    }

    /// Computes and returns a diff from the current state of the counter to be used to update another instance.
    ///
    /// - Parameter state: The optional state of the remote CRDT.
    /// - Returns: The changes to be merged into the counter instance that provided the state to converge its state with this instance.
    public func delta(_: Atom?) -> Atom {
        _storage
    }

    /// Returns a new instance of a register with the delta you provide merged into the current register.
    /// - Parameter delta: The incremental, partial state to merge.
    public func mergeDelta(_ delta: Atom) -> Self {
        var newLWW = self
        newLWW._storage = _storage <= delta ? delta : _storage
        return newLWW
    }
    
    public mutating func mergingDelta(_ delta: Atom) throws {
        if _storage <= delta {
            _storage = delta
        }
    }
    
}

extension LWWRegister: Codable where T: Codable, ActorID: Codable {}
extension LWWRegister.Atom: Codable where T: Codable, ActorID: Codable {}

extension LWWRegister: Sendable where T: Sendable, ActorID: Sendable {}
extension LWWRegister.Atom: Sendable where T: Sendable, ActorID: Sendable {}

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
