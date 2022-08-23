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
    associatedtype DeltaState
    associatedtype Delta

    var state: DeltaState { get }
    func delta(_ state: DeltaState?) -> Delta

    /// Merges the given delta into the state of this data type instance.
    ///
    /// - Parameter delta: The incremental, partial state to merge.
    func mergeDelta(_ delta: Delta) -> Self
}
