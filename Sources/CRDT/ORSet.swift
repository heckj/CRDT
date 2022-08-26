//
//  ORSet.swift
//

import Foundation

/// An Observed-Remove Set.
///
/// The `ORSet` can add and remove items from the set, compared to a ``GSet``, which can only add.
/// This is more powerful than the `GSet`, but has extra storage costs.
///
/// The implementation is based on "An Optimized Conflict-free Replicated Set" by
/// Annette Bieniusa, Marek Zawirski, Nuno Preguiça, Marc Shapiro, Carlos Baquero, Valter Balegas, and Sérgio Duarte (2012).
/// arXiv:[1210.3368](https://arxiv.org/abs/1210.3368)
public struct ORSet<ActorID: Hashable & Comparable & Sendable, T: Hashable & Sendable>: Sendable {
    internal struct Metadata: Sendable, CustomStringConvertible {
        var isDeleted: Bool
        var lamportTimestamp: LamportTimestamp<ActorID>
        var description: String {
            "[\(lamportTimestamp), deleted: \(isDeleted)]"
        }

        init(lamportTimestamp: LamportTimestamp<ActorID>) {
            isDeleted = false
            self.lamportTimestamp = lamportTimestamp
        }
    }

    internal var currentTimestamp: LamportTimestamp<ActorID>
    internal var metadataByValue: [T: Metadata]

    /// Creates a new grow-only set..
    /// - Parameters:
    ///   - actorID: The identity of the collaborator for this set.
    ///   - clock: An optional Lamport clock timestamp for this set.
    public init(actorId: ActorID, clock: UInt64 = 0) {
        metadataByValue = .init()
        currentTimestamp = .init(clock: clock, actorId: actorId)
    }

    /// Creates a new grow-only set..
    /// - Parameters:
    ///   - actorID: The identity of the collaborator for this set.
    ///   - clock: An optional Lamport clock timestamp for this set.
    ///   - elements: An list of elements to add to the set.
    public init(actorId: ActorID, clock: UInt64 = 0, _ elements: [T]) {
        self = .init(actorId: actorId, clock: clock)
        elements.forEach { self.insert($0) }
    }

    /// The set of values.
    public var values: Set<T> {
        let values = metadataByValue.filter { !$1.isDeleted }.map(\.key)
        return Set(values)
    }

    /// Returns a Boolean value that indicates whether the set contains the value you provide.
    /// - Parameter value: The value to compare.
    public func contains(_ value: T) -> Bool {
        !(metadataByValue[value]?.isDeleted ?? true)
    }

    /// The number of items in the set.
    public var count: Int {
        metadataByValue.filter { !$1.isDeleted }.count
    }

    /// Inserts a new value into the set.
    /// - Parameter value: The value to insert.
    /// - Returns: A Boolean value indicating whether the value inserted was new to the set.
    @discardableResult public mutating func insert(_ value: T) -> Bool {
        currentTimestamp.tick()

        let metadata = Metadata(lamportTimestamp: currentTimestamp)
        let isNewInsert: Bool

        if let oldMetadata = metadataByValue[value] {
            isNewInsert = oldMetadata.isDeleted
        } else {
            isNewInsert = true
        }
        metadataByValue[value] = metadata

        return isNewInsert
    }

    /// Removes a value from the set.
    /// - Parameter value: The value to remove.
    /// - Returns: The value removed from the set, or `nil` if the value didn't exist.
    @discardableResult public mutating func remove(_ value: T) -> T? {
        let returnValue: T?

        if let oldMetadata = metadataByValue[value], !oldMetadata.isDeleted {
            currentTimestamp.tick()
            var metadata = Metadata(lamportTimestamp: currentTimestamp)
            metadata.isDeleted = true
            metadataByValue[value] = metadata
            returnValue = value
        } else {
            returnValue = nil
        }

        return returnValue
    }
}

extension ORSet: Replicable {
    /// Returns a new counter by merging two set instances.
    ///
    /// When merging two previously unrelated CRDTs, if there are values in the delta that have metadata in conflict
    /// with the local instance, then the instance with the higher value for the Lamport timestamp as a whole will be chosen and used.
    /// This provides a deterministic output, but could be surprising.
    /// A set may have values that reflect being added or removed, depending on the underlying metadata.
    ///
    /// - Parameter other: The counter to merge.
    public func merged(with other: ORSet) -> ORSet {
        var copy = self
        copy.metadataByValue = other.metadataByValue.reduce(into: metadataByValue) { result, entry in
            let firstMetadata = result[entry.key]
            let secondMetadata = entry.value
            if let firstMetadata = firstMetadata {
                result[entry.key] = firstMetadata.lamportTimestamp > secondMetadata.lamportTimestamp ? firstMetadata : secondMetadata
            } else {
                result[entry.key] = secondMetadata
            }
        }
        copy.currentTimestamp = max(currentTimestamp, other.currentTimestamp)
        return copy
    }
}

