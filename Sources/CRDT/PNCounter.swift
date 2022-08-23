//
//  PNCounter.swift
//

import Foundation

/// Implements a Positive-Negative Counter
/// Based on GCounter implementation as described in "Convergent and Commutative Replicated Data Types"
/// - SeeAlso: [A comprehensive study of Convergent and Commutative Replicated Data Types](https://hal.inria.fr/inria-00555588/document)” by Marc Shapiro, Nuno Preguiça, Carlos Baquero, and Marek Zawirski (2011).
public struct PNCounter<ActorID: Hashable & Comparable> {
    internal var pos_value: UInt
    internal var neg_value: UInt
    internal let selfId: ActorID

    /// The counter's value.
    public var value: Int {
        // ternary operator, since I can never entirely remember the sequence:
        // expression ? valueIfTrue : valueIfFalse

        // clamp UInt values to maximum Int values to avoid overflowing the runtime conversion
        let pos_int: Int = pos_value <= Int.max ? Int(pos_value) : Int.max
        let neg_int: Int = neg_value <= Int.max ? Int(neg_value) : Int.max

        return pos_int - neg_int
    }

    /// Increments the counter.
    @discardableResult
    public mutating func increment() -> Int {
        pos_value += 1
        return value
    }

    /// Decrements the counter.
    @discardableResult
    public mutating func decrement() -> Int {
        neg_value += 1
        return value
    }

    /// Creates a new counter.
    /// - Parameters:
    ///   - value: An optional parameter to set an initial counter value.
    ///   - actorID: The identity of the collaborator for the counter.
    public init(_ value: Int = 0, actorID: ActorID) {
        selfId = actorID
        if value >= 0 {
            pos_value = UInt(value)
            neg_value = 0
        } else {
            pos_value = 0
            neg_value = value > Int.min ? UInt(abs(value)) : UInt(abs(Int.min + 1))
        }
    }
}

extension PNCounter: Replicable {
    /// Returns a new counter by merging two counter instances.
    /// - Parameter other: The counter to merge.
    public func merged(with other: Self) -> Self {
        var copy = self
        copy.pos_value = max(other.pos_value, pos_value)
        copy.neg_value = max(other.neg_value, neg_value)
        return copy
    }
}

extension PNCounter: DeltaCRDT {
//    public typealias DeltaState = Self.Atom
//    public typealias Delta = Self.Atom

    /// A struct that represents the state of a PNCounter.
    public struct PNCounterState {
        let pos: UInt
        let neg: UInt
    }

    /// The current state of the CRDT.
    public var state: PNCounterState {
        get async {
            PNCounterState(pos: pos_value, neg: neg_value)
        }
    }

    /// Computes and returns a diff from the current state of the counter to be used to update another instance.
    ///
    /// - Parameter state: The optional state of the remote CRDT.
    /// - Returns: The changes to be merged into the counter instance that provided the state to converge its state with this instance.
    public func delta(_: PNCounterState?) async -> PNCounterState {
        PNCounterState(pos: pos_value, neg: neg_value)
    }

    /// Returns a new instance of an counter with the delta you provide merged into the current counter.
    /// - Parameter delta: The incremental, partial state to merge.
    public func mergeDelta(_ delta: PNCounterState) async -> Self {
        var copy = self
        copy.pos_value = max(delta.pos, pos_value)
        copy.neg_value = max(delta.neg, neg_value)
        return copy
    }
}

extension PNCounter: Codable where ActorID: Codable {}
extension PNCounter.PNCounterState: Codable where ActorID: Codable {}

extension PNCounter: Equatable {}
extension PNCounter.PNCounterState: Equatable {}

extension PNCounter: Hashable {}
extension PNCounter.PNCounterState: Hashable {}

#if DEBUG
    extension PNCounter: ApproxSizeable {
        public func sizeInBytes() -> Int {
            2 * MemoryLayout<UInt>.size + MemoryLayout<ActorID>.size(ofValue: selfId)
        }
    }

    extension PNCounter.PNCounterState: ApproxSizeable {
        public func sizeInBytes() -> Int {
            2 * MemoryLayout<UInt>.size
        }
    }
#endif
