//
//  WallclockTimestamp.swift
//

import Foundation

/// A wall-clock timestamp for a specific actor.
///
/// The comparable value of the actor identity is used to deterministically order of wallclock timestamps in the (unlikely, but possible) scenario
/// where the clock value is identical. These scenarios happen when two independent CRDTs update internal values
/// "at the same time".
public struct WallclockTimestamp<ActorID: Hashable & PartiallyOrderable>: Identifiable, PartiallyOrderable {
    internal var clock: TimeInterval
    internal var actorId: ActorID

    /// A stable, unique identity for the wallclock timestamp.
    public var id: String {
        description
    }

    /// Returns a Boolean value indicating whether the value of the first timestamp is greater than that of the second timestamp.
    ///
    /// Timestamps are first compared by an internal `clock` value, and uses the provided actor to deterministically order values when the clocks are identical.
    /// This assures that timestamps are partially order-able to satisfy  conformance to ``CRDT/PartiallyOrderable``.
    /// - Parameters:
    ///   - lhs: The first timestamp.
    ///   - rhs: The second timestamp.
    public static func > (lhs: WallclockTimestamp, rhs: WallclockTimestamp) -> Bool {
        !(lhs <= rhs)
    }

    /// Returns a Boolean value indicating whether the value of the first timestamp is less than or equal to that of the second timestamp.
    ///
    /// Timestamps are first compared by an internal `clock` value, and uses the provided actor to deterministically order values when the clocks are identical.
    /// This assures that timestamps are partially order-able to satisfy  conformance to ``CRDT/PartiallyOrderable``.
    /// - Parameters:
    ///   - lhs: The first timestamp.
    ///   - rhs: The second timestamp.
    public static func <= (lhs: WallclockTimestamp<ActorID>, rhs: WallclockTimestamp<ActorID>) -> Bool {
        if lhs.clock == rhs.clock {
            return rhs.id <= lhs.id
        }
        return lhs.clock <= rhs.clock
    }

    /// Create a new Lamport timestamp with the actor identity you provide.
    /// - Parameters:
    ///   - clock: An optional initial clock value, that otherwise defaults to a value determined by the current time.
    ///   - actorId: The actor identity for the timestamp.
    public init(actorId: ActorID, timestamp: TimeInterval = Date().timeIntervalSinceReferenceDate) {
        clock = timestamp
        self.actorId = actorId
    }
}

extension WallclockTimestamp: Codable where ActorID: Codable {}

extension WallclockTimestamp: Sendable where ActorID: Sendable {}

extension WallclockTimestamp: Equatable {}

extension WallclockTimestamp: Hashable {}

extension WallclockTimestamp: CustomStringConvertible {
    /// The description of the timestamp.
    ///
    /// In the format `[clockValue-actorID]`.
    public var description: String {
        "[\(clock)-\(actorId)]"
    }
}

extension WallclockTimestamp: CustomDebugStringConvertible {
    /// The debug description of the timestamp.
    public var debugDescription: String {
        "LamportTimestamp<\(clock), \(actorId)>"
    }
}

#if DEBUG
    extension WallclockTimestamp: ApproxSizeable {
        public func sizeInBytes() -> Int {
            MemoryLayout<TimeInterval>.size(ofValue: clock) + MemoryLayout<ActorID>.size(ofValue: actorId)
        }
    }
#endif
