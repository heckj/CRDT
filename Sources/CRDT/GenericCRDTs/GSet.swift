//
//  GSet.swift
//

/// A Grow-only Set.
///
/// The `GSet` implementation is based on the grow-only set  described in
/// [A comprehensive study of Convergent and Commutative Replicated Data Types](https://hal.inria.fr/inria-00555588/document)”
/// by Marc Shapiro, Nuno Preguiça, Carlos Baquero, and Marek Zawirski (2011).
public struct GSet<ActorID: Hashable & PartiallyOrderable, T: Hashable> {
    private var _storage: Set<T>
    var currentTimestamp: LamportTimestamp<ActorID>

    /// The set of values.
    public var values: Set<T> {
        _storage
    }

    /// The number of items in the set.
    public var count: Int {
        _storage.count
    }

    /// Inserts a new value into the set.
    /// - Parameter value: The value to insert.
    public mutating func insert(_ value: T) {
        _storage.insert(value)
        currentTimestamp.tick()
    }

    /// Returns a Boolean value that indicates whether the set contains the value you provide.
    /// - Parameter value: The value to compare.
    public func contains(_ value: T) -> Bool {
        _storage.contains(value)
    }

    /// Creates a new grow-only set..
    /// - Parameters:
    ///   - actorID: The identity of the collaborator for this set.
    ///   - clock: An optional Lamport clock timestamp for this set.
    public init(actorId: ActorID, clock: UInt64 = 0) {
        currentTimestamp = LamportTimestamp(clock: clock, actorId: actorId)
        _storage = Set<T>()
    }

    /// Creates a new grow-only set..
    /// - Parameters:
    ///   - actorID: The identity of the collaborator for this set.
    ///   - clock: An optional Lamport clock timestamp for this set.
    ///   - elements: An list of elements to add to the set.
    public init(actorId: ActorID, clock: UInt64 = 0, _ elements: [T]) {
        self = .init(actorId: actorId, clock: clock)
        elements.forEach { insert($0) }
    }
}

extension GSet: Replicable {
    /// Merges another set into the current instance.
    /// - Parameter other: The set to merge.
    public mutating func merging(with other: GSet<ActorID, T>) {
        _storage = _storage.union(other._storage)
        currentTimestamp.clock = max(currentTimestamp.clock, other.currentTimestamp.clock)
    }

    /// Returns a new counter by merging two counter instances.
    /// - Parameter other: The counter to merge.
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
    /// A struct that represents the state of the set.
    public struct GSetState {
        let values: Set<T>
    }

    /// A struct that represents the differences to be merged to replicate the set.
    public struct GSetDelta {
        let lamportClock: LamportTimestamp<ActorID>
        let values: Set<T>
    }

    /// The current state of the CRDT.
    public var state: GSetState {
        GSetState(values: _storage)
    }

    /// Computes and returns a diff from the current state of the counter to be used to update another instance.
    ///
    /// - Parameter state: The optional state of the remote CRDT.
    /// - Returns: The changes to be merged into the counter instance that provided the state to converge its state with this instance, or `nil` if no changes are needed.
    public func delta(_ state: GSetState?) -> GSetDelta? {
        guard let otherState = state else {
            return GSetDelta(lamportClock: currentTimestamp, values: _storage)
        }
        var diff = _storage
        for val in _storage.intersection(otherState.values) {
            diff.remove(val)
        }
        if !diff.isEmpty {
            return GSetDelta(lamportClock: currentTimestamp, values: diff)
        }
        return nil
    }

    /// Returns a new instance of an set with the delta you provide merged into the current set.
    /// - Parameter delta: The incremental, partial state to merge.
    public func mergeDelta(_ delta: GSetDelta) -> Self {
        var copy = self
        // Merging two grow-only sets is (conveniently) the union of the two sets
        copy._storage = values.union(delta.values)
        // The clock isn't used for ordering or merging, so updating it isn't strictly needed.
        let maxClock = max(currentTimestamp.clock, delta.lamportClock.clock)
        copy.currentTimestamp.clock = maxClock
        return copy
    }

    /// Merges the delta you provide from another set.
    /// - Parameter delta: The incremental, partial state to merge.
    public mutating func mergingDelta(_ delta: GSetDelta) {
        // Merging two grow-only sets is (conveniently) the union of the two sets
        _storage = values.union(delta.values)
        // The clock isn't used for ordering or merging, so updating it isn't strictly needed.
        currentTimestamp.clock = max(currentTimestamp.clock, delta.lamportClock.clock)
    }
}

extension GSet: Codable where T: Codable, ActorID: Codable {}
extension GSet.GSetState: Codable where T: Codable, ActorID: Codable {}
extension GSet.GSetDelta: Codable where T: Codable, ActorID: Codable {}

extension GSet: Sendable where T: Sendable, ActorID: Sendable {}
extension GSet.GSetState: Sendable where T: Sendable, ActorID: Sendable {}
extension GSet.GSetDelta: Sendable where T: Sendable, ActorID: Sendable {}

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
