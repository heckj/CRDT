//
//  ApproxSizeable.swift
//

import Foundation

#if DEBUG
    /// A type that reports an approximate memory size, useful for debugging and proofing.
    public protocol ApproxSizeable {
        /// Returns the approximate size, in bytes, of the memory used.
        func sizeInBytes() -> Int
    }

    extension String: ApproxSizeable {
        public func sizeInBytes() -> Int {
            maximumLengthOfBytes(using: .utf8)
        }
    }

    extension Array: ApproxSizeable where Array.Element == String {
        public func sizeInBytes() -> Int {
            let eleSize = reduce(into: 0) { partialResult, element in
                partialResult += element.sizeInBytes()
            }
            return eleSize
        }
    }

#endif
