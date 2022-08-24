//
//  ORMap.swift
//

import Foundation

/// An Observed-Remove Map.
///
/// The `ORMap` adds,  removes, and updates items from a dictionary-like structure.
///
/// The implementation is based on "An Optimized Conflict-free Replicated Set" by
/// Annette Bieniusa, Marek Zawirski, Nuno Preguiça, Marc Shapiro, Carlos Baquero, Valter Balegas, and Sérgio Duarte (2012).
/// arXiv:[1210.3368](https://arxiv.org/abs/1210.3368).
public struct ORMap<ActorID: Hashable & Comparable, KEY: Hashable, VALUE> {
    internal struct Metadata: CustomStringConvertible {
        var isDeleted: Bool
        var lamportTimestamp: LamportTimestamp<ActorID>
        var value: VALUE
        var description: String {
            "[\(lamportTimestamp), deleted: \(isDeleted)]"
        }
        
        init(lamportTimestamp: LamportTimestamp<ActorID>, _ val: VALUE) {
            isDeleted = false
            self.lamportTimestamp = lamportTimestamp
            value = val
        }
    }
    
    internal var currentTimestamp: LamportTimestamp<ActorID>
    internal var metadataByValue: [KEY: Metadata]
    
    /// Creates a new grow-only set..
    /// - Parameters:
    ///   - actorID: The identity of the collaborator for this set.
    ///   - clock: An optional lamport clock timestamp for this set.
    public init(actorId: ActorID, clock: UInt64 = 0) {
        metadataByValue = .init()
        currentTimestamp = .init(clock: clock, actorId: actorId)
    }
    
    /// Creates a new grow-only set..
    /// - Parameters:
    ///   - actorID: The identity of the collaborator for this set.
    ///   - clock: An optional lamport clock timestamp for this set.
    ///   - elements: An list of elements to add to the set.
    public init(actorId: ActorID, clock: UInt64 = 0, _ kvPairs: [KEY:VALUE]) {
        self = .init(actorId: actorId, clock: clock)
        for x in kvPairs {
            self[x.key] = x.value
        }
    }
    
    /// The set of keys.
    public var keys: [KEY] {
        metadataByValue.filter { !$1.isDeleted }.map(\.key)
    }

    /// The set of values.
    public var values: [VALUE] {
        metadataByValue.filter { !$1.isDeleted }.map(\.value.value)
    }

    /// The number of items in the set.
    public var count: Int {
        metadataByValue.filter { !$1.isDeleted }.count
    }
    
    public subscript(key: KEY) -> VALUE? {
        get {
            guard let container = metadataByValue[key], !container.isDeleted else { return nil }
            return container.value
        }
        
        set(newValue) {
            if let newValue = newValue {
                currentTimestamp.tick()
                let metadata = Metadata(lamportTimestamp: currentTimestamp, newValue)
                metadataByValue[key] = metadata
            } else if let oldMetadata = metadataByValue[key] {
                currentTimestamp.tick()
                var updatedMetaData = Metadata(lamportTimestamp: currentTimestamp, oldMetadata.value)
                updatedMetaData.isDeleted = true
                metadataByValue[key] = updatedMetaData
            }
        }
    }
}

