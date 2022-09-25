//
//  Concrete.swift
//

import Foundation

/// A collection of initializers for CRDTs that use a 64-bit collaboration identifier.
public enum CRDT_64 {
    
    /// Creates a counter with the collaboration identifier you provide.
    /// - Parameter collaboratorId: The collaboration identifier.
    public static func counter(collaboratorId: UInt64) -> PNCounter<UInt64> {
        PNCounter(actorID: collaboratorId)
    }

    /// Creates a set with the collaboration identifier you provide.
    /// - Parameter collaboratorId: The collaboration identifier.
    public static func set<T: Hashable>(collaboratorId: UInt64) -> ORSet<UInt64, T> {
        ORSet(actorId: collaboratorId)
    }

    /// Creates a map with the collaboration identifier you provide.
    /// - Parameter collaboratorId: The collaboration identifier.
    public static func map<KEY: Hashable, VALUE: Equatable>(collaboratorId: UInt64) -> ORMap<UInt64, KEY, VALUE> {
        ORMap(actorId: collaboratorId)
    }

    /// Creates a list with the collaboration identifier you provide.
    /// - Parameter collaboratorId: The collaboration identifier.
    public static func list<T: Hashable & Comparable & Equatable>(collaboratorId: UInt64) -> List<UInt64, T> {
        List(actorId: collaboratorId)
    }
}

/// A collection of initializers for CRDTs that use UUID for a collaboration identifier.
public enum CRDT_UUID {

    /// Creates a counter with the collaboration identifier you provide.
    /// - Parameter collaboratorId: The collaboration identifier.
    public static func counter(collaboratorId: UUID) -> PNCounter<UUID> {
        PNCounter(actorID: collaboratorId)
    }

    /// Creates a set with the collaboration identifier you provide.
    /// - Parameter collaboratorId: The collaboration identifier.
    public static func set<T: Hashable>(collaboratorId: UUID) -> ORSet<UUID, T> {
        ORSet(actorId: collaboratorId)
    }

    /// Creates a map with the collaboration identifier you provide.
    /// - Parameter collaboratorId: The collaboration identifier.
    public static func map<KEY: Hashable, VALUE: Equatable>(collaboratorId: UUID) -> ORMap<UUID, KEY, VALUE> {
        ORMap(actorId: collaboratorId)
    }

    /// Creates a list with the collaboration identifier you provide.
    /// - Parameter collaboratorId: The collaboration identifier.
    public static func list<T: Hashable & Comparable & Equatable>(collaboratorId: UUID) -> List<UUID, T> {
        List(actorId: collaboratorId)
    }
}
