# ``CRDT/PNCounter``

## Topics

### Creating a Counter

- ``CRDT/PNCounter/init(_:actorID:)``

### Inspecting a Counter

- ``CRDT/PNCounter/value``

### Adjusting the Counter

- ``CRDT/PNCounter/increment()``
- ``CRDT/PNCounter/decrement()``

### Replicating Counters

- ``CRDT/PNCounter/merged(with:)``

### Delta-based Replicating

- ``CRDT/PNCounter/state``
- ``CRDT/PNCounter/delta(_:)``
- ``CRDT/PNCounter/mergeDelta(_:)``
- ``CRDT/PNCounter/PNCounterState``

### Decoding a Counter

- ``CRDT/PNCounter/init(from:)``

### Debugging and Optimization Methods

- ``CRDT/PNCounter/sizeInBytes()``