extension ORMap: Replicable {
    /// Returns a new counter by merging two counter instances.
    /// - Parameter other: The counter to merge.
    public func merged(with other: ORMap) -> ORMap {
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

extension ORMap: DeltaCRDT {
    /// The minimal state for an ORSet to compute diffs for replication.
    public struct ORMapState {
        let maxClockValueByActor: [ActorID: UInt64]
    }

    /// The set of changes to bring another ORSet instance up to the same state.
    public struct ORMapDelta {
        let updates: [KEY: Metadata]
    }

    /// The current state of the ORSet.
    public var state: ORMapState {
        get async {
            // The composed, compressed state to compare consists of a list of all the collaborators (represented
            // by the actorId in the LamportTimestamps) with their highest value for clock.
            var maxClockValueByActor: [ActorID: UInt64]
            maxClockValueByActor = metadataByValue.reduce(into: [:]) { partialResult, valueMetaData in
                // Do the accumulated keys already reference an actorID from our CRDT?
                if partialResult.keys.contains(valueMetaData.value.lamportTimestamp.actorId) {
                    // Our local CRDT knows of this actorId, so only include the value if the
                    // lamport clock of the local data element's timestamp is larger than the accumulated
                    // lamport clock for the actorId.
                    if let latestKnownClock = partialResult[valueMetaData.value.lamportTimestamp.actorId],
                       latestKnownClock < valueMetaData.value.lamportTimestamp.clock
                    {
                        partialResult[valueMetaData.value.lamportTimestamp.actorId] = valueMetaData.value.lamportTimestamp.clock
                    }
                } else {
                    // The local CRDT doesn't know about this actorId, so add it to the outgoing state being
                    // accumulated into partialResult, including the current lamport clock value as the current
                    // latest value. If there is more than one entry by this actorId, the if check above this
                    // updates the timestamp to any later values.
                    partialResult[valueMetaData.value.lamportTimestamp.actorId] = valueMetaData.value.lamportTimestamp.clock
                }
            }
            return ORMapState(maxClockValueByActor: maxClockValueByActor)
        }
    }

    /// Computes and returns a diff from the current state of the ORSet to be used to update another instance.
    ///
    /// If you don't provide a state from another ORSet instance, the returned delta represents the full state.
    ///
    /// - Parameter state: The optional state of the remote ORSet.
    /// - Returns: The changes to be merged into the ORSet instance that provided the state to converge its state with this instance.
    public func delta(_ otherInstanceState: ORMapState?) async -> ORMapDelta {
        // In the case of a null state being provided, the delta is all current values and their metadata:
        guard let maxClockValueByActor: [ActorID: UInt64] = otherInstanceState?.maxClockValueByActor else {
            return ORMapDelta(updates: metadataByValue)
        }
        // The state of a remote instance has been provided to us as a list of actorIds and max clock values.
        var statesToReplicate: [KEY: Metadata]

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
        return ORMapDelta(updates: statesToReplicate)
    }

    /// Returns a new instance of an ORSet with the delta you provide merged into the current ORSet.
    /// - Parameter delta: The incremental, partial state to merge.
    ///
    /// When merging two previously unrelated CRDTs, if there are values in the delta that have metadata in conflict
    /// with our local metadata, this method will throw the error: ``CRDTMergeError/conflictingHistory(_:)``.
    public func mergeDelta(_ delta: ORMapDelta) async throws -> Self {
        var copy = self
        for (valueKey, metadata) in delta.updates {
            // Check to see if we already have this entry in our set...
            if let localMetadata = copy.metadataByValue[valueKey] {
                if metadata.lamportTimestamp <= localMetadata.lamportTimestamp {
                    // The remote delta is providing a timestamp equal to, or earlier than, our own.
                    // Check to see if the metadata matches, and if so. If it does, then ignore this value and
                    // leave things alone, as it could be identical causal updates, which shouldn't fail to merge.
                    // If the metadata is in conflict, then throw an error since the history for this value conflicts.
                    if !metadata.isDeleted == localMetadata.isDeleted {
                        let msg = "The metadata for the set value \(valueKey) has conflicting timestamps. local: \(localMetadata), remote: \(metadata)."
                        throw CRDTMergeError.conflictingHistory(msg)
                    }
                    // The metadata is identical for the value, only the lamport timestamp is in conflict.
                    // If the timestamp from the incoming value being merged is more recent, then we should
                    // overwrite our timestamp value. Not doing "so should be safe", but could mean extra "diff"
                    // values being propogated over consecutive merges.
                    if metadata.lamportTimestamp > localMetadata.lamportTimestamp {
                        copy.metadataByValue[valueKey] = metadata
                    }
                } else {
                    // The incoming delta includes a key we already have, but the lamport timestamp is newer
                    // than the version we're tracking, so update the metadata with the remote's timestamp.
                    // This can happen when the metadata is updated, for example when a value is marked as
                    // deleted, by a remote CRDT.
                    copy.metadataByValue[valueKey] = metadata
                }
            } else {
                // We don't have this entry, so copy it into place with the metadata from the delta.
                copy.metadataByValue[valueKey] = metadata
            }
            // If the remote values have a more recent clock value for this actor instance,
            // increment the clock.
            if metadata.lamportTimestamp.actorId == copy.currentTimestamp.actorId, metadata.lamportTimestamp.clock > copy.currentTimestamp.clock {
                copy.currentTimestamp.clock = metadata.lamportTimestamp.clock
            }
        }
        return copy
    }
}

extension ORMap: Codable where KEY: Codable, VALUE: Codable, ActorID: Codable {}
extension ORMap.Metadata: Codable where KEY: Codable, VALUE: Codable, ActorID: Codable {}
extension ORMap.ORMapState: Codable where KEY: Codable, ActorID: Codable {}
extension ORMap.ORMapDelta: Codable where KEY: Codable, VALUE: Codable, ActorID: Codable {}

extension ORMap: Equatable where KEY: Equatable, VALUE: Equatable {}
extension ORMap.Metadata: Equatable where KEY: Equatable, VALUE: Equatable {}
extension ORMap.ORMapState: Equatable where KEY: Equatable {}
extension ORMap.ORMapDelta: Equatable where KEY: Equatable, VALUE: Equatable {}

extension ORMap: Hashable where KEY: Hashable, VALUE: Hashable {}
extension ORMap.Metadata: Hashable where KEY: Hashable, VALUE: Hashable {}
extension ORMap.ORMapState: Hashable where KEY: Hashable {}
extension ORMap.ORMapDelta: Hashable where KEY: Hashable, VALUE: Hashable {}

#if DEBUG
    extension ORMap.Metadata: ApproxSizeable {
        public func sizeInBytes() -> Int {
            MemoryLayout<Bool>.size + lamportTimestamp.sizeInBytes()
        }
    }

    extension ORMap: ApproxSizeable {
        public func sizeInBytes() -> Int {
            let dictSize = metadataByValue.reduce(into: 0) { partialResult, meta in
                partialResult += MemoryLayout<KEY>.size(ofValue: meta.key)
                partialResult += meta.value.sizeInBytes()
            }
            return currentTimestamp.sizeInBytes() + dictSize
        }
    }

    extension ORMap.ORMapState: ApproxSizeable {
        public func sizeInBytes() -> Int {
            let dictSize = maxClockValueByActor.reduce(into: 0) { partialResult, meta in
                partialResult += MemoryLayout<ActorID>.size(ofValue: meta.key)
                partialResult += MemoryLayout<UInt64>.size
            }
            return dictSize
        }
    }

    extension ORMap.ORMapDelta: ApproxSizeable {
        public func sizeInBytes() -> Int {
            let dictSize = updates.reduce(into: 0) { partialResult, meta in
                partialResult += MemoryLayout<KEY>.size(ofValue: meta.key)
                partialResult += meta.value.sizeInBytes()
            }
            return dictSize
        }
    }
#endif
