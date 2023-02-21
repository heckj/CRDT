# ExternalBenchmarks

Additional CRDT benchmarks that utilize https://github.com/ordo-one/package-benchmark.

This code is explicitly in a subdirectory with a local reference to CRDT in order
to preserve the backwards compatibility of the CRDT package itself, where this
benchmark library requires macOS 13 (or Linux).

To run the benchmarks, invoke:

    swift package benchmark
