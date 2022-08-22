//
//  GSet.swift
//  

import Foundation

/// Implements Grow-only Set
/// Based on GSet implementation as described in "Convergent and Commutative Replicated Data Types"
/// - SeeAlso: [A comprehensive study of Convergent and Commutative Replicated Data Types](https://hal.inria.fr/inria-00555588/document)” by Marc Shapiro, Nuno Preguiça, Carlos Baquero, and Marek Zawirski (2011).
public struct GSet<ActorID: Hashable & Comparable, T: Hashable> {

    private var _storage: Set<T>
    internal var currentTimestamp: LamportTimestamp<ActorID>

    public var values: Set<T> {
        get {
            _storage
        }
    }

    public var count: Int {
        get {
            _storage.count
        }
    }

    public mutating func insert(_ value: T) {
        self._storage.insert(value)
        self.currentTimestamp.tick()
    }
    
    public func contains(_ value: T) -> Bool {
        _storage.contains(value)
    }

    public init(actorId: ActorID, clock: UInt64 = 0) {
        self.currentTimestamp = LamportTimestamp(clock: clock, actorId: actorId)
        self._storage = Set<T>()
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
        copy._storage = _storage.union(other._storage)
        // The clock isn't used for ordering or merging, so updating it isn't strictly needed.
        copy.currentTimestamp.clock = max(currentTimestamp.clock, other.currentTimestamp.clock)
        return copy
    }
}

extension GSet: DeltaCRDT {
//    public typealias DeltaState = Self.Atom
//    public typealias Delta = Self.Atom
//    associatedtype DeltaState: PartiallyOrderable
//    associatedtype Delta: PartiallyOrderable, Identifiable

    public struct GSetState {
        let values: Set<T>
    }
    
    public struct GSetDelta: Identifiable, PartiallyOrderable {
        let lamportClock: LamportTimestamp<ActorID>
        let values: Set<T>

        public var id: String {
            lamportClock.id
        }

        public static func <= (lhs: GSet<ActorID, T>.GSetDelta, rhs: GSet<ActorID, T>.GSetDelta) -> Bool {
            lhs.lamportClock <= rhs.lamportClock
        }
    }
    // var state: DeltaState { get }
    public var state: GSetState {
        GSetState(values: _storage)
    }

    //func delta(_ state: DeltaState?) -> [Delta]
    public func delta(_ otherState: GSetState?) -> [GSetDelta] {
        if let otherState = otherState {
            var diff = _storage
            for val in _storage.intersection(otherState.values) {
                diff.remove(val)
            }
            return [GSetDelta(lamportClock: self.currentTimestamp, values: diff)]
        } else {
            return [GSetDelta(lamportClock: self.currentTimestamp, values: _storage)]
        }
    }

    //func mergeDelta(_ delta: [Delta]) -> Self
    public func mergeDelta(_ delta: [GSetDelta]) -> Self {
        var copy = self
        // Merging two grow-only sets is (conveniently) the union of the two sets
        let reducedSet = delta.reduce(into: Set<T>(self.values)) { partialResult, delta in
            partialResult = partialResult.union(delta.values)
        }
        copy._storage = reducedSet
        // The clock isn't used for ordering or merging, so updating it isn't strictly needed.
        let maxClock = delta.reduce(into: 0) { partialResult, delta in
            partialResult = max(partialResult, delta.lamportClock.clock)
        }
        copy.currentTimestamp.clock = maxClock
        return copy
    }
}

extension GSet: Codable where T: Codable, ActorID: Codable {}

extension GSet.GSetState: Codable where T: Codable, ActorID: Codable {}

extension GSet: Equatable where T: Equatable {}

extension GSet.GSetState: Equatable where T: Equatable {}

extension GSet: Hashable where T: Hashable {}

extension GSet.GSetState: Hashable where T: Hashable {}

#if DEBUG
    extension GSet: ApproxSizeable {
        public func sizeInBytes() -> Int {
            let setSize = _storage.capacity * MemoryLayout<T>.size
            return setSize + currentTimestamp.sizeInBytes()
        }
    }

    extension GSet.GSetState: ApproxSizeable {
        public func sizeInBytes() -> Int {
            (MemoryLayout<T>.size * values.capacity)
        }
    }

    extension GSet.GSetDelta: ApproxSizeable {
        public func sizeInBytes() -> Int {
            let setSize = values.reduce(into: 0) { partialResult, someTVal in
                partialResult += MemoryLayout<T>.size(ofValue: someTVal)
            }
            return setSize + lamportClock.sizeInBytes()
        }
    }

#endif
