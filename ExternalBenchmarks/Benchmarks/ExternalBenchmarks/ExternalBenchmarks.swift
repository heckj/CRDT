import BenchmarkSupport // imports supporting infrastructure for running the benchmarks
import Foundation
import ExtrasJSON
import CRDT

@main extension BenchmarkRunner {} // Required for the main() definition to no get linker errors

/*
 
Interesting comparison benchmark for parsing the JSON, turns out that hand-parsing is a
LOT faster than even ExtrasJSON Decodable conformance implementations. ExtrasJSON is still
notably faster than Foundation, but the hand-parse optimization was surprising to me.
 
 Throughput (scaled / s)
 ╒════════════════════════════════════╤═════╤═════╤═════╤═════╤═════╤═════╤══════╤═════════╕
 │ Test                               │  p0 │ p25 │ p50 │ p75 │ p90 │ p99 │ p100 │ Samples │
 ╞════════════════════════════════════╪═════╪═════╪═════╪═════╪═════╪═════╪══════╪═════════╡
 │ Custom parse JSON into trace       │  83 │  77 │  76 │  75 │  74 │  66 │   59 │     300 │
 ├────────────────────────────────────┼─────┼─────┼─────┼─────┼─────┼─────┼──────┼─────────┤
 │ ExtrasJSON decode JSON into trace  │   6 │   6 │   6 │   6 │   6 │   5 │    5 │      29 │
 ├────────────────────────────────────┼─────┼─────┼─────┼─────┼─────┼─────┼──────┼─────────┤
 │ Foundation decode JSON into trace  │   1 │   1 │   1 │   1 │   1 │   1 │    1 │       7 │
 ╘════════════════════════════════════╧═════╧═════╧═════╧═════╧═════╧═════╧══════╧═════════╛

 Time (wall clock)
 ╒════════════════════════════════════════╤═════╤═════╤═════╤═════╤═════╤═════╤══════╤═════════╕
 │ Test                                   │  p0 │ p25 │ p50 │ p75 │ p90 │ p99 │ p100 │ Samples │
 ╞════════════════════════════════════════╪═════╪═════╪═════╪═════╪═════╪═════╪══════╪═════════╡
 │ Custom parse JSON into trace (ms)      │  12 │  13 │  13 │  13 │  13 │  15 │   17 │     300 │
 ├────────────────────────────────────────┼─────┼─────┼─────┼─────┼─────┼─────┼──────┼─────────┤
 │ ExtrasJSON decode JSON into trace (ms) │ 175 │ 177 │ 177 │ 178 │ 180 │ 184 │  184 │      29 │
 ├────────────────────────────────────────┼─────┼─────┼─────┼─────┼─────┼─────┼──────┼─────────┤
 │ Foundation decode JSON into trace (ms) │ 825 │ 825 │ 826 │ 826 │ 827 │ 827 │  827 │       7 │
 ╘════════════════════════════════════════╧═════╧═════╧═════╧═════╧═════╧═════╧══════╧═════════╛
 
 */
enum TextOp {
    case insert(cursor: UInt32, value: String)
    case delete(cursor: UInt32, count: UInt32)
}

typealias Trace = [TextOp]

extension TextOp: Decodable {
    init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        if container.count ?? 0 < 2 {
            throw DecodingError.typeMismatch(
               Self.self,
               .init(codingPath: decoder.codingPath,
                     debugDescription: "Fewer than two elements within array")
            )
        }
        let column = try container.decode(UInt32.self)
        let optype = try container.decode(UInt32.self)
        switch optype {
            case 0:
                let insertedString = try container.decode(String.self)
            self = .insert(cursor: column, value: insertedString)
        case 1: self = .delete(cursor: column, count: 1)
            default: throw DecodingError.typeMismatch(
                Self.self,
                .init(codingPath: decoder.codingPath,
                      debugDescription: "Unknown op type: \(optype)")
                )
        }
    }
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

