---
title: "A gentlemans guide to self-hosting"
date: 2021-02-21T19:24:17Z
tags: ["sds", "self-hosting"]
---

I'm looking to self host more and more of my infrastructure, this comes with the
old question of hardware maintenance and service failover; an often forgotten
question around deployment reproducibility (aka the cattle vs pets argument).
Finally a more nuanced question also arised around security, process and data
isolation.

<!--more-->

## What do you plan to self host on?

Before we start talking about k8s like the hammer for every ~problem~ nail in
sight, lets first consider what are we actually going to self host, and what are
we looking to self host on. To make this process easier to follow, and because
this is ultimately meant to be an engineering-log format blog, I will talk
through my _own_ adventure in re-self-hosting.

### Services

A pretty good driving force for building up your datacenter-in-a-closet is
deciding on what _right now_ you plan to self host (we can consider future
expansion afterwards), and what sort of [SLAs](https://kubernetes.io/) you wish
to meet (if any).

Here is my list:

1. CalDAV host (contacts& calendar syncing).
1. Git repository (SSH).
1. XMPP node.
1. Email system *without* a web frontend.
1. Taskwarrior backend.
1. This blog.

I know I want to add more things in the future, but these services I already
either self host or have running in someone else's computer ("the cloud").

XMPP and Email will probably need pretty decent SLA's, though I use to self host
email on a MkI RaspberryPI (when they first came out) and a USB HDD RAID array.
I use to have to compile my own rpi kernel back in the day just to get the raid
array + LXC to work... So ultimately I might be rather laissez-faire about my
SLA's.

I'm willing to accept up to 3 days of downtime for email, maybe 1 day for XMPP
and 1 week for everything else.. Per month. 👌 :cowboypepe: I do however
plan to migrate my friends to XMPP; they probably will not appreciate a day of
downtime.

### Security

For me its fairly simple:

1. The compromise of any one service should not give an attacker access to
   any other.
2. The compromise of any service should not compromise my personal home
   network.
3. If any hosted service needs to talk to another, it has to do so in the
   same way as I would outside the network (network isolation).

### Hardware

Considering my SLA's we can start thinking about our hardware choices, the
reason to do things in this order is because it makes us think about our data
redundancy and backup strategy ;)

The first question to ask is homogeneous or heterogeneous?
     I want to support hetrogenous hardware, because I'm cheap and this lets me
     both aquire (whatever is cheap) and well have a lower power bill, less
     noise (inaudiable actually, is a requirement for me).

Next question is around contingency of data.

