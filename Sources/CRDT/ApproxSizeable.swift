//
//  ApproxSizeable.swift
//

import Foundation

#if DEBUG
    /// A type that reports is approximate memory size, useful for debugging and proofing.
    public protocol ApproxSizeable {
        /// Returns the approximate size, in bytes, of the memory used.
        func sizeInBytes() -> Int
    }
#endif
