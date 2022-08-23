//
//  ORSet.swift
//

import Foundation

/// Observed-Remove Set.
///
/// The `ORSet` can add and remove items from the set, compared to a ``GSet``, which can only add.
/// This is more powerful than the `GSet`, but has extra storage costs.
///
/// The implementation is based on "An Optimized Conflict-free Replicated Set" by
/// Annette Bieniusa, Marek Zawirski, Nuno Preguiça, Marc Shapiro, Carlos Baquero, Valter Balegas, and Sérgio Duarte (2012).
/// arXiv:[1210.3368](https://arxiv.org/abs/1210.3368)
public struct ORSet<ActorID: Hashable & Comparable, T: Hashable> {
    public struct Metadata {
        var isDeleted: Bool
        var lamportTimestamp: LamportTimestamp<ActorID>

        init(lamportTimestamp: LamportTimestamp<ActorID>) {
            isDeleted = false
            self.lamportTimestamp = lamportTimestamp
        }
    }

    internal var currentTimestamp: LamportTimestamp<ActorID>
    internal var metadataByValue: [T: Metadata]

    public init(actorId: ActorID) {
        metadataByValue = .init()
        currentTimestamp = .init(actorId: actorId)
    }

    public init(actorId: ActorID, _ elements: [T]) {
        self = .init(actorId: actorId)
        elements.forEach { self.insert($0) }
    }

    public var values: Set<T> {
        let values = metadataByValue.filter { !$1.isDeleted }.map(\.key)
        return Set(values)
    }

    public func contains(_ value: T) -> Bool {
        !(metadataByValue[value]?.isDeleted ?? true)
    }

    public var count: Int {
        metadataByValue.filter { !$1.isDeleted }.count
    }

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
    //    associatedtype DeltaState
    /// The minimal state for an ORSet to compute diffs for replication.
    public struct ORSetState {
        let maxClockValueByActor: [ActorID: UInt64]
    }

    //    associatedtype Delta
    /// The set of changes to bring another ORSet instance up to the same state.
    public struct ORSetDelta {
        let updates: [T: Metadata]
    }

    // var state: DeltaState { get }
    /// The current state of the ORSet.
    public var state: ORSetState {
        // The composed, compressed state to compare consists of a list of all the collaborators (represented
        // by the actorId in the LamportTimestamps) with their highest value for clock.
        var maxClockValueByActor: [ActorID: UInt64]
        maxClockValueByActor = metadataByValue.reduce(into: [:]) { partialResult, valueMetaData in
            // Do the keys already reference an actorID?
            if partialResult.keys.contains(valueMetaData.value.lamportTimestamp.actorId) {
                // The keys know of this actorId, so update the value is the clock value of the timestamp is larger.
                if let latestKnownClock = partialResult[valueMetaData.value.lamportTimestamp.actorId],
                   latestKnownClock < valueMetaData.value.lamportTimestamp.clock
                {
                    partialResult[valueMetaData.value.lamportTimestamp.actorId] = valueMetaData.value.lamportTimestamp.clock
                }
            } else {
                // The keys don't know of this actorId, so add this one as the latest value.
                partialResult[valueMetaData.value.lamportTimestamp.actorId] = valueMetaData.value.lamportTimestamp.clock
            }
        }
        return ORSetState(maxClockValueByActor: maxClockValueByActor)
    }

    // func delta(_ state: DeltaState?) -> Delta
    /// Computes and returns a diff from the current state of the ORSet to be used to update another instance.
    ///
    /// If you don't provide a state from another ORSet instance, the returned delta represents the full state.
    ///
    /// - Parameter state: The optional state of the remote ORSet.
    /// - Returns: The changes to be merged into the ORSet instance that provided the state to converge its state with this instance.
    public func delta(_ otherInstanceState: ORSetState?) -> ORSetDelta {
        // In the case of a null state being provided, the delta is all current values and their metadata:
        guard let maxClockValueByActor: [ActorID: UInt64] = otherInstanceState?.maxClockValueByActor else {
            return ORSetDelta(updates: metadataByValue)
        }
        // The state of a remote instance has been provided to us as a list of actorIds and max clock values.
        var statesToReplicate: [T: Metadata]

        // To determine the changes that need to be replicated to the instance that provided the state:
        // Iterate through the local collection:
        statesToReplicate = metadataByValue.reduce(into: [:]) { partialResult, keyMetaData in
            // - If any actorIds are in our list that they don't have, include all values
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

    // func mergeDelta(_ delta: Delta) -> Self
    /// Returns a new instance of an ORSet with the delta you provide merged into the current ORSet.
    /// - Parameter delta: The incremental, partial state to merge.
    public func mergeDelta(_ delta: ORSetDelta) -> Self {
        var copy = self
        for (valueKey, metadata) in delta.updates {
            copy.metadataByValue[valueKey] = metadata
            // If the remote values have a more recent clock value for this actor instance,
            // increment the clock.
            if metadata.lamportTimestamp.actorId == copy.currentTimestamp.actorId, metadata.lamportTimestamp.clock > copy.currentTimestamp.clock {
                copy.currentTimestamp.clock = metadata.lamportTimestamp.clock
            }
        }
        return copy
    }
}

extension ORSet: Codable where T: Codable, ActorID: Codable {}

extension ORSet.Metadata: Codable where T: Codable, ActorID: Codable {}

extension ORSet: Equatable where T: Equatable {}

extension ORSet.Metadata: Equatable where T: Equatable {}

extension ORSet: Hashable where T: Hashable {}

extension ORSet.Metadata: Hashable where T: Hashable {}

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
