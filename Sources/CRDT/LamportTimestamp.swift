//
//  LamportTimestamp.swift
//

/// A Lamport timestamp for a specific actor.
///
/// The comparable value of the actor identity is used to deterministically order of Lamport timestamps in the scenario
/// where the clock value is identical. These scenarios happen when two independent CRDTs update internal values
/// "at the same time".
public struct LamportTimestamp<ActorID: Hashable & PartiallyOrderable>: Identifiable, PartiallyOrderable {
    var clock: UInt64 = 0
    var actorId: ActorID

    /// A stable, unique identity for the Lamport timestamp.
    public var id: String {
        description
    }

    /// Increments the value of the Lamport timestamp.
    public mutating func tick() {
        clock += 1
    }

    /// Returns a Boolean value indicating whether the value of the first timestamp is less than or equal to that of the second timestamp.
    ///
    /// Timestamps are first compared by an internal `clock` value, and uses the provided actor to deterministically order values when the clocks are identical.
    /// This assures that timestamps are partially order-able to satisfy  conformance to ``CRDT/PartiallyOrderable``.
    /// - Parameters:
    ///   - lhs: The first timestamp.
    ///   - rhs: The second timestamp.
    public static func <= (lhs: LamportTimestamp, rhs: LamportTimestamp) -> Bool {
        (lhs.clock, lhs.id) <= (rhs.clock, rhs.id)
    }

    /// Returns a Boolean value indicating whether the value of the first timestamp is greater than that of the second timestamp.
    ///
    /// Timestamps are first compared by an internal `clock` value, and uses the provided actor to deterministically order values when the clocks are identical.
    /// This assures that timestamps are partially order-able to satisfy  conformance to ``CRDT/PartiallyOrderable``.
    /// - Parameters:
    ///   - lhs: The first timestamp.
    ///   - rhs: The second timestamp.
    public static func > (lhs: LamportTimestamp, rhs: LamportTimestamp) -> Bool {
        !(lhs <= rhs)
    }

    /// Create a new Lamport timestamp with the actor identity you provide.
    /// - Parameters:
    ///   - clock: An optional initial clock value, that otherwise defaults to `0`.
    ///   - actorId: The actor identity for the timestamp.
    public init(clock: UInt64 = 0, actorId: ActorID) {
        self.clock = clock
        self.actorId = actorId
    }
}

extension LamportTimestamp: Codable where ActorID: Codable {}

extension LamportTimestamp: Sendable where ActorID: Sendable {}

extension LamportTimestamp: Equatable {}

extension LamportTimestamp: Hashable {}

extension LamportTimestamp: CustomStringConvertible {
    /// The description of the timestamp.
    ///
    /// In the format `[clockValue-actorID]`.
    public var description: String {
        "[\(clock)-\(actorId)]"
    }
}

extension LamportTimestamp: CustomDebugStringConvertible {
    /// The debug description of the timestamp.
    public var debugDescription: String {
        "LamportTimestamp<\(clock), \(actorId)>"
    }
}

#if DEBUG
    extension LamportTimestamp: ApproxSizeable {
        public func sizeInBytes() -> Int {
            MemoryLayout<UInt64>.size(ofValue: clock) + MemoryLayout<ActorID>.size(ofValue: actorId)
        }
    }
#endif
