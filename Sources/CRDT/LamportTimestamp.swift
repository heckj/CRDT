//
//  LamportTimestamp.swift
//

public struct LamportTimestamp<ActorID: Hashable & Comparable>: Identifiable, Comparable {
    internal var clock: UInt64 = 0
    public var id: ActorID

    public mutating func tick() {
        clock += 1
    }

    public static func < (lhs: LamportTimestamp, rhs: LamportTimestamp) -> Bool {
        (lhs.clock, lhs.id) < (rhs.clock, rhs.id)
    }
}

extension LamportTimestamp: Codable where ActorID: Codable {}

extension LamportTimestamp: Equatable {}

extension LamportTimestamp: Hashable {}

extension LamportTimestamp: PartiallyOrderable {}
