import BenchmarkSupport // imports supporting infrastructure for running the benchmarks
import Foundation
import ExtrasJSON
import CRDT

@main extension BenchmarkRunner {} // Required for the main() definition to no get linker errors

// https://www.donnywals.com/splitting-a-json-object-into-an-enum-and-an-associated-object-with-codable/

struct EditingTrace: Decodable {
    let operations: [RawOp]
}
struct RawOp: Decodable {
    // [0, 0, "\\"],
    let column: UInt32
    let opType: UInt32
    let value: String
}

enum TextOp {
    case insert(UInt32, String)
    case delete(UInt32, UInt32)
}


func loadEditingTrace () async {
    guard let traceURL = Bundle.module.url(forResource: "editing-trace", withExtension: "json") else {
        fatalError("Unable to find editing-trace.json in bundle")
    }
    let data: Data
    do {
        data = try Data(contentsOf: traceURL, options: .mappedIfSafe)
    } catch {
        fatalError("failed load JSON data from editing-trace.json URL")
    }
    print("[TESTING DEBUG OUTPUT] bytes loaded: \(data.count)")
    
    do {
        let topValue = try ExtrasJSON.JSONParser().parse(bytes: data)
        switch topValue {
        case let .array(opsJSONValues):
            print("Identified \(opsJSONValues.count)")
        default:
            print("WTF? Incorrect thing found.")
        }
    } catch {
        fatalError("failed parse JSON")
    }
}

@_dynamicReplacement(for: registerBenchmarks) // And this is how we register our benchmarks
func benchmarks() {
    Benchmark.defaultConfiguration.timeUnits = .microseconds
    Benchmark.defaultConfiguration.desiredIterations = .count(1)
//    Benchmark.defaultConfiguration.desiredDuration = .seconds(1)

    Benchmark("Process Editing Trace",
              configuration: .init(metrics: [.throughput, .wallClock])) { benchmark in
        for _ in benchmark.throughputIterations {
            await loadEditingTrace()
            var mylist = List<String, String>(actorId: "mk")
            benchmark.startMeasurement()
            mylist.append(" hello")
            benchmark.stopMeasurement()
        }
    }

    Benchmark("Create single-character List CRDT",
              configuration: .init(metrics: BenchmarkMetric.all, throughputScalingFactor: .kilo)) { benchmark in
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
