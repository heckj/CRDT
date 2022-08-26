# ``CRDT/ORSet``

## Topics

### Creating a Set

- ``CRDT/ORSet/init(actorId:clock:)``
- ``CRDT/ORSet/init(actorId:clock:_:)``

### Inspecting the Set

- ``CRDT/ORSet/values``
- ``CRDT/ORSet/contains(_:)``
- ``CRDT/ORSet/count``

### Updating the Set

- ``CRDT/ORSet/insert(_:)``
- ``CRDT/ORSet/remove(_:)``

### Replicating a Set

- ``CRDT/ORSet/merged(with:)``
- ``CRDT/ORSet/merging(with:)``

### Delta-based Replicating

- ``CRDT/ORSet/state``
- ``CRDT/ORSet/ORSetState``
- ``CRDT/ORSet/delta(_:)``
- ``CRDT/ORSet/ORSetDelta``
- ``CRDT/ORSet/mergeDelta(_:)``
- ``CRDT/ORSet/mergingDelta(_:)``

### Decoding a Set

- ``CRDT/ORSet/init(from:)``

### Debugging and Optimization Methods

- ``CRDT/ORSet/sizeInBytes()``
