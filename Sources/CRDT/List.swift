//
//  List.swift
//

// This is a modified form of the source, used under MIT license.
// Copyright (c) 2020 appdecentral
// Sourced from
// https://github.com/appdecentral/replicatingtypes/blob/master/Sources/ReplicatingTypes/ReplicatingArray.swift

/// A causal-tree List.
///
/// The `List` implementation is based a causal tree implementation, stored within array structures,
/// as described in [A comprehensive study of Convergent and Commutative Replicated Data Types](https://hal.inria.fr/inria-00555588/document)”
/// by Marc Shapiro, Nuno Preguiça, Carlos Baquero, and Marek Zawirski (2011).
public struct List<ActorID: Hashable & Comparable, T: Hashable & Comparable & Equatable> {
    /// Causal Tree Metadata
    public struct Metadata: CustomStringConvertible, Identifiable {
        /// A unique identifier, made up of a Lamport timestamp and the collaboration instance Id.
        public var id: LamportTimestamp<ActorID>
        /// The metadata instance that this instance logically follows.
        ///
        /// If `nil`, the metadata instance references the start of the causal tree.
        public var anchor: LamportTimestamp<ActorID>?
        /// A Boolean value that indicates whether this list element is deleted.
        public var isDeleted: Bool = false
        /// The value of the associated list element.
        public var value: T

        /// The description of the metadata.
        public var description: String {
            if let anchor = anchor {
                return "[\(anchor)<-\(id), deleted: \(isDeleted), value: \(value)]"
            } else {
                return "[nil<-\(id), deleted: \(isDeleted), value: \(value)]"
            }
        }

        /// Creates a new instance of metadata with the ID, value, and optional anchor that you provide.
        /// - Parameters:
        ///   - id: The identifier for the metadata
        ///   - anchor: The metadata instance that this references.
        ///   - value: The value that the metadata tracks.
        public init(id: LamportTimestamp<ActorID>, anchor: LamportTimestamp<ActorID>?, value: T) {
            self.id = id
            self.anchor = anchor
            self.value = value
        }

        /// Returns a Boolean value that indicates if this instance should be ordered before another instance.
        /// - Parameter other: The other metadata to compare.
        func ordered(beforeSibling other: Metadata) -> Bool {
            // A tuple sort orders by the first tuple, then the second tuple
            // IFF the first tuples are equivalent.
            (id.clock, id.actorId) > (other.id.clock, other.id.actorId)
        }

        /// Returns a list of metadata ordered according to a preorder traversal of a causal tree.
        ///
        /// For each element, we insert the element itself first, then the child (anchored) subtrees from left to right.
        /// - Parameter unordered: The metadata list to sort.
        public static func ordered(fromUnordered unordered: [Metadata]) -> [Metadata] {
            let sorted = unordered.sorted { $0.ordered(beforeSibling: $1) }
            let anchoredByAnchorId: [Metadata.ID?: [Metadata]] = .init(grouping: sorted) { $0.anchor }
            var result: [Metadata] = []

            func addDecendants(of containers: [Metadata]) {
                for container in containers {
                    result.append(container)
                    guard let anchoredToValueContainer = anchoredByAnchorId[container.id] else { continue }
                    addDecendants(of: anchoredToValueContainer)
                }
            }

            let roots = anchoredByAnchorId[nil] ?? []
            addDecendants(of: roots)
            return result
        }
        
        /// Verifies that a set of metadata can be ordered and configured in a complete and consistent causal tree.
        /// - Parameter meta: The list of metadata to evaluate.
        /// - Returns: Returns `nil` if the metadata makes a consistent tree or a string indicating the reason otherwise.
        public static func verifyCausalTreeConsistency(_ meta: [Metadata]) -> String? {
            let idsFromMetadata = meta.map { $0.id }
            let availableIds = Set<LamportTimestamp<ActorID>>(idsFromMetadata)
            if availableIds.count != idsFromMetadata.count {
                // There was a duplicate ID somewhere in that list...
                return "Two different metadata instances have identical Ids"
            }
            for m in meta {
                if let anchorId = m.anchor, !availableIds.contains(anchorId) {
                    // The anchor Id existed, but isn't in the list of available Ids
                    return "Metadata id \(m.id) references anchor \(anchorId) which is not in the list of available metadata."
                }
            }
            return nil
        }
    }

