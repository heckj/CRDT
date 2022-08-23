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

    public var value: UInt {
        _storage
    }

    public mutating func increment() {
        if _storage != UInt.max {
            _storage += 1
        }
    }

    public init(_ value: UInt = 0, actorID: ActorID) {
        selfId = actorID
        _storage = value
    }
}

extension GCounter: Replicable {
    public func merged(with other: Self) -> Self {
        var copy = self
        copy._storage = max(value, other._storage)
        return copy
    }
}

extension GCounter: DeltaCRDT {
    public var state: UInt {
        _storage
    }

    public func delta(_: UInt?) -> UInt {
        _storage
    }

    public func mergeDelta(_ delta: UInt) -> Self {
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
