# ``CRDT``

Seamlessly, consistently, and asynchronously replicate data. 

## Overview

Conflict-free Replicated Data Types (CRDT) are data structures that support conflict-free replication algorithms.
To enable this functionality, CRDT types internally manage history and state relevant to the type of data structure.

The implementations in this library are state-based CRDTs (written as `CvRDT` in research papers), represented by conformance to the ``CRDT/Replicable`` protocol.
Types that conform to the ``CRDT/DeltaCRDT`` protocol, provide the implementation for ∂-state based CRDTs, which optimizes the data transfer needed to replicate between the types.
The data types supported in this package are optimized versions of well known CRDT data types and algorithms, including:

CRDT Type | Description
--- | ---
``CRDT/GCounter`` | A grow-only counter.
``CRDT/PNCounter`` | A PN-Counter that both increments and decrements.
``CRDT/LWWRegister`` | A Last Write Wins register.
``CRDT/GSet`` | A grow-only set.
``CRDT/ORSet`` | An Observed-Removed set
``CRDT/ORMap`` | An Observed-Removed map

For more information on CRDTs and the algorithms behind them, see the [CRDT.tech website](https://crdt.tech), or
[Wikipedia's page on CRDTs](https://en.wikipedia.org/wiki/Conflict-free_replicated_data_type).

## Topics

### Counters

- ``CRDT/GCounter``
- ``CRDT/PNCounter``

### Registers

- ``CRDT/LWWRegister``

### Sets

- ``CRDT/GSet``
- ``CRDT/ORSet``

### Maps

- ``CRDT/ORMap``

### Timestamps

- ``CRDT/LamportTimestamp``
- ``CRDT/WallclockTimestamp``

### Replication Protocols

- ``CRDT/Replicable``
- ``CRDT/PartiallyOrderable``
- ``CRDT/DeltaCRDT``
- ``CRDT/CRDTMergeError``

### Debugging and Optimization Protocols

- ``CRDT/ApproxSizeable``
