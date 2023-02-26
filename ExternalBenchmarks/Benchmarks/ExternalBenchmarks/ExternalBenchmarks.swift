import BenchmarkSupport // imports supporting infrastructure for running the benchmarks
import Foundation
import ExtrasJSON
import CRDT

@main extension BenchmarkRunner {} // Required for the main() definition to no get linker errors

enum TextOp {
    case insert(cursor: UInt32, value: String)
    case delete(cursor: UInt32, count: UInt32)
}

func loadEditingTrace () async  -> Data {
    guard let traceURL = Bundle.module.url(forResource: "editing-trace", withExtension: "json") else {
        fatalError("Unable to find editing-trace.json in bundle")
    }
    let data: Data
    do {
        data = try Data(contentsOf: traceURL, options: .mappedIfSafe)
    } catch {
        fatalError("failed load JSON data from editing-trace.json URL")
    }
    // print("[TESTING DEBUG OUTPUT] bytes loaded: \(data.count)")
    return data
}

func parseDataIntoJSON(data: Data) async -> JSONValue {
    do {
        return try ExtrasJSON.JSONParser().parse(bytes: data)
    } catch {
        fatalError("failed parse JSON")
    }
}

func parseJSONIntoTrace(topOfTrace: JSONValue) async -> [TextOp] {
    // var insert = 0
    // var delete = 0
    var trace:[TextOp] = []

    switch topOfTrace {
    case let .array(opsJSONValues):
        // print("Identified \(opsJSONValues.count)")
        for opsJSONValue in opsJSONValues {
            if case let .array(internalOpValues) = opsJSONValue {
                let cursorPos: UInt32
                if case let .number(cursorString) = internalOpValues[0] {
                    cursorPos = UInt32(cursorString)!
                } else {
                    fatalError("Invalid cursor position")
                }
                if case let .number(opString) = internalOpValues[1] {
                    if opString == "0" {
                        // insert += 1
                        if case let .string(foundInsertString) = internalOpValues[2] {
                            trace.append(TextOp.insert(cursor: cursorPos, value: foundInsertString))
                        }
                    }
                    if opString == "1" {
                        // delete += 1
                        trace.append(TextOp.delete(cursor: cursorPos, count: 1))
                    }
                }
            }
        }
    default:
        // print("WTF? Incorrect thing found.")
        fatalError("Top value of JSON wasn't an array.")
    }
    // print("[TESTING DEBUG OUTPUT] - \(insert) inserts, \(delete) deletes")
    // print("Created trace with \(trace.count) elements")
    return trace
}

@_dynamicReplacement(for: registerBenchmarks) // And this is how we register our benchmarks
func benchmarks() {
    // Benchmark.defaultConfiguration.timeUnits = .microseconds
    Benchmark.defaultConfiguration.desiredIterations = .count(1)
    Benchmark.defaultConfiguration.desiredDuration = .seconds(3)

    Benchmark("Loading JSON trace data",
              configuration: .init(metrics: [.throughput, .wallClock], desiredIterations: 20)) { benchmark in
        for _ in benchmark.throughputIterations {
            blackHole(await loadEditingTrace())
        }
    }

    Benchmark("parse JSON with Swift Extras parser",
              configuration: .init(metrics: [.throughput, .wallClock], desiredIterations: 50)) { benchmark in
        for _ in benchmark.throughputIterations {
            let data = await loadEditingTrace()
            benchmark.startMeasurement()
            blackHole(await parseDataIntoJSON(data: data))
            benchmark.stopMeasurement()
        }
    }

    Benchmark("process JSON into trace data",
              configuration: .init(metrics: [.throughput, .wallClock], desiredIterations: 30)) { benchmark in
        for _ in benchmark.throughputIterations {
            let data = await loadEditingTrace()
            let jsonValue = await parseDataIntoJSON(data: data)
            benchmark.startMeasurement()
            blackHole(await parseJSONIntoTrace(topOfTrace: jsonValue))
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
