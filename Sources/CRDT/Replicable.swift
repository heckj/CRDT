//
//  Replicable.swift
//

public protocol Replicable {
    func merged(with other: Self) -> Self
}

/// Delta State CvRDT (ẟ-CvRDT), a kind of state-based CRDT.
///
/// Incremental state (delta) rather than the entire state is disseminated as an optimization.
///
/// - SeeAlso: [Delta State Replicated Data Types](https://arxiv.org/abs/1603.01529)
/// - SeeAlso: [Efficient Synchronization of State-based CRDTs](https://arxiv.org/pdf/1803.02750.pdf)
public protocol DeltaCRDT: Replicable {
    /// `Delta` type should be registered and (de-)serializable using the Actor serialization infrastructure.
    ///
    /// - SeeAlso: The library's documentation on serialization for more information.
    associatedtype Delta: Replicable

    var delta: Delta? { get }

    // Do we want something that provides a list of atoms for this CRDT
    // func atoms() -› [LogEncodable]
    //  - the atoms need to be identifiable, codable, and they need to be comparable

    /// Merges the given delta into the state of this data type instance.
    ///
    /// - Parameter delta: The incremental, partial state to merge.
    mutating func mergeDelta(_ delta: Delta)

    /// Resets the delta of this data type instance.
    // mutating func resetDelta()
}

extension DeltaCRDT {
    /// Creates a data type instance by merging the given delta with the state of this data type instance.
    ///
    /// - Parameter delta: The incremental, partial state to merge.
    /// - Returns: A new data type instance with the merged state of this data type instance and `delta`.
    func mergingDelta(_ delta: Delta) -> Self {
        var result = self
        result.mergeDelta(delta)
        return result
    }
}
