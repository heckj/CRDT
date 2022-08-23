# ``CRDT/LWWRegister``

## Topics

### Creating a Register

- ``CRDT/LWWRegister/init(_:actorID:timestamp:)``

### Inspecting or Updating the Register

- ``CRDT/LWWRegister/value``

### Replicating a Register

- ``CRDT/LWWRegister/merged(with:)``

### Delta-based Replicating

- ``CRDT/LWWRegister/state``
- ``CRDT/LWWRegister/delta(_:)``
- ``CRDT/LWWRegister/mergeDelta(_:)``
- ``CRDT/LWWRegister/Atom``

### Decoding a Register

- ``CRDT/LWWRegister/init(from:)``

### Debugging and Optimization Methods

- ``CRDT/LWWRegister/sizeInBytes()``
