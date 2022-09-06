# Falco Pod Specifications

This directory contains example pod specifications to deploy the patterns
discussed in the [container images](/../../tree/main/containerimages/) directory on to Amazon
EKS for AWS Fargate.

## Prerequisites

1. An Amazon EKS Cluster already exists with a [Fargate
   Profile](https://docs.aws.amazon.com/eks/latest/userguide/fargate.html)
   created for the Kubernetes Namespace you plan to deploy these Pods in to.
2. The Container Images have been built and pushed to Amazon ECR.

## Deployment

### Embedded Binaries

Here we will run 1 Container in 1 Kubernetes Pod. The container will contain
both the workload (instrumented with `pdig`) and the Falco Daemon, both
controlled by the supervisord process manager.

> Ensure to update the container image name in the pod specification with your
> container image URI.

```bash
# Deploy the Falco Configuration file
kubectl apply -f falco.yaml

# Deploy the Local Falco Rules File
kubectl apply -f falco-local-rules.yaml

# Deploy the Pod
kubectl apply -f embeddedbinary.yaml
```

You can monitor the workload with

```bash
kubectl logs -f embeddingbinaries
{"output":"2022-09-21T15:45:22.020532144+0000: Informational Bash ran inside a container (user=root command=bash /vendor/falco/scripts/myscript.sh <NA> (id=d4b6181cd88e))","priority":"Informational","rule":"Detect bash in a container","source":"syscall","tags":[],"time":"2022-09-21T15:45:22.020532144Z", "output_fields": {"container.id":"d4b6181cd88e","container.name":null,"evt.time.iso8601":1663775122020532144,"proc.cmdline":"bash /vendor/falco/scripts/myscript.sh","user.name":"root"}}
```

And clean up the workload with:

```bash
kubectl delete pods embeddingbinaries
kubectl delete configmap falco-config
kubectl delete configmap falco-local-rules
```

### Side Car Pattern

Here we will run 2 Container in 1 Kubernetes Pod. The first container will
contain the workload (instrumented with `pdig`) and the second container will
contain the Falco Daemon in a traditional side car pattern.

> Ensure to update the container image name in the pod specification with your
> container image URI.

```bash
# Deploy the Falco Configuration file
kubectl apply -f falco.yaml

# Deploy the Local Falco Rules File
kubectl apply -f falco-local-rules.yaml

# Deploy the Pod
kubectl apply -f sidecarptrace.yaml
```

You can monitor the workload with

```bash
kubectl logs -f sidecarptrace -c falcosidecar
{"output":"2022-09-21T15:50:02.501664749+0000: Informational Bash ran inside a container (user=root command=bash /vendor/falco/scripts/myscript.sh <NA> (id=5c0b99428181))","priority":"Informational","rule":"Detect bash in a container","source":"syscall","tags":[],"time":"2022-09-21T15:50:02.501664749Z", "output_fields": {"container.id":"5c0b99428181","container.name":null,"evt.time.iso8601":1663775402501664749,"proc.cmdline":"bash /vendor/falco/scripts/myscript.sh","user.name":"root"}}
```

And clean up the workload with:

```bash
kubectl delete pods sidecarptrace
kubectl delete configmap falco-config
kubectl delete configmap falco-local-rules
```