    // A combination of Lamport timestamp & actor ID
    internal var currentTimestamp: LamportTimestamp<ActorID>
    internal var activeValues: [Metadata] = []
    internal var tombstones: [Metadata] = []

    /// The values of the list.
    public var values: [T] { activeValues.map(\.value) }

    /// The number of non-deleted values in the list.
    public var count: UInt64 { UInt64(activeValues.count) }

    // MARK: Init

    /// Creates a new, empty list.
    /// - Parameter actorId: The collaboration instance identity.
    public init(actorId: ActorID, clock: UInt64 = 0) {
        currentTimestamp = LamportTimestamp(clock: clock, actorId: actorId)
    }

    /// Creates a new list with the values you provide.
    /// - Parameters:
    ///   - actorId: The collaboration instance identity.
    ///   - values: The values to insert into the list.
    public init(actorId: ActorID, clock: UInt64 = 0, _ values: [T]) {
        currentTimestamp = LamportTimestamp(clock: clock, actorId: actorId)
        values.forEach { self.append($0) }
    }
}

// MARK: Adding and Updating List Elements

public extension List {
    /// Inserts a value into the list at the position you specify.
    /// - Parameters:
    ///   - newValue: The value to add.
    ///   - index: The position to add the value.
    mutating func insert(_ newValue: T, at index: Int) {
        currentTimestamp.tick()
        let new = makeMetadata(withValue: newValue, forInsertingAtIndex: index)
        activeValues.insert(new, at: index)
    }

    /// Appends a value onto the end of the list.
    /// - Parameter newValue: The value to add.
    mutating func append(_ newValue: T) {
        insert(newValue, at: activeValues.count)
    }

    private func makeMetadata(withValue value: T, forInsertingAtIndex index: Int) -> Metadata {
        let anchor = index > 0 ? activeValues[index - 1].id : nil
        let new = Metadata(id: currentTimestamp, anchor: anchor, value: value)
        return new
    }
}

// MARK: Removing List Elements

public extension List {
    /// Removes a value at the position you specify
    /// - Parameter index: The position to remove the value.
    /// - Returns: The value that was removed.
    @discardableResult mutating func remove(at index: Int) -> T {
        var tombstone = activeValues[index]
        tombstone.isDeleted = true
        tombstones.append(tombstone)
        activeValues.remove(at: index)
        return tombstone.value
    }
}

// MARK: Merging Lists

extension List: Replicable {
    /// Merges another list into the current instance.
    /// - Parameter other: The list to merge.
    public mutating func merging(with other: Self) {
        let combinedUniqueTombstones = (tombstones + other.tombstones).filterDuplicates { $0.id }
        let tombstoneIds = combinedUniqueTombstones.map(\.id)

        var encounteredIds: Set<Metadata.ID> = []
        let unorderedContainers = (activeValues + other.activeValues).filter {
            !tombstoneIds.contains($0.id) && encounteredIds.insert($0.id).inserted
        }

        let resultMetadataWithTombstones = Metadata.ordered(fromUnordered: unorderedContainers + combinedUniqueTombstones)
        let resultMetadata = resultMetadataWithTombstones.filter { !$0.isDeleted }
        activeValues = resultMetadata
        tombstones = combinedUniqueTombstones
        currentTimestamp.clock = Swift.max(currentTimestamp.clock, other.currentTimestamp.clock)
    }

    /// Returns a new list created by merging another list.
    /// - Parameter other: The list to merge.
    public func merged(with other: Self) -> Self {
        let combinedUniqueTombstones = (tombstones + other.tombstones).filterDuplicates { $0.id }
        let tombstoneIds = combinedUniqueTombstones.map(\.id)

        var encounteredIds: Set<Metadata.ID> = []
        let unorderedContainers = (activeValues + other.activeValues).filter {
            !tombstoneIds.contains($0.id) && encounteredIds.insert($0.id).inserted
        }

        let resultMetadataWithTombstones = Metadata.ordered(fromUnordered: unorderedContainers + combinedUniqueTombstones)
        let resultMetadata = resultMetadataWithTombstones.filter { !$0.isDeleted }

        var copy = self
        copy.activeValues = resultMetadata
        copy.tombstones = combinedUniqueTombstones
        copy.currentTimestamp.clock = Swift.max(currentTimestamp.clock, other.currentTimestamp.clock)
        return copy
    }
}

