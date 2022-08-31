#!/bin/bash

set -e  # exit on a non-zero return code from a command
set -x  # print a trace of commands as they execute

swift run -c release crdt-benchmark \
    library run Benchmarks/results.json \
    --library Benchmarks/Library.json \
    --cycles 5 \
    --mode replace-all
    
swift run -c release crdt-benchmark \
    library render Benchmarks/results.json \
    --library Benchmarks/Library.json \
    --output Benchmarks
