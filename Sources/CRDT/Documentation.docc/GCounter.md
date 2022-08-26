# ``CRDT/GCounter``

## Topics

### Creating a Counter

- ``CRDT/GCounter/init(_:actorID:)``

### Inspecting a Counter

- ``CRDT/GCounter/value``

### Incrementing the Counter

- ``CRDT/GCounter/increment()``

### Replicating Counters

- ``CRDT/GCounter/merged(with:)``
- ``CRDT/GCounter/merging(with:)``

### Delta-based Replicating

- ``CRDT/GCounter/state``
- ``CRDT/GCounter/delta(_:)``
- ``CRDT/GCounter/mergeDelta(_:)``
- ``CRDT/GCounter/mergingDelta(_:)``

### Decoding a Counter

- ``CRDT/GCounter/init(from:)``

### Debugging and Optimization Methods

- ``CRDT/GCounter/sizeInBytes()``

