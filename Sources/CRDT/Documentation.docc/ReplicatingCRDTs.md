# Replicating CRDTs

Techniques to replicate instances of CRDTs. 

## Overview

One of the key reasons to choose to use a CRDT is to enable seamless, asynchronous collaboration.
To replicate and synchronize between instances of CRDT types, there are two patterns.
The first is the simplest; replicate all of the data within the type to the remote site and then merge.

The second is more complex, trading off multiple steps for potentially less data transfer required to synchronize.
The steps of second technique:

1. Export and share the state of your CRDT instance
2. On the remote instance, generate a delta from the state of the first instance, and send that back.
3. On the original instance, merge the provided delta to bring it up to sync with the remote instance.

### Full State Transfer

The simplest technique for synchronization is to serialize out the entirety of the current data structure, move it to another instance, deserialize it, and merge it.
This is the same mechanism you could use to store the data from a CRDT instance onto disk, to be read later.

The CRDT library is intentionally generic over the identifier for collaborators, `ActorID` within the types.
If the type you choose to use for ActorID conforms to the `Codable` protocol, the whole CRDT instance also conforms.
For example, you could create a `LWWRegister` of a String, and use String as the ActorID type:

```swift
let register = LWWRegister("Hello", actorID: UUID().uuidString)
```

This example uses `.uuidString` instead of a UUID directly because the ActorID also needs to be comparable.
If you want to use UUID directly, you can alternatively provide your own Comparable conformance in an extension:

```swift
extension UUID: Comparable {
    public static func < (lhs: UUID, rhs: UUID) -> Bool {
        return lhs.uuidString < rhs.uuidString
    }
}

let register = LWWRegister("Hello", actorID: UUID())
let data = try JSONEncoder().encode(register)
print(String(decoding: data, as: UTF8.self))
```

The above snippet generates something akin to the following JSON:
```json
{
    "selfId": "89A9244B-2577-484E-9151-0830C8662BD6",
    "_storage": {
        "value": "Hello",
        "clockId": {
            "clock": 683694177.84892404,
            "actorId": "89A9244B-2577-484E-9151-0830C8662BD6"
         }
    }
}
```

The CRDT library intentionally doesn't provide transport mechanisms, so you can move the data as best fits your scenario.
Once the data is moved, decode it:

```swift
let regenerated = try JSONDecoder().decode(LWWRegister<UUID, String>.self, from: data)
```

And merge potentially merge it into another instance using the ``CRDT/LWWRegister/merged(with:)`` method:
```swift
let updated = register.merged(with: regenerated)
```

Or the ``CRDT/LWWRegister/merging(with:)`` method if you want to update a variable directly instead of creating a new, merged instance:

```swift
remoteRegister.merging(with: regenerated)
```

The downside of this technique is that it requires replicating all of the instance of the CRDT for every merge.
The CRDT instances in this library also provide a means to only transfer the state that has changed, which we look at in the next section.

### Delta-state Replication

The protocol ``CRDT/DeltaCRDT`` provides the required interface methods, which track to the multistep process:

Step | Method
---- | ----
Export and share the state of your CRDT instance | ``CRDT/DeltaCRDT/state`` 
Generate a delta from the state of the first instance, and send that back. | ``CRDT/DeltaCRDT/delta(_:)``
Merge the provided delta to bring it up to sync with the remote instance. | ``CRDT/DeltaCRDT/mergeDelta(_:)`` or ``CRDT/DeltaCRDT/mergingDelta(_:)`` 

Just as with the whole instance encoding, the types returned from the `state` property conform to `Codable` when `ActorID` (and the value of the type) conform to `Codable`.
In simpler CRDT types, such as ``GCounter``, ``PNCounter``, or ``GSet``, there is no appreciable difference in the size of the serialized `state` as compared to serializing the whole instance.
However, when you use ``LWWRegister``, ``ORSet``, ``ORMap``, or ``List`` there can be a notable difference, as the state doesn't need to include the values stored within the instance.
You can see the difference in the following code snippet:
```swift
let data = try JSONEncoder().encode(register.state)
print(String(decoding: data, as: UTF8.self))
```

The above snippet generates something akin to the following JSON:
```json
{
    "clockId": {
        "clock": 683695946.55028403,
        "actorId": "C98A69EE-59C5-4739-8395-988B37D8B48B"
    }
}
```

Decode the state, and use that with another instance to generate a delta to transfer back.
Then, if the delta isn't `nil`, merge it to synchronize changes:

```swift
let regeneratedState = try JSONDecoder().decode(LWWRegister<UUID, String>.DeltaState.self, from: data)
if let delta = register.delta(regeneratedState) {
    let updated = register.mergeDelta(delta)
}
```

You can also get the entirety of the state of a CRDT instance by passing `nil` as the state into the `delta` method:

```swift
let fullDelta = register.delta(nil)
```
