# Falco on AWS Fargate

[Falco](https://falco.org/docs/), the CNCF project, provides runtime monitoring
of containerised workloads. Falco monitors which system calls are being made and
can notify administrators when unusual system calls occur. System calls are
streamed to Falco for analysis in a [number of
ways](https://falco.org/docs/#what-are-the-components-of-falco):
1. By loading a kernel module
2. By leveraging BPF probes
3. User space instrumentation.

On AWS Fargate, the number of privileges you can add to a container are reduced,
improving the security profile of the containerised workloads that run on it. As
access to the underlying host in AWS Fargate is restricted, you are unable to
load Falco's kernel modules or BPF probes to the underlying kernel. Therefore,
the only way to stream system calls for containerised workloads on AWS Fargate
is user space instrumentation, leveraging the
[SYS_PTRACE](https://man7.org/linux/man-pages/man2/ptrace.2.html) Linux
capability.

The user space implementation is where a tracing binary traces the calls of a
child process or attaches itself to an already running process. The tracing
binary streams the system calls to Falco which can then analyze them against
rules. For this pattern to work, the tracing binary needs to be located in the
same container as the containerised workload (to be able to either launch or
attach itself to the workload process). Secondly the Falco binary needs to be in
the same IPC namespace as the tracing binary to retrieve the system call stream.

In Amazon ECS for AWS Fargate, you are unable to share an IPC namespace between
2 containers, therefore the [traditional side car
pattern](https://docs.microsoft.com/en-us/azure/architecture/patterns/sidecar)
would not work. The Falco binary would need to be running in the same container
as the tracing binary that is creating a system call stream.

In Amazon EKS for AWS Fargate, you are able to share an IPC namespace between 2
containers, therefore you can adopt the [traditional side car
pattern](https://docs.microsoft.com/en-us/azure/architecture/patterns/sidecar).

This GitHub Repository contains 3 things:

1. Examples of different user space tracing patterns, [built and demonstrated on
  a local Docker Engine](./containerimages). These patterns are:

    * Embedding the tracing binary and the Falco binary in to the workload
      container image (Amazon EKS or Amazon ECS).
    * Mounting the tracing binary and the Falco binary in to the workload container
      image at runtime via a "sleeping" side car (Amazon ECS only).
    * Embedding the tracing binary in to the workload container and running the
      Falco Binary as a side car (Amazon EKS only).

2. [Example ECS Task definitions](./taskdefinitions/) demonstrating how you
   could deploy these patterns on to Amazon ECS on AWS Fargate.

3. [Example Kubernetes Pod specifications](./podspecs/) demonstrating how you
   could deploy these patterns on to Amazon EKS on AWS Fargate.