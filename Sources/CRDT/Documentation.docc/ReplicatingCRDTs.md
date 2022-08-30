# Replicating CRDTs

Replicating Summary

## Overview

Costs of CRDTs
 - slower
 - more overhead/memory consumed

Limits and Edges
 - maximum number of interactions before things "blow up" - in this library UInt64.max (18,446,744,073,709,551,615) changes
 - number of potential collaborators (potentially) limited by whatever you choose as a collaborator ID. UInt8 would be 255 collaborators.
 - size of this collaboration count and actorID is stored along with every entry, for example, in an ORMap - which increases the size required to track that element as compared to just a simple map without tracking for consistent replication.

Deterministic doesn't imply magical correctness

 - previously unmerged instances can merge in ways that appear wrong.
 - best scenario to minimize these impacts, start from a replicated copy of an initial instance.

Replicating

 1. replicate the whole 'type' (serialize it out, unserialize it elsewhere and 'merge' it in)
 2. replicate using a 'diff' has two paths - whole state, or diff using another instances' state
  - get state of first instance, use that with secondInstance.diff(state), and then replicate that diff back to the first.
  - invoke secondInstance.diff(nil) to get the "whole thing" from instance2, move that data back to where instance1 lives, and the merge it instance1.mergeDelta(diff) 