extension ORSet: DeltaCRDT {
    // NOTE(heckj): IMPLEMENTATION DETAILS
    //  - You may note that this implementation is nearly identical to ORMap's conformance methods.
    //
    //     This is intentional!
    //
    // Let me explain: While it pains me a bit to replicate all this code, nearly identically, there
    // are some *very small* differences in the implementations due to the fact that the base type has
    // differently structured metadata. Since the additional of this metadata *also* effects the
    // generic type structure, I didn't see any easy way to pull out some of this code, and in the end
    // just decided to replicate the whole kit.
    //
    // That said, if you find and fix a bug in these protocol conformance methods, PLEASE double check
    // the peer implementation in `ORMap.swift` and fix any issues there as well.

    /// The minimal state for an ORSet to compute diffs for replication.
    public struct ORSetState {
        let maxClockValueByActor: [ActorID: UInt64]
    }

    /// The set of changes to bring another ORSet instance up to the same state.
    public struct ORSetDelta {
        let updates: [T: Metadata]
    }

    /// The current state of the ORSet.
    public var state: ORSetState {
        get async {
            // The composed, compressed state to compare consists of a list of all the collaborators (represented
            // by the actorId in the LamportTimestamps) with their highest value for clock.
            var maxClockValueByActor: [ActorID: UInt64]
            maxClockValueByActor = metadataByValue.reduce(into: [:]) { partialResult, valueMetaData in
                // Do the accumulated keys already reference an actorID from our CRDT?
                if partialResult.keys.contains(valueMetaData.value.lamportTimestamp.actorId) {
                    // Our local CRDT knows of this actorId, so only include the value if the
                    // Lamport clock of the local data element's timestamp is larger than the accumulated
                    // Lamport clock for the actorId.
                    if let latestKnownClock = partialResult[valueMetaData.value.lamportTimestamp.actorId],
                       latestKnownClock < valueMetaData.value.lamportTimestamp.clock
                    {
                        partialResult[valueMetaData.value.lamportTimestamp.actorId] = valueMetaData.value.lamportTimestamp.clock
                    }
                } else {
                    // The local CRDT doesn't know about this actorId, so add it to the outgoing state being
                    // accumulated into partialResult, including the current Lamport clock value as the current
                    // latest value. If there is more than one entry by this actorId, the if check above this
                    // updates the timestamp to any later values.
                    partialResult[valueMetaData.value.lamportTimestamp.actorId] = valueMetaData.value.lamportTimestamp.clock
                }
            }
            return ORSetState(maxClockValueByActor: maxClockValueByActor)
        }
    }

    /// Computes and returns a diff from the current state of the ORSet to be used to update another instance.
    ///
    /// If you don't provide a state from another ORSet instance, the returned delta represents the full state.
    ///
    /// - Parameter state: The optional state of the remote ORSet.
    /// - Returns: The changes to be merged into the ORSet instance that provided the state to converge its state with this instance.
    public func delta(_ otherInstanceState: ORSetState?) async -> ORSetDelta {
        // In the case of a null state being provided, the delta is all current values and their metadata:
        guard let maxClockValueByActor: [ActorID: UInt64] = otherInstanceState?.maxClockValueByActor else {
            return ORSetDelta(updates: metadataByValue)
        }
        // The state of a remote instance has been provided to us as a list of actorIds and max clock values.
        var statesToReplicate: [T: Metadata]

        // To determine the changes that need to be replicated to the instance that provided the state:
        // Iterate through the local collection:
        statesToReplicate = metadataByValue.reduce(into: [:]) { partialResult, keyMetaData in
            // - If there are actorIds in our CRDT that the incoming state doesn't list, include those values
            // in the delta. It means the remote CRDT hasn't seen the collaborator that the actorId represents.
            if !maxClockValueByActor.keys.contains(keyMetaData.value.lamportTimestamp.actorId) {
                partialResult[keyMetaData.key] = keyMetaData.value
            } else
            // - If any clock values are greater than the max clock for the actorIds they listed, provide them.
            if let maxClockForThisActor = maxClockValueByActor[keyMetaData.value.lamportTimestamp.actorId], keyMetaData.value.lamportTimestamp.clock > maxClockForThisActor {
                partialResult[keyMetaData.key] = keyMetaData.value
            }
        }
        return ORSetDelta(updates: statesToReplicate)
    }

