# ``CRDT/GSet``

## Topics

### Creating a Set

- ``CRDT/GSet/init(actorId:clock:)``
- ``CRDT/GSet/init(actorId:clock:_:)``

### Inspecting the Set

- ``CRDT/GSet/values``
- ``CRDT/GSet/contains(_:)``
- ``CRDT/GSet/count``

### Growing the Set

- ``CRDT/GSet/insert(_:)``

### Replicating a Set

- ``CRDT/GSet/merged(with:)``

### Delta-based Replicating

- ``CRDT/GSet/state``
- ``CRDT/GSet/delta(_:)``
- ``CRDT/GSet/mergeDelta(_:)``
- ``CRDT/GSet/GSetDelta``

### Decoding a Set

- ``CRDT/GSet/init(from:)``

### Debugging and Optimization Methods

- ``CRDT/LWWRegister/sizeInBytes()``
