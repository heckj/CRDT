//
//  CRDTMergeError.swift
//

/// Errors related to failures in merging CRDT instances.
public enum CRDTMergeError: Error {
    /// The metadata from the remote CRDT conflicts with the local metadata.
    case conflictingHistory(_ msg: String)
    /// The metadata from a remote CRDT doesn't include all the operations to generate a complete and consistent causal tree.
    case inconsistentCausalTree(_ msg: String)
}
