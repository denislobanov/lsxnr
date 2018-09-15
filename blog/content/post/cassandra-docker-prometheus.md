---
title: "Monitoring Dockerised Cassandra with Prometheus"
date: 2017-11-13T12:15:52Z
tags: ["cassandra", "prometheus", "docker", "devops"]
draft: false
---

As part of the move away from a proprietary in memory database `madb`, [last.fm](https://last.fm) is moving to [Apache Cassandra](https://cassandra.apache.org). Cassandra is far more easier to deploy to a public cloud (in our case GCE), scale up/down and query. `madb`, being completely in memory does have pretty good performance characteristics, but scaling requires machines with more ram, sharding by user and in has some weird and interesting bugs.

<!--more-->
We deploy a dockerised version of Cassandra, but the standard image doesn't support monitoring via [Prometheus](https://prometheus.io/). It's easy to add however - all you need is a JMX java agent, and one for Prometheus [already exists](https://github.com/prometheus/jmx_exporter). Initially our Dockerfile looked something like this:
```Dockerfile
FROM cassandra

ADD "http://central.maven.org/maven2/io/prometheus/jmx/jmx_prometheus_javaagent/0.10/jmx_prometheus_javaagent-0.10.jar" /usr/local/lib/jmx_prometheus_javaagent.jar
ADD prometheus.yaml /usr/local/etc/prometheus.yaml

RUN chmod a+r /usr/local/lib/jmx_prometheus_javaagent.jar
ENV JVM_OPTS "$JVM_OPTS -javaagent:/usr/local/lib/jmx_prometheus_javaagent.jar=61621:/prometheus/cassandra.yml "
```

However trying to run this resulted in a nice stack trace rather than a running Cassandra instance. The root of this stack trace was..

</br>
## java.net.BindException: Address already in use
I first wrote our Dockerfile to use `ENV JVM_OPTS`, however it seems the problem is that if the `jmx_prometheus_javaagent` jar is defined in `JVM_OPTS` for the whole container it gets started before Cassandra. So the solution was a small rewrite, adding the `JVM_OPTS` line to `cassandra-env.sh` instead. Our Dockerfile thus became something like this:  
```Dockerfile
FROM cassandra

ADD "http://central.maven.org/maven2/io/prometheus/jmx/jmx_prometheus_javaagent/0.10/jmx_prometheus_javaagent-0.10.jar" /usr/local/lib/jmx_prometheus_javaagent.jar
ADD prometheus.yaml /usr/local/etc/prometheus.yaml

RUN chmod a+r /usr/local/lib/jmx_prometheus_javaagent.jar
RUN echo 'JVM_OPTS="$JVM_OPTS -javaagent:/usr/local/lib/jmx_prometheus_javaagent.jar=61621:/usr/local/etc/prometheus.yaml"' >> /etc/cassandra/cassandra-env.sh
```

