
# ``CRDT/List/Metadata``

## Topics

### Creating List Metadata

- ``CRDT/List/Metadata/init(id:anchor:value:)``

### Inspecting List Metadata

- ``CRDT/List/Metadata/id-2w9gg``
- ``CRDT/List/Metadata/id-4n3w3``
- ``CRDT/List/Metadata/anchor``
- ``CRDT/List/Metadata/isDeleted``
- ``CRDT/List/Metadata/value``
- ``CRDT/List/Metadata/description``

### Decoding an ORSet State

- ``CRDT/List/Metadata/init(from:)``

### Ordering Metadata into a Causal Tree

- ``CRDT/List/Metadata/ordered(fromUnordered:)``
- ``CRDT/List/Metadata/verifyCausalTreeConsistency(_:)``

### Debugging and Optimization Methods

- ``CRDT/List/Metadata/sizeInBytes()``
