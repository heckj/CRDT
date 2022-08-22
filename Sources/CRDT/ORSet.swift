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
            self.isDeleted = false
            self.lamportTimestamp = lamportTimestamp
        }
    }
    
    internal var selfId: ActorID
    internal var currentTimestamp: LamportTimestamp<ActorID>
    internal var metadataByValue: Dictionary<T, Metadata>
    
    public init(actorId: ActorID) {
        selfId = actorId
        self.metadataByValue = .init()
        self.currentTimestamp = .init(actorId: selfId)
    }
    
    public init(actorId: ActorID, array elements: [T]) {
        selfId = actorId
        self = .init(actorId: selfId)
        elements.forEach { self.insert($0) }
    }
    
    public var values: Set<T> {
        let values = metadataByValue.filter({ !$1.isDeleted }).map({ $0.key })
        return Set(values)
    }
    
    public func contains(_ value: T) -> Bool {
        !(metadataByValue[value]?.isDeleted ?? true)
    }

    public var count: Int {
        metadataByValue.filter({ !$1.isDeleted }).count
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
        copy.currentTimestamp = max(self.currentTimestamp, other.currentTimestamp)
        return copy
    }
    
}

//extension ORSet: DeltaCRDT {
////    public typealias DeltaState = Self.Atom
////    public typealias Delta = Self.Atom
//    public var state: Atom {
//        _storage
//    }
//
//    public func delta(_: Atom?) -> [Atom] {
//        [_storage]
//    }
//
//    public func mergeDelta(_ delta: [Atom]) -> Self {
//        var copy = self
//        // Merging two grow-only sets is (conveniently) the union of the two sets
//        let reducedSet = delta.reduce(into: Set<T>(self._storage.values)) { partialResult, atom in
//            partialResult = partialResult.union(atom.values)
//        }
//        copy._storage.values = reducedSet
//        // The clock isn't used for ordering or merging, so updating it isn't strictly needed.
//        let maxClock = delta.reduce(into: 0) { partialResult, atom in
//            partialResult = max(partialResult, atom.clockId.clock)
//        }
//        copy._storage.clockId.clock = maxClock
//        copy._storage.clockId.tick()
//        return copy
//    }
//}

extension ORSet: Codable where T: Codable, ActorID: Codable {
}

extension ORSet.Metadata: Codable where T: Codable, ActorID: Codable {
}

extension ORSet: Equatable where T: Equatable {
}

extension ORSet.Metadata: Equatable where T: Equatable {
}

extension ORSet: Hashable where T: Hashable {
}

extension ORSet.Metadata: Hashable where T: Hashable {
}

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
            return MemoryLayout<ActorID>.size(ofValue: selfId) + currentTimestamp.sizeInBytes() + dictSize
        }
    }
#endif