1. Some services can technically survive data loss:
    - Git is meant to be a distributed system, I have repositories cloned on
    multiple machines.
    - Ditto my taskwarrior setup (also.. it doesnt contain anything that I
    wouldn't mind loosing tomorrow (unlike my git repos)).
    - This blog is static pages from a git repo.
2. I do not want to suffer data loss due to drive failure. I also do not
   want drive failure to impact service availability.
    - This all means RAID.
3. Some services cannot survive data loss:
    - CalDAV and Email, though I have copies of data on various system, I
      would rather not loose data from either.
    - Probably the same for XMPP, but :cowboypepe:

### Hardware architecture

You probably have already arrived at this answer, but it's a good exercise to
get to this point after actually writing answers down to the questions above - I
had a very different idea in my mind before I started writing this post.

1. Main work nodes need to run RAID arrays - if one drive fails, I do not want
   this to lead to immediate downtime.
2. Backups, backups, backups:
    - Local hot snapshots.
    - Local cold snapshots (aka backup to removable media).
    - Remote periodic snapshots/backups.
    - All backups must be encrypted at rest and in transit (for remote backups).
    - Local hot and remote backups should be automatic (I wont remember to do
      them on time).
3. All nodes should sit on UPS's
4. I will need multiple worker nodes to host services - I will ultimately need
   to take machines offline to replace dead drives, or motherboards ( ͡° ͜ʖ ͡°)

## Cluster options

You already knew it was going to go here. I need (reasonably) High Availability
for multiple workloads. There are existing options in this market, lets have a
maybe quick brush over some of these (some not so quick, since they are de facto
industry standards that I (and you ( ͡° ͜ʖ ͡°)) work with every day).

### The hammer: K8S

Kubernetes has basically won this war, at least in industry, and its the
de-facto standard for deploying microservices.

**Advantages:**

1. Containarised deployment provides security in process isolation.
1. Process resource limitation - processes using more resources than
   specified get restarted, this can be advantages from a HA and security
   perspecive, as you avoid hardware lockups.
1. Centralised deployment configuration, as code; YAML, YAML everywhere as
   you define what your cluster looks like in one place. SDN and all...
1. Software defined network topologies - good from a security perspective
   for isolation.
1. Industry standard; when in Rome. Pods run docker images, you can use
   existing stuff.

**Disadvantages:**

1. Complex to deploy and manage. Really.
1. Microservice orientated - this is good if you want to denormalise your
   software architecture, but what if you want to run
   postfix+dovecot+spamd+dkim+...... together? You can shove all that in a
   Docker image and make a mega pod, but k8s will supervise the health of
   that pod as a whole, not of each process.
1. Linux only - furthermore you probably will have to run a SysD distro, I
   plan to run this on *BSD.

### Tesco's own brand: Openshift

**Advantages:**

1. You basically run RHE k8s.

**Disadvantages:**

1. You basically run RHE k8s.

Jokes aside, we are evaluating this at work. I may write more here.

### Mesos

I really misunderstood this for a while, until I actually spent time looking at
it. I think it will be possible to wrangle Mesos into managing a cluster like
this, but thats not really what its for.

### Diet Kubernetes: K3S

Basically k8s after spending time in the gym wrapped in cling film, presumably
the sweat has had a shrink wrapping effect and all the bloat has been packaged
in a single binary.

**Advantages:**

1. Single binary makes deployment easy
1. ARM optimised, I can run RPI nodes (heterogeneous hardware is important for
   me, also frankly I won't need more compute power than a few RPI's).

**Disadvantages:**

1. You're still managing a k8s stack

### My mustache brings all the gentlemen to the barbers: Openstack

Actually, this is going one level up - you use this to build a cloud onto which
you deploy k8s et al. If kubernetes is a hammer, then this is a mallet and I'm
not sure my body is ready to deploy this beast.

### Sandstorm

I found this one much later, its a _very, very_ interesting architecture and I
think it might actually be worth trying out. Instead of denormalising your
software architecture into horizontally scaling deployments of individual
service components (aka microservices); you divide your setup into pods based on
_data access policies_. I think they use a fancier word to describe this, but
basically instead of podding individual services, you pod user data. Thus you
would have one pod for an email stack, for one user.

In sandstorm parlance these pods are called grains, and you would thus have one
grain per user per service. If I had 10x email users, I would have 10x grains,
each one containing its own comprehensive email system.

This is a _massive_ security gain, but I have only just found out about it and
this post is actually being written post-factum.

### NIHS: roll your own 👌

**Advantages:**

1. Does whatever you want, how you want it.

**Disadvantages:**

1. Probably doesnt work.

## What's in a cluster anyway

I could also just run up a bunch of nodes and provision them with ansible (or
some other fancier tool). This will probably give me 80% of the value with 20%
of the required effort. Especially if I provision services to run in [Jails](http://docs.freebsd.org/en/books/handbook/jails/).
This would give me process isolation, but still allow some processes to talk to
each other (e.g. if I ran postfix+dovecot in the Linux world (I'm going to have
to reevaluate this setup if I move it to BSD)); I would also get network
isolation with jails. Having the jails backed by ZFS gives me encrypted atomic
snapshots, and its easy enough to schedule remote snapshots using something as
simple as SSH + crontab.

The _only_ things I would miss, is automatic workload migration when
de-provisioning a server - I would have to run ansible manually; though
technically deprovisioning a k8s node still requires manual interaction to taint
& drain it.

I also would not get the safety of automatic hardware failover - in other words,
pod migration if one node dies. But have a look at my SLA times again. They're
pretty lax; lax enough that as long as I have decent data availability, I could
simply spin up the dead jails in a new node by taking the last known snapshot
from my local hot/online backups.

But if you think about it really hard, some might even say too hard , you could
automate this. You could then build a simple distributed system which would
automatically migrate jails by way of ZFS snapshots between nodes. It could even
suggest the specific node that a jail (or LXC container, I should say at this
point) should live in, based on resource usage. It could also allocate drive
resources automatically for you to provision a new jail, based on node resource
usage.

Such a system could even ensure realtime data redundancy amongst nodes for rapid
failover in the event of a node failure.

For such a system, the operator would need little more than his ansible
playbooks to provision individual services; the additional configuration would
be around failover polices and node groups for some form of pseudo availability
zones (or real availability zones, if one is a particularly financially
well-endowed gentlemen).

## Crysalis

Having these ideas in mind, I decided to make such a System for Cluster Resource
Allocation and Provisioning.

Or simply: SCRAP.

It does exactly what it sounds like  ͡° ͜ʖ ͡ –

## TL;DR

As a sort of epilogue, I would like to give a TL;DR summary of the content
above, and discuss the reason for this post:

### I want to get my feet wet, where do I start?

You probably already know of a few curated awesome-xxxx lists well, there is one
for self hosted software and deployment configurations: https://github.com/awesome-selfhosted/awesome-selfhosted

1. Use that as your guide for _what_ part of your digital life you want to self-host.
1. Understand that self-hosting doesn't mean own hardware. You can still run this
   in someone else's computer (DO/AWS/etc).

If you are ready for the own hardware adventure:

1. Make a list of exactly what you have _today_ that you will need to run. There
   can always be more tomorrow, but first consider what you are willing to port
   right now. And focus on porting, not standing up a new service; as this
   removes one unknown.
1. Consider your SLAs, this will influence the kind of hardware you need (UPS's,
   RAID, mobile broadband for failover, etc).
1. Consider your security model, if only a little.
1. Based on SLAs considerations, decide if you want managed deployments.
1. Based on your desired SLAs and security models, consider if you want
   virtualised deployments.
1. The outcomes of the last two points are your decision of whether or not to
   essentially run a private cloud.
1. Get your feet wet and run a single node! :))

### Why I'm making SCRAP

I hope that eventually SDS/SCRAP will become a simple and lightweight system for
managing containarised deployments, giving you the benefit of a private cloud
with something like k3s but without forcing you to denormalise your deployments.

( ✧≖ ͜ʖ≖)
