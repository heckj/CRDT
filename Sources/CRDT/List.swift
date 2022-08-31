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

        let resultMetadataWithTombstones = Self.ordered(fromUnordered: unorderedContainers + combinedUniqueTombstones)
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

        let resultMetadataWithTombstones = Self.ordered(fromUnordered: unorderedContainers + combinedUniqueTombstones)
        let resultMetadata = resultMetadataWithTombstones.filter { !$0.isDeleted }

        var copy = self
        copy.activeValues = resultMetadata
        copy.tombstones = combinedUniqueTombstones
        copy.currentTimestamp.clock = Swift.max(currentTimestamp.clock, other.currentTimestamp.clock)
        return copy
    }

    /// Not just sorted, but ordered according to a preorder traversal of the causal tree.
    /// For each element, we insert the element itself first, then the child (anchored) subtrees from left to right.
    private static func ordered(fromUnordered unordered: [Metadata]) -> [Metadata] {
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
}

// MARK: Codable

extension List: Codable where T: Codable, ActorID: Codable {}

extension List.Metadata: Codable where T: Codable, ActorID: Codable {}

// MARK: Equatable and Hashable

extension List: Equatable where T: Equatable {}

extension List.Metadata: Equatable where T: Equatable {}

extension List: Hashable where T: Hashable {}

extension List.Metadata: Hashable where T: Hashable {}

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
