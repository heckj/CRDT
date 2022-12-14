# ``CRDT/ORMap``

## Topics

### Creating a Set

- ``CRDT/ORMap/init(actorId:clock:)``
- ``CRDT/ORMap/init(actorId:clock:_:)``

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

### Decoding a Map

- ``CRDT/ORMap/init(from:)``

### Debugging and Optimization Methods

- ``CRDT/ORMap/sizeInBytes()``
