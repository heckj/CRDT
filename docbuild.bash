#!/bin/bash

echo "Make sure you've rebased over the current HEAD branch:"
echo "git rebase -i origin/main docs"

set -e  # exit on a non-zero return code from a command
set -x  # print a trace of commands as they execute

#rm -rf .build
#mkdir -p .build/symbol-graphs
#
#$(xcrun --find swift) build --target CRDT \
#    -Xswiftc -emit-symbol-graph \
#    -Xswiftc -emit-symbol-graph-dir -Xswiftc .build/symbol-graphs
#

# Enables deterministic output
# - useful when you're committing the results to host on github pages
export DOCC_JSON_PRETTYPRINT=YES

#$(xcrun --find docc) convert Sources/CRDT/Documentation.docc \
#    --output-path ./docs \
#    --fallback-display-name CRDT \
#    --fallback-bundle-identifier com.github.heckj.CRDT \
#    --fallback-bundle-version 0.1.9 \
#    --additional-symbol-graph-dir .build/symbol-graphs \
#    --emit-digest \
#    --transform-for-static-hosting \
#    --hosting-base-path 'CRDT'

# Add the following as a dependency into your Package.swift
#
# // Swift-DocC Plugin - swift 5.6 ONLY (GitHhub Actions on 1/29/2022 only supports to 5.5)
#     dependencies: [
#        .package(url: "https://github.com/apple/swift-docc-plugin", branch: "main"),
#    ],
# run:
#   $(xcrun --find swift) package resolve
#   $(xcrun --find swift) build


# Swift package plugin for hosted content:
#
 $(xcrun --find swift) package \
     --allow-writing-to-directory ./docs \
     generate-documentation \
     --fallback-bundle-identifier com.github.heckj.CRDT \
     --target SwiftVizScale \
     --output-path ./docs \
     --emit-digest \
     --disable-indexing \
     --transform-for-static-hosting \
     --hosting-base-path 'CRDT'

# Generate a list of all the identifiers to assist in DocC curation
#

cat docs/linkable-entities.json | jq '.[].referenceURL' -r > all_identifiers.txt
sort all_identifiers.txt \
    | sed -e 's/doc:\/\/com\.github\.heckj\.CRDT\/documentation\///g' \
    | sed -e 's/^/- ``/g' \
    | sed -e 's/$/``/g' > all_symbols.txt

echo "Page will be available at https://heckj.github.io/CRDT/documentation/CRDT/"
