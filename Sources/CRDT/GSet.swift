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
        _storage
    }

    public var count: Int {
        _storage.count
    }

    public mutating func insert(_ value: T) {
        _storage.insert(value)
        currentTimestamp.tick()
    }

    public func contains(_ value: T) -> Bool {
        _storage.contains(value)
    }

    public init(actorId: ActorID, clock: UInt64 = 0) {
        currentTimestamp = LamportTimestamp(clock: clock, actorId: actorId)
        _storage = Set<T>()
    }

    public init(actorId: ActorID, clock: UInt64 = 0, _ elements: [T]) {
        self = .init(actorId: actorId, clock: clock)
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
    public struct GSetState {
        let values: Set<T>
    }

    public struct GSetDelta {
        let lamportClock: LamportTimestamp<ActorID>
        let values: Set<T>
    }

    // var state: DeltaState { get }
    public var state: GSetState {
        get async {
            GSetState(values: _storage)
        }
    }

    // func delta(_ state: DeltaState?) -> [Delta]
    public func delta(_ otherState: GSetState?) async -> GSetDelta {
        if let otherState = otherState {
            var diff = _storage
            for val in _storage.intersection(otherState.values) {
                diff.remove(val)
            }
            return GSetDelta(lamportClock: currentTimestamp, values: diff)
        } else {
            return GSetDelta(lamportClock: currentTimestamp, values: _storage)
        }
    }

    // func mergeDelta(_ delta: [Delta]) -> Self
    public func mergeDelta(_ delta: GSetDelta) async -> Self {
        var copy = self
        // Merging two grow-only sets is (conveniently) the union of the two sets
        copy._storage = values.union(delta.values)
        // The clock isn't used for ordering or merging, so updating it isn't strictly needed.
        let maxClock = max(currentTimestamp.clock, delta.lamportClock.clock)
        copy.currentTimestamp.clock = maxClock
        return copy
    }
}

extension GSet: Codable where T: Codable, ActorID: Codable {}
extension GSet.GSetState: Codable where T: Codable, ActorID: Codable {}
extension GSet.GSetDelta: Codable where T: Codable, ActorID: Codable {}

extension GSet: Equatable where T: Equatable {}
extension GSet.GSetState: Equatable where T: Equatable {}
extension GSet.GSetDelta: Equatable where T: Equatable {}

extension GSet: Hashable where T: Hashable {}
extension GSet.GSetState: Hashable where T: Hashable {}
extension GSet.GSetDelta: Hashable where T: Hashable {}

#if DEBUG
    extension GSet: ApproxSizeable {
        public func sizeInBytes() -> Int {
            let setSize = _storage.capacity * MemoryLayout<T>.size
            return setSize + currentTimestamp.sizeInBytes()
        }
    }

    extension GSet.GSetState: ApproxSizeable {
        public func sizeInBytes() -> Int {
            MemoryLayout<T>.size * values.capacity
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
