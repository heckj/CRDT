//
//  WallclockTimestamp.swift
//

import Foundation

/// A wall-clock timestamp for a specific actor.
public struct WallclockTimestamp<ActorID: Hashable & Comparable>: Identifiable, Comparable {
    internal var clock: TimeInterval
    internal var actorId: ActorID

    /// The identity of the counter metadata (atom) computed from the actor Id and a current timestamp.
    public var id: String {
        "\(clock)-\(actorId)"
    }

    public static func < (lhs: WallclockTimestamp, rhs: WallclockTimestamp) -> Bool {
        (lhs.clock, lhs.id) < (rhs.clock, rhs.id)
    }

    public init(actorId: ActorID, timestamp: TimeInterval = Date().timeIntervalSinceReferenceDate) {
        clock = timestamp
        self.actorId = actorId
    }
}

extension WallclockTimestamp: Codable where ActorID: Codable {}

extension WallclockTimestamp: Equatable {}

extension WallclockTimestamp: Hashable {}

extension WallclockTimestamp: PartiallyOrderable {}

#if DEBUG
    extension WallclockTimestamp: ApproxSizeable {
        public func sizeInBytes() -> Int {
            MemoryLayout<TimeInterval>.size(ofValue: clock) + MemoryLayout<ActorID>.size(ofValue: actorId)
        }
    }
#endif
