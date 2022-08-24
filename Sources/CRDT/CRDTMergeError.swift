//
//  CRDTMergeError.swift
//

/// Errors related to failures in merging CRDT instances.
public enum CRDTMergeError: Error {
    /// The metadata from the remote CRDT conflicts with the local metadata.
    case conflictingHistory(_ msg: String)
}
