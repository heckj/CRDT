//
//  LamportTimestamp.swift
//

/// A lamport timestamp for a specific actor.
public struct LamportTimestamp<ActorID: Hashable & Comparable>: Identifiable, Comparable {
    internal var clock: UInt64 = 0
    internal var actorId: ActorID

    /// The identity of the counter metadata (atom) computed from the actor Id and the lamport timestamp.
    public var id: String {
        "\(clock)-\(actorId)"
    }

    public mutating func tick() {
        clock += 1
    }

    public static func < (lhs: LamportTimestamp, rhs: LamportTimestamp) -> Bool {
        (lhs.clock, lhs.id) < (rhs.clock, rhs.id)
    }

    public init(clock: UInt64 = 0, actorId: ActorID) {
        self.clock = clock
        self.actorId = actorId
    }
}

extension LamportTimestamp: Codable where ActorID: Codable {}

extension LamportTimestamp: Equatable {}

extension LamportTimestamp: Hashable {}

extension LamportTimestamp: PartiallyOrderable {}

#if DEBUG
    extension LamportTimestamp: ApproxSizeable {
        public func sizeInBytes() -> Int {
            MemoryLayout<UInt64>.size(ofValue: clock) + MemoryLayout<ActorID>.size(ofValue: actorId)
        }
    }
#endif
