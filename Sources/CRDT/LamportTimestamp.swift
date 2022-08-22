//
//  LamportTimestamp.swift
//

public struct LamportTimestamp<ActorID: Hashable & Comparable>: Identifiable, Comparable {
    var count: UInt64 = 0
    public var id: ActorID

    public mutating func tick() {
        count += 1
    }

    public static func < (lhs: LamportTimestamp, rhs: LamportTimestamp) -> Bool {
        (lhs.count, lhs.id) < (rhs.count, rhs.id)
    }
}

extension LamportTimestamp: Codable where ActorID: Codable {}

extension LamportTimestamp: Equatable {}

extension LamportTimestamp: Hashable {}

extension LamportTimestamp: PartiallyOrderable {}
