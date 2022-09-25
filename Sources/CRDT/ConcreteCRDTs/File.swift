//
//  File.swift
//
//
//  Created by Joseph Heck on 9/25/22.
//

import Foundation

public enum S64 {
    static func counter(collaboratorId: UInt64) -> PNCounter<UInt64> {
        PNCounter(actorID: collaboratorId)
    }

    static func set<T: Hashable>(collaboratorId: UInt64) -> ORSet<UInt64, T> {
        ORSet(actorId: collaboratorId)
    }

    static func map<KEY: Hashable, VALUE: Equatable>(collaboratorId: UInt64) -> ORMap<UInt64, KEY, VALUE> {
        ORMap(actorId: collaboratorId)
    }

    static func list<T: Hashable & Comparable & Equatable>(collaboratorId: UInt64) -> List<UInt64, T> {
        List(actorId: collaboratorId)
    }
}

public enum SUUID {
    static func counter(collaboratorId: UUID) -> PNCounter<UUID> {
        PNCounter(actorID: collaboratorId)
    }

    static func set<T: Hashable>(collaboratorId: UUID) -> ORSet<UUID, T> {
        ORSet(actorId: collaboratorId)
    }

    static func map<KEY: Hashable, VALUE: Equatable>(collaboratorId: UUID) -> ORMap<UUID, KEY, VALUE> {
        ORMap(actorId: collaboratorId)
    }

    static func list<T: Hashable & Comparable & Equatable>(collaboratorId: UUID) -> List<UUID, T> {
        List(actorId: collaboratorId)
    }
}
