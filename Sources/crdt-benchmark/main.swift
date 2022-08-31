import CollectionsBenchmark
import CRDT

// NOTE(heckj): benchmark implementations can be a bit hard to understand from the opaque inputs and structure of the code.
// It's worthwhile to look at existing benchmarks that Karoy created for swift-collections:
// - https://github.com/apple/swift-collections/blob/main/Benchmarks/Benchmarks/SetBenchmarks.swift
// - https://github.com/apple/swift-collections/blob/main/Benchmarks/Benchmarks/OrderedSetBenchmarks.swift
// - https://github.com/apple/swift-collections/blob/main/Benchmarks/Benchmarks/DictionaryBenchmarks.swift
//
// Implementation detail for the benchmarks. When they're running, each run has a "size" associated
// with it, and that flows to the inputs that the task provides to your closure. There are 4 different default
// 'input generators' registered and immediately available:
//
// Int.self
// [Int].self
// ([Int], [Int]).self
// Insertions.self
//
// These result an array of length 'size' with integers, in shuffled order. The last one is a set of array of random
// numbers where each number is within the range 0...i where i is the index of the element order. It's useful for
// testing random insertions.

var benchmark = Benchmark(title: "CRDT")

benchmark.addSimple(
    title: "GSet<String,Int> insert",
    input: [Int].self
) { input in
    var set = GSet<String, Int>(actorId: "A")
    for i in input {
        set.insert(i)
    }
    precondition(set.count == input.count)
    blackHole(set)
}

benchmark.addSimple(
    title: "ORSet<String,Int> insert",
    input: [Int].self
) { input in
    var set = ORSet<String, Int>(actorId: "A")
    for i in input {
        set.insert(i)
    }
    precondition(set.count == input.count)
    blackHole(set)
}

benchmark.add(
    title: "ORSet<String,Int> remove",
    input: ([Int], [Int]).self
) { input, removals in
    { timer in
        var set = ORSet<String, Int>(actorId: "A", input)
        timer.measure {
            for i in removals {
                set.remove(i)
            }
        }
        precondition(set.count == 0)
        blackHole(set)
    }
}

benchmark.addSimple(
    title: "ORMap<String,Int,String> insert",
    input: [Int].self
) { input in
    var map = ORMap<String, Int, String>(actorId: "A")
    for i in input {
        map[i] = String(i)
    }
    precondition(map.count == input.count)
    blackHole(map)
}

benchmark.add(
    title: "ORMap<String,Int,String> remove",
    input: ([Int], [Int]).self
) { _, removals in
    { timer in
        var map = ORMap<String, Int, String>(actorId: "A")
        timer.measure {
            for i in removals {
                map[i] = nil
            }
        }
        precondition(map.count == 0)
        blackHole(map)
    }
}

benchmark.addSimple(
    title: "Set insert",
    input: [Int].self
) { input in
    var set = Set<Int>()
    for i in input {
        set.insert(i)
    }
    precondition(set.count == input.count)
    blackHole(set)
}

benchmark.add(
    title: "Set remove",
    input: ([Int], [Int]).self
) { input, removals in
    { timer in
        var set = Set<Int>(input)
        timer.measure {
            for i in removals {
                set.remove(i)
            }
        }
        precondition(set.count == 0)
        blackHole(set)
    }
}

benchmark.addSimple(
    title: "Map insert",
    input: [Int].self
) { input in
    var map = [Int: String]()
    for i in input {
        map[i] = String(i)
    }
    precondition(map.count == input.count)
    blackHole(map)
}

benchmark.add(
    title: "Map remove",
    input: ([Int], [Int]).self
) { input, removals in
    { timer in
        var map = [Int: String]()
        for i in input {
            map[i] = String(i)
        }
        timer.measure {
            for i in removals {
                map[i] = nil
            }
        }
        precondition(map.count == 0)
        blackHole(map)
    }
}

benchmark.registerInputGenerator(for: (Benchmark.Insertions, Benchmark.Insertions).self) { size in
    (Benchmark.Insertions(count: size), Benchmark.Insertions(count: size))
}

benchmark.add(
    title: "ORSet<String,Int> merging random",
    input: (Benchmark.Insertions, Benchmark.Insertions).self
) { input1, input2 in
    { timer in
        var setA = ORSet<String, Int>(actorId: "A", input1.values)
        let setB = ORSet<String, Int>(actorId: "B", input2.values)
        timer.measure {
            setA.merging(with: setB)
        }
        blackHole(setA)
        blackHole(setB)
    }
}

benchmark.add(
    title: "ORSet<String,Int> merged random",
    input: (Benchmark.Insertions, Benchmark.Insertions).self
) { input1, input2 in
    { timer in
        let setA = ORSet<String, Int>(actorId: "A", input1.values)
        let setB = ORSet<String, Int>(actorId: "B", input2.values)
        timer.measure {
            let x = setA.merged(with: setB)
            blackHole(x)
        }
        blackHole(setA)
        blackHole(setB)
    }
}

benchmark.add(
    title: "ORSet<String,Int> delta merged random",
    input: (Benchmark.Insertions, Benchmark.Insertions).self
) { input1, input2 in
    { timer in
        let setA = ORSet<String, Int>(actorId: "A", input1.values)
        let setB = ORSet<String, Int>(actorId: "B", input2.values)

        timer.measure {
            let diff = setA.delta(setB.state)
            do {
                let x = try setB.mergeDelta(diff)
                blackHole(x)
            } catch {}
        }
        blackHole(setA)
        blackHole(setB)
    }
}

benchmark.addSimple(
    title: "List append",
    input: [Int].self
) { input in
    var list = List<String, Int>(actorId: "a")
    for i in input {
        list.append(i)
    }
    precondition(list.count == input.count)
    blackHole(list)
}

benchmark.addSimple(
    title: "List insertion",
    input: Benchmark.Insertions.self
) { input in
    var list = List<String, Int>(actorId: "a")
    for i in input.values {
        list.insert(i, at: i)
    }
    precondition(list.count == input.values.count)
    blackHole(list)
}

// Execute the benchmark tool with the above definitions.
benchmark.main()
