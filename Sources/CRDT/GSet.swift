//
//  GSet.swift
//  

import Foundation

/// Implements Grow-only Set
/// Based on GSet implementation as described in "Convergent and Commutative Replicated Data Types"
/// - SeeAlso: [A comprehensive study of Convergent and Commutative Replicated Data Types](https://hal.inria.fr/inria-00555588/document)” by Marc Shapiro, Nuno Preguiça, Carlos Baquero, and Marek Zawirski (2011).
public struct GSet<ActorID: Hashable & Comparable, T: Hashable> {
    /// The replicated state structure for LWWRegister
    public struct Atom: Identifiable, PartiallyOrderable {
        internal var values: Set<T>
        internal var clockId: LamportTimestamp<ActorID>

        /// The identity of the counter metadata (atom) computed from the actor Id and a current timestamp.
        public var id: String {
            clockId.id
        }

        init(values: Set<T>, id: ActorID, clock: UInt64 = 0) {
            self.values = values
            clockId = LamportTimestamp(clock: clock, actorId: id)
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

    public var values: Set<T> {
        get {
            _storage.values
        }
    }

    public var count: Int {
        get {
            _storage.values.count
        }
    }

    public mutating func insert(_ value: T) {
        self._storage.values.insert(value)
        self._storage.clockId.tick()
    }
    
    public func contains(_ value: T) -> Bool {
        _storage.values.contains(value)
    }

    public init(actorId: ActorID, clock: UInt64 = 0) {
        self.selfId = actorId
        self._storage = Atom(values: Set<T>(), id: actorId, clock: clock)
    }
    
    public init(actorId: ActorID, _ elements: [T]) {
        self = .init(actorId: actorId)
        elements.forEach { self.insert($0) }
    }
}

extension GSet: Replicable {
    public func merged(with other: GSet) -> GSet {
        var copy = self
        // Merging two grow-only sets is (conveniently) the union of the two sets
        copy._storage.values = _storage.values.union(other._storage.values)
        // The clock isn't used for ordering or merging, so updating it isn't strictly needed.
        copy._storage.clockId.clock = max(_storage.clockId.clock, other._storage.clockId.clock)
        copy._storage.clockId.tick()
        return copy
    }
}

extension GSet: DeltaCRDT {
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
        // Merging two grow-only sets is (conveniently) the union of the two sets
        let reducedSet = delta.reduce(into: Set<T>(self._storage.values)) { partialResult, atom in
            partialResult = partialResult.union(atom.values)
        }
        copy._storage.values = reducedSet
        // The clock isn't used for ordering or merging, so updating it isn't strictly needed.
        let maxClock = delta.reduce(into: 0) { partialResult, atom in
            partialResult = max(partialResult, atom.clockId.clock)
        }
        copy._storage.clockId.clock = maxClock
        copy._storage.clockId.tick()
        return copy
    }
}

extension GSet: Codable where T: Codable, ActorID: Codable {}

extension GSet.Atom: Codable where T: Codable, ActorID: Codable {}

extension GSet: Equatable where T: Equatable {}

extension GSet.Atom: Equatable where T: Equatable {}

extension GSet: Hashable where T: Hashable {}

extension GSet.Atom: Hashable where T: Hashable {}

#if DEBUG
    extension GSet: ApproxSizeable {
        public func sizeInBytes() -> Int {
            _storage.sizeInBytes() + MemoryLayout<ActorID>.size(ofValue: selfId)
        }
    }

    extension GSet.Atom: ApproxSizeable {
        public func sizeInBytes() -> Int {
            clockId.sizeInBytes() + (MemoryLayout<T>.size * values.capacity)
        }
    }
#endif
