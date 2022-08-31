# ``CRDT/List``

## Topics

### Creating a List

- ``CRDT/List/init(actorId:clock:)``
- ``CRDT/List/init(actorId:clock:_:)``

### Inspecting the Map

- ``CRDT/ORMap/keys``
- ``CRDT/ORMap/values``
- ``CRDT/ORMap/count``

### Updating the Map

- ``CRDT/ORMap/subscript(_:)``

### Replicating a Map

- ``CRDT/ORMap/merged(with:)``
- ``CRDT/ORMap/merging(with:)``

### Delta-based Replicating

- ``CRDT/ORMap/state``
- ``CRDT/ORMap/ORMapState``
- ``CRDT/ORMap/delta(_:)``
- ``CRDT/ORMap/ORMapDelta``
- ``CRDT/ORMap/mergeDelta(_:)``
- ``CRDT/ORMap/mergingDelta(_:)``

### Decoding a Set

- ``CRDT/ORMap/init(from:)``

### Debugging and Optimization Methods

- ``CRDT/ORMap/sizeInBytes()``
