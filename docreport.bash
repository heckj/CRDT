#!/bin/bash

set -e  # exit on a non-zero return code from a command
set -x  # print a trace of commands as they execute

rm -rf .build .crdt-graphs
mkdir -p .crdt-graphs

$(xcrun --find swift) build --target CRDT \
    -Xswiftc -emit-symbol-graph \
    -Xswiftc -emit-symbol-graph-dir -Xswiftc .crdt-graphs

$(xcrun --find docc) convert Sources/CRDT/Documentation.docc \
    --analyze \
    --fallback-display-name CRDT \
    --fallback-bundle-identifier com.github.heckj.CRDT \
    --fallback-bundle-version 0.1.9 \
    --additional-symbol-graph-dir .crdt-graphs \
    --experimental-documentation-coverage \
    --level brief
