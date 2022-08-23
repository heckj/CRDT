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
