# Sync

Synchronizing data is fundamentally at the heart of all the use cases for CRDT.
That said, there's a lot of different scenarios, each of which comes with its own challenges to maintain the constraints expected by a CRDT.

The key constraint:

> Every separate collaborating instance needs to have it's own identity for any changes represented with in the CRDT.
> If you fail to do this, the CRDT _can_ potentially still merge deterministically, but the results may be brutally wrong from what an end-user would _expect_.

Different use-case scenarios for what you're syncing, and how you're interacting with the underlying data may lead to different ways to handle this.

Use Cases:

CRDT stored to a persistent file, and shared intermittently and asynchronously.
: The file in question can be copied, and updates happen in any order, with a desire to be able to later synchronize.

Ephemeral CRDT to support collaborative efforts across a live network connection.
: CRDT data structures are (relatively) short-lived, with the end results being stored independently. No long-term synchronization and updates are expected.
