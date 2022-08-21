//
//  Replicable.swift
//

/// A type that can be merged with itself, providing a deterministic result.
///
/// Replicable is the core feature of a Conflict-free Replicated Data Type (CRDT).
/// Any implementation of a CRDT should provide the following guarantees of the merge:
/// - Commutative (a -merged-> b = b -merged-> a)
/// - Associative ((a -merged-> b) -merged-> c) = (a -merged-> (b -merged-> c))
/// - Idempotent (a -merged-> a = a)
public protocol Replicable {
    func merged(with other: Self) -> Self
}

/// A type that can be used to determine partial order sets or sequences.
///
/// Per [Partial Order at Wolfram MathWorld](https://mathworld.wolfram.com/PartialOrder.html):
/// 1. Reflexivity: `a<=a` for all `a` in `S`.
/// 2. Antisymmetry: `a<=b` and `b<=a` implies `a=b`.
/// 3. Transitivity: `a<=b` and `b<=c` implies `a<=c`.
public protocol PartiallyOrderable {
    static func <= (lhs: Self, rhs: Self) -> Bool
}

/// A type of CRDT that supports delta replication.
///
/// Incremental state (delta) rather than the entire state is disseminated as an optimization for replicating
/// state-based CRDTs. This protocol encapsulates a two-phase state/delta handshake, by allowing a
/// state to be presented from another type, which is then used to calculate the delta's needed to bring the
/// state up to a converged status with the replica that provided the state.
///
/// - SeeAlso: [Delta State Replicated Data Types](https://arxiv.org/abs/1603.01529)
/// - SeeAlso: [Efficient Synchronization of State-based CRDTs](https://arxiv.org/pdf/1803.02750.pdf)
public protocol DeltaCRDT: Replicable {
    associatedtype DeltaState: PartiallyOrderable
    associatedtype Delta: PartiallyOrderable, Identifiable

    var state: DeltaState { get }
    func delta(_ state: DeltaState?) -> [Delta]

    // Do we want something that provides a list of atoms for this CRDT
    // func atoms() -› [LogEncodable]
    //  - the atoms need to be identifiable, codable, and they need to be comparable

    /// Merges the given delta into the state of this data type instance.
    ///
    /// - Parameter delta: The incremental, partial state to merge.
    func mergeDelta(_ delta: [Delta]) -> Self
}

extension DeltaCRDT {
    /// Creates a data type instance by merging the given delta with the state of this data type instance.
    ///
    /// - Parameter delta: The incremental, partial state to merge.
    /// - Returns: A new data type instance with the merged state of this data type instance and `delta`.
    func mergingDelta(_ delta: Delta) -> Self {
        mergeDelta([delta])
    }
}