extension List: DeltaCRDT {
    /// The current essential state information from a list's causal tree.
    public struct CausalTreeState {
        /// A dictionary of the maximum clock values for each collaboration instance identifier for active values.
        let maxActiveClockValueByActor: [ActorID: UInt64]
        /// A dictionary of the maximum clock values for each collaboration instance identifier for tombstone values.
        let maxTombstoneClockValueByActor: [ActorID: UInt64]
    }

    /// The updates needed to replicate the list.
    public struct CausalTreeDelta {
        let values: [Metadata]
        var maxClockValue: UInt64 {
            values.reduce(into: 0) { partialResult, metadata in
                partialResult = Swift.max(partialResult, metadata.id.clock)
            }
        }
    }

    /// The current state of the map.
    public var state: CausalTreeState {
        // We represent the state by the combined sets of the maximum values for the clocks for each actor that
        // we know about. We can't "just combine" the tombstones and active values and pick a total max clock
        // because the delete actions (those which result in tombstones) don't change the clock. Doing so would
        // invalidate the causal tree parent structure ordering, so we need to track those separately.
        let maxActiveClocks: [ActorID: UInt64] = activeValues
            .reduce(into: [:]) { partialResult, valueMetaData in
                // Do the accumulated keys already reference an actorID from our CRDT?
                if partialResult.keys.contains(valueMetaData.id.actorId) {
                    // Our local CRDT knows of this actorId, so only include the value if the
                    // Lamport clock of the local data element's timestamp is larger than the accumulated
                    // Lamport clock for the actorId.
                    if let latestKnownClock = partialResult[valueMetaData.id.actorId],
                       latestKnownClock < valueMetaData.id.clock
                    {
                        partialResult[valueMetaData.id.actorId] = valueMetaData.id.clock
                    }
                } else {
                    // The local CRDT doesn't know about this actorId, so add it to the outgoing state being
                    // accumulated into partialResult, including the current Lamport clock value as the current
                    // latest value. If there is more than one entry by this actorId, the if check above this
                    // updates the timestamp to any later values.
                    partialResult[valueMetaData.id.actorId] = valueMetaData.id.clock
                }
            }
        // same algorithm, applied for the recorded tombstones
        let maxTombstoneClocks: [ActorID: UInt64] = tombstones
            .reduce(into: [:]) { partialResult, valueMetaData in
                if partialResult.keys.contains(valueMetaData.id.actorId) {
                    if let latestKnownClock = partialResult[valueMetaData.id.actorId],
                       latestKnownClock < valueMetaData.id.clock
                    {
                        partialResult[valueMetaData.id.actorId] = valueMetaData.id.clock
                    }
                } else {
                    partialResult[valueMetaData.id.actorId] = valueMetaData.id.clock
                }
            }
        return CausalTreeState(maxActiveClockValueByActor: maxActiveClocks, maxTombstoneClockValueByActor: maxTombstoneClocks)
    }