func decodeIntoTrace(data: Data) async -> Trace {
    let decoder = JSONDecoder()
    do {
        return try decoder.decode(Trace.self, from: data)
    } catch {
        fatalError("failed parse JSON")
    }
}

func decodeXIntoTrace(data: Data) async -> Trace {
    let decoder = XJSONDecoder()
    do {
        return try decoder.decode(Trace.self, from: data)
    } catch {
        fatalError("failed parse JSON")
    }
}

func parseJSONIntoTrace(topOfTrace: JSONValue) async -> Trace {
    var trace:[TextOp] = []

    switch topOfTrace {
    case let .array(opsJSONValues):
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
                        if case let .string(foundInsertString) = internalOpValues[2] {
                            trace.append(TextOp.insert(cursor: cursorPos, value: foundInsertString))
                        }
                    }
                    if opString == "1" {
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
    Benchmark.defaultConfiguration.desiredIterations = .count(300)
    Benchmark.defaultConfiguration.desiredDuration = .seconds(5)

//    Benchmark("Loading JSON trace data",
//              configuration: .init(metrics: [.throughput, .wallClock], desiredIterations: 20)) { benchmark in
//        for _ in benchmark.throughputIterations {
//            blackHole(await loadEditingTrace())
//        }
//    }
//
//    Benchmark("parse JSON with Swift Extras parser",
//              configuration: .init(metrics: [.throughput, .wallClock], desiredIterations: 50)) { benchmark in
//        for _ in benchmark.throughputIterations {
//            let data = await loadEditingTrace()
//            benchmark.startMeasurement()
//            blackHole(await parseDataIntoJSON(data: data))
//            benchmark.stopMeasurement()
//        }
//    }

    Benchmark("Custom parse JSON into trace",
              configuration: .init(metrics: [.throughput, .wallClock])) { benchmark in
        for _ in benchmark.throughputIterations {
            let data = await loadEditingTrace()
            let jsonValue = await parseDataIntoJSON(data: data)
            benchmark.startMeasurement()
            blackHole(await parseJSONIntoTrace(topOfTrace: jsonValue))
            benchmark.stopMeasurement()
        }
    }

    Benchmark("Foundation decode JSON into trace",
              configuration: .init(metrics: [.throughput, .wallClock])) { benchmark in
        for _ in benchmark.throughputIterations {
            let data = await loadEditingTrace()
            benchmark.startMeasurement()
            blackHole(await decodeIntoTrace(data: data))
            benchmark.stopMeasurement()
        }
    }

    Benchmark("ExtrasJSON decode JSON into trace",
              configuration: .init(metrics: [.throughput, .wallClock])) { benchmark in
        for _ in benchmark.throughputIterations {
            let data = await loadEditingTrace()
            benchmark.startMeasurement()
            blackHole(await decodeXIntoTrace(data: data))
            benchmark.stopMeasurement()
        }
    }

//    Benchmark("Create single-character List CRDT",
//              configuration: .init(metrics: BenchmarkMetric.all, throughputScalingFactor: .kilo)) { benchmark in
//        for _ in benchmark.throughputIterations {
//            blackHole(blackHole(List(actorId: "a", ["a"])))
//        }
//    }
//
//    Benchmark("List six-character append",
//              configuration: .init(metrics: [.throughput, .wallClock], throughputScalingFactor: .kilo)) { benchmark in
//        for _ in benchmark.throughputIterations {
//            var mylist = List(actorId: "a", ["a"])
//            benchmark.startMeasurement()
//            mylist.append(" hello")
//            benchmark.stopMeasurement()
//        }
//    }
//
//    Benchmark("List six-character append, individual characters",
//              configuration: .init(metrics: [.throughput, .wallClock], throughputScalingFactor: .kilo)) { benchmark in
//        for _ in benchmark.throughputIterations {
//            var mylist = List(actorId: "a", ["a"])
//            let appendList = [" ", "h", "e", "l", "l", "o"]
//            benchmark.startMeasurement()
//            for val in appendList {
//                mylist.append(val)
//            }
//            benchmark.stopMeasurement()
//        }
//    }

}
