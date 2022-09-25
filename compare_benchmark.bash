#!/bin/bash

set -e  # exit on a non-zero return code from a command
set -x  # print a trace of commands as they execute

swift run -c release crdt-benchmark \
    library run --library Benchmarks/Library.json \
    --cycles 2 \
    devcheck

swift run -c release crdt-benchmark \
    results compare \
    Benchmarks/results.json devcheck \
    --list-cutoff 1.1

swift run -c release crdt-benchmark \
    results compare \
    Benchmarks/results.json devcheck \
    --output diff.html
