---
title: "Common commands for namespaced projects running in cloud"
date: 2018-04-16T14:22:10Z
tags: ["gcloud", "kubernetes", "common commands"]
draft: true
---

This is nothing new, special or otherwise more than what you can find by just looking over the [Kubernetes Cheat Sheet](https://kubernetes.io/docs/reference/kubectl/cheatsheet/). 

However I tend to use these all the time when working on projects using gcloud and kubernetes (both k8s pods and gcloud vm instances), that use namespaces to segraggate different lifecycle deployments. The most common stuff I can remember (like getting a list of pods :p), but getting kubectl credentials for another project I tend to forget unless I use often :) So I will put them here in order to not have to look through my shell history so often.

#### Select a project and get kubctl creds
```
gcloud config set project i-lastfm-dev

gcloud container clusters list
gcloud container clusters get-credentials dev --zone us-central1-a --project i-lastfm-dev
```

#### Find an instance to ssh to  
```
gcloud compute instances list
gcloud compute ssh my-instance --project my-project
```

#### Create template  
```
gcloud compute instance-templates create cassandra  --machine-type n1-standard-2 --local-ssd interface=nvme --local-ssd interface=nvme --image-project ubuntu-os-cloud --image-family ubuntu-1604-lts --boot-disk-size=20GB --metadata startup-script-url=gs://my-provisioning-bucket/cassandra/provision.sh --project my-project
```

#### Create instance group & add instances
Aggregate monitoring of instances in gcloud console.
```
gcloud compute instance-groups unmanaged create my-cassandra --description 'Such Cassandra cluster. Wow' --zone us-central1-a
gcloud compute instance-groups unmanaged add-instances my-cassandra --instances my-cassandra-01
```

#### Submit a dataproc job
```
# thing.jar params: 0 1 2 3 
gcloud dataproc jobs submit spark --region=us-central1 --cluster my-cluster --class com.lsxnr.example.Thing --jars target/scala-2.11/thing.jar -- 0 1 2 3
```

#### Delete a cluster
```
yes | gcloud dataproc clusters delete my-cluster --region=us-central1
```

#### Compute job progress
```
gcloud compute ssh --zone-us-central1 --sh-flag="-D 1080" --ssh-flag="-N" --ssh-flag="-n" cluster-11ea-m
```

#### Copy things to bucket
```
gsutil cp provision.sh gs://my-bucket/cassandra/provision.sh
```

<br/><br/>
Probably will keep updating this list..
