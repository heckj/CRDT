# CRDT

An implementation of ∂-state based CRDTs (conflict-free replicated data types) in the Swift language.

[![codecov](https://codecov.io/gh/heckj/CRDT/branch/main/graph/badge.svg?token=AP68RBHNHM)](https://codecov.io/gh/heckj/CRDT)

[![code coverage chart](https://codecov.io/gh/heckj/CRDT/branch/main/graphs/sunburst.svg?token=AP68RBHNHM)](https://codecov.io/gh/heckj/CRDT)

This library implements well-known state-based CRDTs as swift generics, and supplies a replicator to support using CRDTs in your own data models.

- [x] G-Counter (grow-only counter)
- [x] PN-Counter (A positive-negative counter)
- [x] LWW-Register (last write wins register)
- [X] G-Set (grow-only set)
- [X] OR-Set (observed-remove set, with LWW add bias)
- [ ] OR-Map (observed-remove map, with LWW add or update bias)
- [ ] Replicator

For more, general, information on CRDTs, see the following sites and papers:
- [CRDT.tech website](https://crdt.tech)
- [Wikipedia's page on CRDTs](https://en.wikipedia.org/wiki/Conflict-free_replicated_data_type)
- Two academic papers with implementation details:
  - “[Conflict-free Replicated Data Types](https://arxiv.org/pdf/1805.06358.pdf)” by Nuno Preguiça, Carlos Baquero, and Marc Shapiro (2018)
  - “[A comprehensive study of Convergent and Commutative Replicated Data Types](https://hal.inria.fr/inria-00555588/document)” by Marc Shapiro, Nuno Preguiça, Carlos Baquero, and Marek Zawirski (2011).

Two very well established CRDT libraries used for collaborative text editing:
- [Automerge](https://automerge.org)
  - (video) [CRDTs: The Hard Parts](https://youtu.be/x7drE24geUw) by [Martin Kleppmann](https://martin.kleppmann.com/2020/07/06/crdt-hard-parts-hydra.html))
- [Yjs](https://yjs.dev) (and its multi-language port [Y-CRDT](https://github.com/y-crdt))
  - Yrs data structure internals: https://bartoszsypytkowski.com/yrs-architecture/

Articles discussing tradeoffs, algorithm details, and performance, specifically for sequence based CRDTs:
- https://bartoszsypytkowski.com/yata/
- https://josephg.com/blog/crdts-go-brrr/

Other Swift implementations of CRDTs:
- https://github.com/bluk/CRDT
- https://github.com/appdecentral/replicatingtypes
    - article: https://appdecentral.com/2020/07/12/conflict-free-replicated-data-types-crdts-in-swift/
- https://github.com/jamztang/CRDT
- https://github.com/archagon/crdt-playground
  - article: http://archagon.net/blog/2018/03/24/data-laced-with-history/
- Obj.io's video series: https://talk.objc.io/episodes/S01E294-crdts-introduction