    /// Computes and returns a diff from the current state of the list to be used to update another instance.
    ///
    /// If you don't provide a state from another list instance, the returned delta represents the full state.
    ///
    /// - Parameter state: The optional state of the remote list.
    /// - Returns: The changes to be merged into the list to converge it with this instance.
    public func delta(_ otherInstanceState: CausalTreeState?) -> CausalTreeDelta {
        // In the case of a null state being provided, the delta is all current values and their metadata:
        guard let maxActiveClocks: [ActorID: UInt64] = otherInstanceState?.maxActiveClockValueByActor,
              let maxTombstoneClocks: [ActorID: UInt64] = otherInstanceState?.maxTombstoneClockValueByActor
        else {
            return CausalTreeDelta(values: activeValues + tombstones)
        }
        // To determine the changes that need to be replicated to the instance that provided the state:
        // Iterate through the combined collection of active values and then tombstones:
        let activeStatesToReplicate: [Metadata] = activeValues
            .reduce(into: []) { partialResult, metadata in
                // - If there are actorIds in our CRDT that the incoming state doesn't list, include those values
                // in the delta. It means the remote CRDT hasn't seen the collaborator that the actorId represents.
                if !maxActiveClocks.keys.contains(metadata.id.actorId) {
                    partialResult.append(metadata)
                } else
                // - If any clock values are greater than the max clock for the actorIds they listed, provide them.
                if let maxClockForThisActor = maxActiveClocks[metadata.id.actorId],
                   metadata.id.clock > maxClockForThisActor
                {
                    partialResult.append(metadata)
                }
            }
        let tombStonesToReplicate: [Metadata] = tombstones
            .reduce(into: []) { partialResult, metadata in
                // - If there are actorIds in our CRDT that the incoming state doesn't list, include those values
                // in the delta. It means the remote CRDT hasn't seen the collaborator that the actorId represents.
                if !maxTombstoneClocks.keys.contains(metadata.id.actorId) {
                    partialResult.append(metadata)
                } else
                // - If any clock values are greater than the max clock for the actorIds they listed, provide them.
                if let maxClockForThisActor = maxTombstoneClocks[metadata.id.actorId],
                   metadata.id.clock > maxClockForThisActor
                {
                    partialResult.append(metadata)
                }
            }
        return CausalTreeDelta(values: activeStatesToReplicate + tombStonesToReplicate)
    }

    /// Returns a new instance of a map with the delta you provide merged into the current map.
    /// - Parameter delta: The incremental, partial state to merge.
    ///
    /// When merging two previously unrelated CRDTs, if there are values in the delta that have metadata in conflict
    /// with the local instance, then the instance with the higher value for the Lamport timestamp as a whole will be chosen and used.
    /// This provides a deterministic output, but could be surprising. Values for keys may exhibit unexpected values from the choice, or
    /// reflect being removed, depending on the underlying metadata.
    ///
    /// This method will throw an exception in the scenario where two identical Lamport timestamps (same clock, same actorId)
    /// report conflicting metadata.
    public func mergeDelta(_ delta: CausalTreeDelta) throws -> Self {
        let deltaTombstones = delta.values.filter(\.isDeleted)
        let deltaActiveValues = delta.values.filter { !$0.isDeleted }

        // Create a deduplicated list of all the tombstone entries
        let combinedUniqueTombstones = (tombstones + deltaTombstones).filterDuplicates { $0.id }
        // Use that to get a list of all the tombstone IDs
        let tombstoneIds = combinedUniqueTombstones.map(\.id)
        var encounteredIds: Set<Metadata.ID> = []

        // Build an updated list of active values from the combination of the current active
        // values, ones from the delta, and any current values that aren't in the combined
        // tombstone list.
        let unorderedContainers = (activeValues + deltaActiveValues).filter {
            // include any active metadata that isn't in the new combined list of tombstone Ids
            // We use and the verified insertion into a set to de-duplicate any active Ids
            !tombstoneIds.contains($0.id) && encounteredIds.insert($0.id).inserted
        }

        if let errorString = Metadata.verifyCausalTreeConsistency(unorderedContainers + combinedUniqueTombstones) {
            throw CRDTMergeError.inconsistentCausalTree(errorString)
        }
        
        let resultMetadataWithTombstones = Metadata.ordered(fromUnordered: unorderedContainers + combinedUniqueTombstones)
        let resultMetadata = resultMetadataWithTombstones.filter { !$0.isDeleted }

        var copy = self
        copy.activeValues = resultMetadata
        copy.tombstones = combinedUniqueTombstones
        copy.currentTimestamp.clock = Swift.max(currentTimestamp.clock, delta.maxClockValue)
        return copy
    }

