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
public struct LWWRegister<ActorID: Hashable & PartiallyOrderable, T> {
    /// A struct that represents the state of an LWWRegister
    public struct Metadata {
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

    private var _storage: Metadata
    internal let selfId: ActorID

    /// The value of the register.
    public var value: T {
        get {
            _storage.value
        }
        set {
            _storage = Metadata(value: newValue, id: selfId)
        }
    }

    /// Creates a new last-write-wins register with the value you provide.
    /// - Parameters:
    ///   - value: The initial register value.
    ///   - actorID: The identity of the collaborator for this register..
    ///   - timestamp: An optional wall clock timestamp for this register.
    public init(_ value: T, actorID: ActorID, timestamp: TimeInterval? = nil) {
        selfId = actorID
        if let timestamp = timestamp {
            _storage = Metadata(value: value, id: selfId, timestamp: timestamp)
        } else {
            _storage = Metadata(value: value, id: selfId)
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

    public struct DeltaState {
        public let clockId: WallclockTimestamp<ActorID>
    }

    /// The current state of the CRDT.
    public var state: DeltaState {
        DeltaState(clockId: _storage.clockId)
    }

    /// Computes and returns a diff from the current state of the counter to be used to update another instance.
    ///
    /// - Parameter state: The optional state of the remote CRDT.
    /// - Returns: The changes to be merged into the counter instance that provided the state to converge its state with this instance, or `nil` if no changes are needed.
    public func delta(_ state: DeltaState?) -> Metadata? {
        guard let state = state else {
            return _storage
        }
        if state.clockId != _storage.clockId {
            return _storage
        }
        return nil
    }

    /// Returns a new instance of a register with the delta you provide merged into the current register.
    /// - Parameter delta: The incremental, partial state to merge.
    public func mergeDelta(_ delta: Metadata) -> Self {
        var newLWW = self
        newLWW._storage = _storage <= delta ? delta : _storage
        return newLWW
    }

    /// Merges another register into the current instance.
    /// - Parameter other: The regsister to merge.
    public mutating func mergingDelta(_ delta: Metadata) throws {
        if _storage <= delta {
            _storage = delta
        }
    }
}

extension LWWRegister: Codable where T: Codable, ActorID: Codable {}
extension LWWRegister.Metadata: Codable where T: Codable, ActorID: Codable {}
extension LWWRegister.DeltaState: Codable where ActorID: Codable {}

extension LWWRegister: Sendable where T: Sendable, ActorID: Sendable {}
extension LWWRegister.Metadata: Sendable where T: Sendable, ActorID: Sendable {}
extension LWWRegister.DeltaState: Sendable where ActorID: Sendable {}

extension LWWRegister: Equatable where T: Equatable {}
extension LWWRegister.Metadata: Equatable where T: Equatable {}
extension LWWRegister.DeltaState: Equatable where ActorID: Equatable {}

extension LWWRegister: Hashable where T: Hashable {}
extension LWWRegister.Metadata: Hashable where T: Hashable {}
extension LWWRegister.DeltaState: Hashable where ActorID: Hashable {}

#if DEBUG
    extension LWWRegister: ApproxSizeable {
        public func sizeInBytes() -> Int {
            _storage.sizeInBytes() + MemoryLayout<ActorID>.size(ofValue: selfId)
        }
    }

    extension LWWRegister.Metadata: ApproxSizeable {
        public func sizeInBytes() -> Int {
            clockId.sizeInBytes() + MemoryLayout<T>.size(ofValue: value)
        }
    }

    extension LWWRegister.DeltaState: ApproxSizeable {
        public func sizeInBytes() -> Int {
            clockId.sizeInBytes()
        }
    }
#endif
