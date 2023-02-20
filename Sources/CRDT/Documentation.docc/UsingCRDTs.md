# Using CRDTs

Understand the tradeoffs, pre-requisites, and capabilities to sync data using conflict-free replicated data types (CRDTs).

## Overview

CRDT is a low-level library and has some requisite expectations about how it can be used.
The primary pre-requisite is that each copy of the data that is being replicated needs to have its own, distinct, identifier.
The choice of how you apply the identity, allowing merges or not, and identity validation is not provided by this package.

CRDT data structures trade off consuming additional memory to provide the capability for seamless eventual consistency.
The additional memory tracks historical values and state changes for the collaborating instances.
There is also a performance impact when interacting with these types, as compared to a native type that doesn't support deterministic merging.
The details for prerequisites of identity, memory overhead, and inherent limits are detailed below.

### Collaboration Instances and Actor Ids

Each instance of the type that you are replicating between is required to have its own unique identifier.
An instance does not need to represent a person or a device.
Instead it represents the specific independent instance of the type that you want to allow to change independently.
If you create two separate instances with the same Id and attempt to merge them, the deterministic guarantees cease to exist.

For example, if you have a macOS app that you can run more than one instance of, each instance should be identifiable by its own `ActorID` for the purposes of seamlessly merging updates to the CRDT types.
Likewise, if you are synchronizing data between a macOS and iOS app, don't make the mistake of setting the actor Id to be the individual running the app, as this violates the preconditions for the library.
Instead, the macOS and iOS apps should each have a unique identifier for replicating the data between them.

### Seamless Eventual Consistency Doesn't Imply Semantic Correctness 

When you start off with CRDT types that are independently created, merging them is deterministic, meaning that you will always get the same result, but that result may not be what you perceive as correct.
This can happen, for example, when values are both added and removed to separate instances of types such as ``ORSet`` or ``ORMap`` before merging them together.
In this case, the types have different histories for the internal values.
The algorithms behind CRDTs use the sequential ordering of these histories - provided by the combination of the ActorId and a Lamport timestamp - to provide a deterministic result.
The result of replicating between the two independent created types will always be the same, but without having the detail of how to merge the histories together, the end result may be surprising - and perceived to be incorrect.

To avoid this surprising scenario, start any additional CRDT instances with the history from a "first" one before adding, updating, or removing values.

For more information on the techniques available to synchronize instances of CRDTs, see <doc:ReplicatingCRDTs>.

### Memory Overhead

The memory overhead is minimal for the simplest CRDTs: ``GCounter``, ``PNCounter``, and ``GSet``.
These types require a constant amount of memory, regardless of the number of changes applied to them.
Additional memory is needed to track the history when you can add and remove values, as is the case with the ``ORSet`` and ``ORMap`` types.
The memory needed to track the history when you can add, remove, and update unordered elements is slightly higher, and the total memory grows with the upper bound of the sum of all keys added and removed from these types.
The most memory is required to track history when you can add, remove, and maintain an ordered set of values.
The memory needed for `List` grows with the combination of all additions, removals, and edits to the array.

If the size of a list element is fairly small, a CRDT can represent a significant expansion in the total memory needed to represent that list.
This may not be a significant issue, but is definitely worth being aware of.
As an example, the library tests include [a test that shows the expansion of rough memory needed to store a string](https://github.com/heckj/CRDT/blob/f0ee6b25937a8ac1202432eba856d98f76f1cdf6/Tests/CRDTTests/grokTests.swift#L111) as a CRDT list of characters, which you might do to represent a collaboratively edited description.
The ``List`` CRDT type has the most memory overhead, but provides the most functionality in allowing items to be added, removed, updated, and their ordering preserved.
This space of CRDTs also has the most ongoing research and experimentation to optimize it.

Using a single character string as an `ActorID`, the expansion in space is roughly 21 times:

```
causalTree List size: 326
base list size: 15
expansion factor: 21.733333333333334
```

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
