# Using CRDTs

Understand the tradeoffs and capabilities when you use conflict-free replicated data types (CRDTs).

## Overview

The key tradeoff when using CRDTs is that of additional memory needed to track the historical values and state of any merges between collaborating instances.
There is a slight performance impact when interacting with these types, as compared to a native type that doesn't support deterministic merging.

### Collaboration Instances and Actor Ids

Each instance of the type that you are replicating between is required to have its own unique identifier.
An instance does not need to represent a person or a device.
Instead it represents the specific independent instance of the type that you want to allow to change independently.
If you create two separate instances with the same Id and attempt to merge them, the deterministic guarantees cease to exist.

For example, if you have a macOS app that you can run more than one instance of, each instance should be identifiable by its own `ActorID` for the purposes of seamlessly merging updates to the CRDT types.
Likewise, if you are synchronizing data between a macOS and iOS app, don't make the mistake of setting the actor Id to be the individual running the app, as you are violating the preconditions for the library.

### Limits of CRDTs

All CRDT types have an upper limit on the number of changes they can track, and on the number of collaborators that they can support.
In this library, the number of changes by any individual is limited by the size of the Lamport clock with ``LamportTimestamp``, which uses `UInt64` to track this value.
By using `UInt64`, each collaborator can make 18.4e+18 changes.
In practice, you aren't likely to run into this limit, but it is worth being aware of.

The number of collaborators is constrained to the number of different values that an `ActorID` can represent. 
`ActorID` is a generic type in this library, allowing you to define both the type.
For example, if you used `UInt8`, you could support up to 255 collaboration instances.

The choice of type impacts how much memory is required as additional tracking information for each of the types.
In ``ORSet``, ``ORMap``, and ``List`` the combination of the both the size of the `ActorID` and the size of the Lamport timestamp are used to track the history of each element.
The causal tree implementation of ``List`` includes an additional metadata to track the parent id within the causal tree.  


### Memory Overhead

The memory overhead is minimal for the simplest CRDTs: ``GCounter``, ``PNCounter``, and ``GSet``.
These types require a constant amount of memory, regardless of the number of changes applied to them.
Additional memory is needed to track the history when you can add and remove values, as is the case with the ``ORSet`` and ``ORMap`` types.
The memory needed to track the history when you can add, remove, and update unordered elements is slightly higher, and the total memory grows with the upper bound of the sum of all keys added and removed from these types.
The most memory is required to track history when you can add, remove, and maintain an ordered set of values.
The memory needed for `List` grows with the combination of all additions, removals, and edits to the array.

### Seamless Replication Doesn't Imply Correctness 

When you start off with CRDT types that are independent, merging them is deterministic, meaning that you will always get the same result, but that result may not be what you perceive as correct.
This can happen, for example, when values are both added and removed to separate instances of types such as ``ORSet`` or ``ORMap`` before merging them together.
In this case, the types have different histories for the internal values.
The algorithms behind CRDTs use the ordering of these histories - the combination of the ActorId and a Lamport timestamp - to provide the determinism.

To avoid this surprising scenario, start any additional CRDT instances with the history from a "first" one before adding, updating, or removing values.

For more information on the techniques available to synchronize instances of CRDTs, see <doc:ReplicatingCRDTs>.
