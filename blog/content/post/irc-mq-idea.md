---
title: "IRC as a service mesh"
date: 2020-08-26T18:02:48+01:00
draft: true
---

## IRC as a service mesh  

This is something that spawned out of a bit of lunchtime trolling of my
colleagues; the sort of trolling thats funny at first but then the further it
went the more we realised it can work.

## ideas  

### synchronous  

* each service PM/DM's each other
* one channel for service discovery, heartbeats (services regularly ping a
  message to say they are still alive)

### asynchronous

* channel services as mq topic
* this is at least once semantics

### exactly once delivery

* claim a message on receipt
* message is unclaimed if you miss a heartbeat
* ack on completion of process

### replays/offset semantics

* playing through whole channel is heavy, consensus offset markings?
* second topic for holds/acks & consensus offsets?
* writes can continue to primary topic

## Event structure

Events contain payloads, ie the meat of the message queue.

```rust
struct Event {
    id: u64,
    state: State,
    // id of last client to change message state
    clientId: u64,
    data: [u8],
}

enum State {
    Published,
    Claimed,
    Consumed,
}

```

## Event ownership and message history  

Before considering semantics of 'claiming' an event, how do we establish message
history? Storage can be handled by the irc server, but replay will require a
bouncer to all clients - otherwise events will be dropped; particularly if all
clients temporarily disconnect.

1. Bouncer to save message history.
1. Each client maintains state of last seen message
1. On reconnect, consumes available message history to establish current offset
   and accepts gaps
1. Alternatively heartbeat consensus offsets - do not accept gaps, periodically
   each client emits what it thinks the offset is, quorum decides (ownership
   topic).

Basic ownership event structure:

```rust
struct OwnershipClaim {
    id: u64,
    eventId: u64,
    clientId: u64,
    state: State,
}

struct OwnershipAcknowledge {
    claimId: u64,
    clientId: u64,
}

struct OwnershipRejection {
    claimId: u64,
    clientId: u64,
}
```

Event history consensus:

```rust
struct HistoryClaim {
    id: u64,
    last: u64,
    clientId: u64
}

struct HistoryAcknowledge {
    claimId: u64,
    clientId: u64,
}

struct HistoryRejection {
    claimId: u64,
    clientId: u64,
}
```

## Time

Timestamps are part of irc messages, so all events would need to be wrapped in
an envelope containing this. Other metadata can be on this envelope too, such as
the clientId.
    - all these events are essentially envelopes
    - maybe just add timestamp to all of them
    - library would re-interprent irc timestamp and add it to struct

## Heartbeats  

```rust
struct Heartbeat {
    clientId: u64,
}
```

## Encoding  

1. minimised json? Simple, but not compact
1. base64 bson
1. other binary base64?
1. payloads are already byte data
1. endieness

## Encryption

Initially none, however could use DH to establish a PSK, OMEO for latching &
PFS?

## Service Management

* Would need to separate nodes & services
* Nodes can listen on separate channels for control messages to scale services
* Service & node heartbeat channel
* How to do resource allocation?

