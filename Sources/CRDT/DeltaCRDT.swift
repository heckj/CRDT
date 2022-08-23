//
//  DeltaCRDT.swift
//

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
    /// A type that represents minimal state needed to compute a minimal set of differences that still results in converging CRDTs.
    associatedtype DeltaState
    /// A type that represents a minimal set of differences to merge that results in a converging CRDT.
    associatedtype Delta

    /// The current state of the CRDT.
    var state: DeltaState { get }

    /// Computes and returns a diff from the current state of the CRDT to be used to update another instance.
    ///
    /// If you don't provide a state from another instance of the same type of CRDT, the returned delta represents the full state of the CRDT.
    ///
    /// - Parameter state: The optional state of the remote CRDT.
    /// - Returns: The changes to be merged into the CRDT instance that provided the state to converge its state with this instance.
    func delta(_ state: DeltaState?) async -> Delta

    /// Merges the given delta into the state of this data type instance.
    ///
    /// - Parameter delta: The incremental, partial state to merge.
    func mergeDelta(_ delta: Delta) async -> Self
}