    /// Returns a new instance of an ORSet with the delta you provide merged into the current ORSet.
    /// - Parameter delta: The incremental, partial state to merge.
    ///
    /// When merging two previously unrelated CRDTs, if there are values in the delta that have metadata in conflict
    /// with the local instance, then the instance with the higher value for the Lamport timestamp as a whole will be chosen and used.
    /// This provides a deterministic output, but could be surprising.
    /// A set may have values that reflect being added or removed, depending on the underlying metadata.
    ///
    /// This method will throw an exception in the scenario where two identical Lamport timestamps (same clock, same actorId)
    /// report conflicting metadata.
    public func mergeDelta(_ delta: ORSetDelta) async throws -> Self {
        var copy = self
        for (valueKey, metadata) in delta.updates {
            // Check to see if we already have this entry in our set...
            if let localMetadata = copy.metadataByValue[valueKey] {
                // The importing delta *includes* a value that we already have - which generally
                // should only happen when we merge two previously unsynchronized CRDTs.
                if metadata.lamportTimestamp > localMetadata.lamportTimestamp {
                    // The incoming delta includes a key we already have, but the Lamport timestamp clock value
                    // is newer than the version we're tracking, so we choose the metadata with a higher lamport
                    // timestamp.
                    copy.metadataByValue[valueKey] = metadata
                } else if metadata.lamportTimestamp == localMetadata.lamportTimestamp, metadata != localMetadata {
                    let msg = "The metadata for the set value of \(valueKey) has conflicting metadata. local: \(localMetadata), remote: \(metadata)."
                    throw CRDTMergeError.conflictingHistory(msg)
                }
            } else {
                // We don't have this entry, so we accept all the details from the diff and merge that into place
                // with its metadata.
                copy.metadataByValue[valueKey] = metadata
            }
            // If the remote values have a more recent clock value for this actor instance,
            // increment the clock to that higher value.
            if metadata.lamportTimestamp.actorId == copy.currentTimestamp.actorId, metadata.lamportTimestamp.clock > copy.currentTimestamp.clock {
                copy.currentTimestamp.clock = metadata.lamportTimestamp.clock
            }
        }
        return copy
    }
}

extension ORSet: Codable where T: Codable, ActorID: Codable {}
extension ORSet.Metadata: Codable where T: Codable, ActorID: Codable {}
extension ORSet.ORSetState: Codable where T: Codable, ActorID: Codable {}
extension ORSet.ORSetDelta: Codable where T: Codable, ActorID: Codable {}

extension ORSet: Equatable where T: Equatable {}
extension ORSet.Metadata: Equatable where T: Equatable {}
extension ORSet.ORSetState: Equatable where T: Equatable {}
extension ORSet.ORSetDelta: Equatable where T: Equatable {}

extension ORSet: Hashable where T: Hashable {}
extension ORSet.Metadata: Hashable where T: Hashable {}
extension ORSet.ORSetState: Hashable where T: Hashable {}
extension ORSet.ORSetDelta: Hashable where T: Hashable {}

#if DEBUG
    extension ORSet.Metadata: ApproxSizeable {
        public func sizeInBytes() -> Int {
            MemoryLayout<Bool>.size + lamportTimestamp.sizeInBytes()
        }
    }

    extension ORSet: ApproxSizeable {
        public func sizeInBytes() -> Int {
            let dictSize = metadataByValue.reduce(into: 0) { partialResult, meta in
                partialResult += MemoryLayout<T>.size(ofValue: meta.key)
                partialResult += meta.value.sizeInBytes()
            }
            return currentTimestamp.sizeInBytes() + dictSize
        }
    }

    extension ORSet.ORSetState: ApproxSizeable {
        public func sizeInBytes() -> Int {
            let dictSize = maxClockValueByActor.reduce(into: 0) { partialResult, meta in
                partialResult += MemoryLayout<ActorID>.size(ofValue: meta.key)
                partialResult += MemoryLayout<UInt64>.size
            }
            return dictSize
        }
    }

    extension ORSet.ORSetDelta: ApproxSizeable {
        public func sizeInBytes() -> Int {
            let dictSize = updates.reduce(into: 0) { partialResult, meta in
                partialResult += MemoryLayout<T>.size(ofValue: meta.key)
                partialResult += meta.value.sizeInBytes()
            }
            return dictSize
        }
    }
#endif
