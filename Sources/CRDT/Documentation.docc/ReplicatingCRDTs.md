# Replicating CRDTs

Replicating Summary

## Overview

Replicating

 1. replicate the whole 'type' (serialize it out, unserialize it elsewhere and 'merge' it in)
 2. replicate using a 'diff' has two paths - whole state, or diff using another instances' state
  - get state of first instance, use that with secondInstance.diff(state), and then replicate that diff back to the first.
  - invoke secondInstance.diff(nil) to get the "whole thing" from instance2, move that data back to where instance1 lives, and the merge it instance1.mergeDelta(diff) 
