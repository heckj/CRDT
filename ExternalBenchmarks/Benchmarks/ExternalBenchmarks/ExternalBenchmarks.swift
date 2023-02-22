import BenchmarkSupport // imports supporting infrastructure for running the benchmarks
import CRDT

@main extension BenchmarkRunner {} // Required for the main() definition to no get linker errors

@_dynamicReplacement(for: registerBenchmarks) // And this is how we register our benchmarks
func benchmarks() {
    Benchmark.defaultConfiguration.timeUnits = .microseconds
    // Benchmark.defaultConfiguration.desiredIterations = .count(200)
    Benchmark.defaultConfiguration.desiredDuration = .seconds(1)

    Benchmark("Create single-character List CRDT",
              configuration: .init(metrics: [.throughput, .wallClock], throughputScalingFactor: .kilo)) { benchmark in
        for _ in benchmark.throughputIterations {
            blackHole(blackHole(List(actorId: "a", ["a"])))
        }
    }

    Benchmark("List six-character append",
              configuration: .init(metrics: [.throughput, .wallClock], throughputScalingFactor: .kilo)) { benchmark in
        for _ in benchmark.throughputIterations {
            var mylist = List(actorId: "a", ["a"])
            benchmark.startMeasurement()
            mylist.append(" hello")
            benchmark.stopMeasurement()
        }
    }

    Benchmark("List six-character append, individual characters",
              configuration: .init(metrics: [.throughput, .wallClock], throughputScalingFactor: .kilo)) { benchmark in
        for _ in benchmark.throughputIterations {
            var mylist = List(actorId: "a", ["a"])
            let appendList = [" ", "h", "e", "l", "l", "o"]
            benchmark.startMeasurement()
            for val in appendList {
                mylist.append(val)
            }
            benchmark.stopMeasurement()
        }
    }

}
