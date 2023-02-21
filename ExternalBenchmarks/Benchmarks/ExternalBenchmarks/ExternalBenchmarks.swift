import BenchmarkSupport // imports supporting infrastructure for running the benchmarks
import CRDT

@main extension BenchmarkRunner {} // Required for the main() definition to no get linker errors

@_dynamicReplacement(for: registerBenchmarks) // And this is how we register our benchmarks
func benchmarks() {
    Benchmark("List single-character append",
              configuration: .init(metrics: BenchmarkMetric.all, throughputScalingFactor: .mega)) { benchmark in
        for _ in benchmark.throughputIterations {
                    blackHole(List(actorId: "a", ["a"]))
                }
    }
}