    /// Merges the delta you provide from another set.
    /// - Parameter delta: The incremental, partial state to merge.
    ///
    /// When merging two previously unrelated CRDTs, if there are values in the delta that have metadata in conflict
    /// with the local instance, then the instance with the higher value for the Lamport timestamp as a whole will be chosen and used.
    /// This provides a deterministic output, but could be surprising. Values for keys may exhibit unexpected values from the choice, or
    /// reflect being removed, depending on the underlying metadata.
    ///
    /// This method will throw an exception in the scenario where two identical Lamport timestamps (same clock, same actorId)
    /// report conflicting metadata.
    public mutating func mergingDelta(_ delta: CausalTreeDelta) throws {
        let deltaTombstones = delta.values.filter(\.isDeleted)
        let deltaActiveValues = delta.values.filter { !$0.isDeleted }

        let combinedUniqueTombstones = (tombstones + deltaTombstones).filterDuplicates { $0.id }
        let tombstoneIds = combinedUniqueTombstones.map(\.id)

        var encounteredIds: Set<Metadata.ID> = []
        let unorderedContainers = (activeValues + deltaActiveValues).filter {
            // include values that aren't in the list of tombstone Ids and
            // (side effect) have been inserted into our 'encounteredIds' set.
            !tombstoneIds.contains($0.id) && encounteredIds.insert($0.id).inserted
        }

        // Order the combined sets together into a single, pre-order causal tree ordering.
        let orderedAndCombinedMetadata = Metadata.ordered(fromUnordered: unorderedContainers + combinedUniqueTombstones)
        // Then pull out the active values from that pre-ordered list.
        let resultMetadata = orderedAndCombinedMetadata.filter { !$0.isDeleted }

        activeValues = resultMetadata
        tombstones = combinedUniqueTombstones
        currentTimestamp.clock = Swift.max(currentTimestamp.clock, delta.maxClockValue)
    }
}

// MARK: Codable

extension List: Codable where T: Codable, ActorID: Codable {}
extension List.Metadata: Codable where T: Codable, ActorID: Codable {}
extension List.CausalTreeDelta: Codable where T: Codable, ActorID: Codable {}
extension List.CausalTreeState: Codable where T: Codable, ActorID: Codable {}

extension List: Equatable where T: Equatable {}
extension List.Metadata: Equatable where T: Equatable {}
extension List.CausalTreeState: Equatable where T: Equatable, ActorID: Equatable {}
extension List.CausalTreeDelta: Equatable where T: Equatable, ActorID: Equatable {}

extension List: Hashable where T: Hashable {}
extension List.Metadata: Hashable where T: Hashable {}
extension List.CausalTreeState: Hashable where T: Hashable, ActorID: Hashable {}
extension List.CausalTreeDelta: Hashable where T: Hashable, ActorID: Hashable {}

// MARK: Collection and RandomAccessCollection

extension List: Collection, RandomAccessCollection {
    public var startIndex: Int { activeValues.startIndex }
    public var endIndex: Int { activeValues.endIndex }
    public func index(after i: Int) -> Int { activeValues.index(after: i) }

    public subscript(_ i: Int) -> T {
        get {
            activeValues[i].value
        }
        set {
            remove(at: i)
            currentTimestamp.tick()
            let newMetadata = makeMetadata(withValue: newValue, forInsertingAtIndex: i)
            activeValues.insert(newMetadata, at: i)
        }
    }
}

// MARK: Other

private extension Array {
    func filterDuplicates(identifyingWith block: (Element) -> AnyHashable) -> Self {
        var encountered: Set<AnyHashable> = []
        return filter { encountered.insert(block($0)).inserted }
    }
}

#if DEBUG
    extension List.Metadata: ApproxSizeable {
        public func sizeInBytes() -> Int {
            MemoryLayout<Bool>.size + id.sizeInBytes() + (anchor?.sizeInBytes() ?? 1) + MemoryLayout<T>.size(ofValue: value)
        }
    }

    extension List: ApproxSizeable {
        public func sizeInBytes() -> Int {
            let tombstones = tombstones.reduce(into: 0) { partialResult, meta in
                partialResult += meta.sizeInBytes()
            }
            let actives = activeValues.reduce(into: 0) { partialResult, meta in
                partialResult += meta.sizeInBytes()
            }
            return currentTimestamp.sizeInBytes() + tombstones + actives
        }
    }
#endif
