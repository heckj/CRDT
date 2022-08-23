//
//  GCounter.swift
//

import Foundation

/// Implements a Grow-only Counter
/// Based on GCounter implementation as described in "Convergent and Commutative Replicated Data Types"
/// - SeeAlso: [A comprehensive study of Convergent and Commutative Replicated Data Types](https://hal.inria.fr/inria-00555588/document)” by Marc Shapiro, Nuno Preguiça, Carlos Baquero, and Marek Zawirski (2011).
public struct GCounter<ActorID: Hashable & Comparable> {
    private var _storage: UInt
    internal let selfId: ActorID

    /// The counter's value.
    public var value: UInt {
        _storage
    }

    /// Increments the counter.
    @discardableResult
    public mutating func increment() -> UInt {
        if _storage != UInt.max {
            _storage += 1
        }
        return _storage
    }

    /// Creates a new counter.
    /// - Parameters:
    ///   - value: An optional parameter to set an initial counter value.
    ///   - actorID: The identity of the collaborator for the counter.
    public init(_ value: UInt = 0, actorID: ActorID) {
        selfId = actorID
        _storage = value
    }
}

extension GCounter: Replicable {
    /// Returns a new counter by merging two counter instances.
    /// - Parameter other: The counter to merge.
    public func merged(with other: Self) -> Self {
        var copy = self
        copy._storage = max(value, other._storage)
        return copy
    }
}

extension GCounter: DeltaCRDT {
    /// The current state of the CRDT.
    public var state: UInt {
        get async {
            _storage
        }
    }

    /// Computes and returns a diff from the current state of the counter to be used to update another instance.
    ///
    /// - Parameter state: The optional state of the remote CRDT.
    /// - Returns: The changes to be merged into the counter instance that provided the state to converge its state with this instance.
    public func delta(_: UInt?) async -> UInt {
        _storage
    }

    /// Returns a new instance of a counter with the delta you provide merged into the current counter.
    /// - Parameter delta: The incremental, partial state to merge.
    public func mergeDelta(_ delta: UInt) async -> Self {
        var copy = self
        copy._storage = max(_storage, delta)
        return copy
    }
}

extension GCounter: Codable where ActorID: Codable {}
extension GCounter: Equatable {}
extension GCounter: Hashable {}

#if DEBUG
    extension GCounter: ApproxSizeable {
        public func sizeInBytes() -> Int {
            MemoryLayout<UInt>.size + MemoryLayout<ActorID>.size(ofValue: selfId)
        }
    }

    extension UInt: ApproxSizeable {
        public func sizeInBytes() -> Int {
            MemoryLayout<UInt>.size
        }
    }
#endif
