# Container Images for Falco Userspace Instrumentation

As mentioned in the README at the [root](/../../tree/main) of this project, in this directory
we demonstrate 3 deployment patterns to run Falco on AWS Fargate.

  * Embedding the tracing binary and the Falco binary in to the workload
    container image (Amazon EKS or Amazon ECS).
  * Mounting the tracing binary and the Falco binary in to the workload container
    image at runtime via a "sleeping" side car (Amazon ECS only).
  * Embedding the tracing binary in to the workload container and running the
    Falco Binary as a side car (Amazon EKS only).

## Sample workload

All three of the patterns in this repository use a "sample workload". This
workload is just a bash script running commands on a loop. I appreciate this is
not a real world workload, however it is used in this scenario to generate lots
of Falco alerts.

## Required Binaries

For the system calls to be captured, streamed and alerted on, there are a number
of things that are "required" at runtime. These are:

1. [A pdig binary](https://github.com/falcosecurity/pdig) - this is a system
   call tracing and streaming binary. This binary can either start or be
   attached to the workload process. Instead of building the binary from source,
   in this sample we are "borrowing" the pre built binary from an existing
   `falcosecurity/falco-userspace` container image.
2. [A Falco binary](https://github.com/falcosecurity/falco) borrowed from the
   official Falco container image `falcosecurity/falco`
3. [A Falco Rule
   files](https://github.com/falcosecurity/falco/tree/master/rules), once again
   we borrow the default set of rules from the official Falco image
   `falcosecurity/falco`.

Its worth noting we plan to keep the `falco.yaml` (Falco's [Configuration
File](https://falco.org/docs/configuration/)) and the `falco_rules.local.yaml`
file (Our set of [Falco Alerting
Rules](https://falco.org/docs/rules/default-custom/)) out of the workload
container image regardless of the deployment pattern. These two configuration
files may want to be changed depending on the workload or the environment the
container is running in. When running locally we mount them in using bind
mounts, but when running on a container orchestrator we pass them in to the
container as configuration files.

### Embedding Binaries in to the Container Image

This pattern embeds the 2 binaries mentioned above and the default Falco Rules
file into the workload container image. We also made a decision to includes a
process manager in this pattern, as there will 2 services that we want to manage
the lifecycle of (this is an optional step). The 2 process we care about are
the workload process and the Falco daemon.

> This example use a process manager called
> [supervisord](https://github.com/Supervisor/supervisor). Other process
> managers could be used, such as
> [s6](https://github.com/just-containers/s6-overlay). The supervisord process
> manager is written in Python and may be seen as "heavy" for non python based
> workloads.

```bash
cd embeddedbinaries

# Build the container image
docker build \
  --tag embeddedbinaries \
  .

# Run the container image and mount in the configuration files
docker run \
  --rm \
  --volume $PWD/falco.yaml:/data/falco.yaml:ro \
  --volume $PWD/falco_rules.local.yaml:/data/falco_rules.local.yaml:ro \
  --cap-add SYS_PTRACE \
  embeddedbinaries
```

After starting the container you should now see the application workload start
and Falco error messages appearing in the Docker logs.

```
{"output":"2022-09-08T17:42:00.851005190+0000: Informational Bash ran inside a container (user=<NA> command=bash /vendor/falco/scripts/myscript.sh <NA> (id=2e153fc3dafb))","priority":"Informational","rule":"Detect bash in a container","source":"syscall","tags":[],"time":"2022-09-08T17:42:00.851005190Z", "output_fields": {"container.id":"2e153fc3dafb","container.name":null,"evt.time.iso8601":1662658920851005190,"proc.cmdline":"bash /vendor/falco/scripts/myscript.sh","user.name":"<NA>"}}
```

### Mounting Binary in to the Container Image

For scenarios where you do not want to embed the binaries into the workload
container image, such as if you're a central platform team who are enforcing
runtime security but not involved in the workload container image build, then
passing binaries in at Runtime can solve the problem.

A lot of the inspiration and tooling for this approach came from Falco's [Kilt
Project](https://github.com/falcosecurity/kilt). The Kilt Project is how the
commercial [Sysdig
Project](https://docs.sysdig.com/en/docs/installation/serverless-agents/aws-fargate-serverless-agents/#aws-fargate-serverless-agents)
embeds binaries for use on AWS Fargate. In this pattern we are running 2
containers, 1 container with the binaries included and 1 container with the
workload. Critically the binaries container is not a Falco sidecar, the Falco
Daemon will run in the workload container, the binaries container is used as
a mount point (more details below).

The binary container includes a few things:

* The pdig binary, the Falco binary and the default Falco rules. This is the same
  as the [embedded binaries images](#required-binaries).
* The [waitforever
  binary](https://github.com/falcosecurity/kilt/tree/master/utilities/waitforever)
  from the Kilt utilities. This utility is a long running process that doesn't
  actually do anything, but it prevents the binary container from stopping.
* The [launcher
  binary](https://github.com/falcosecurity/kilt/tree/master/utilities/launcher)
  from the Kilt utilities. This launcher binary becomes the entrypoint of the
  workload container. Its job is to start Falco as a background process, and
  then start the workload as a foreground process. As we don't want to modify
  the workload container image with `entrypoint.sh` scripts.
* The [logshipper
  binary](https://github.com/falcosecurity/kilt/tree/master/utilities/logshipper)
  from the Kilt utilities. As Falco is not running in the foreground its logs
  are not shown in the Docker logs. This `logshipper` binary takes the Falco
  logs, via the `program_output` setting in the `falco.yaml` configuration file,
  and sends them to a Amazon CloudWatch Log Group. When you run the workload
  locally you will need to pass in AWS Credentials to create and write to a Log
  Group. When running on Amazon ECS these Credentials are passed in via the ECS
  Task Role. To configure which log group to write the logs too, there is an
  environment variable `__CW_LOG_GROUP` directory.

The way the binaries are mounted in to the workload container from the binary
container is through some [Docker
Volumes](https://docs.docker.com/storage/volumes/) MAGIC!! If a Dockerfile has a
`VOLUME` line, when a container is created from that Image the Container Runtime
will create a [Docker Volume](https://docs.docker.com/storage/volumes/)
containing the contents from the directory specified in `VOLUME <dir>`. A Docker
Volume is a directory on the host, usually at `/var/lib/docker/volumes`.

So in our example:

1. We put the binaries in a directory in the binaries container image called
   `/vendor/falco`.
2. We  make `/vendor/falco` a Docker volume, by specifying `VOLUME
/vendor/falco` in the Dockerfile.
3. When the container runs, the contents of `/vendor/falco` are available on the
host as `/var/lib/docker/volume/<randomid>/_data/`.
4. Then through the use of `--volumes-from <binaries_container>` flag passed
   into `docker run`, we mount all Docker Volumes that are being used by the
   binaries container into the workload container.
5. Magic!!! This works on AWS Fargate and allows us to pass binaries between the
containers.

```bash
cd mountedbinaries

# Build the binary container image
docker build \
  --tag mountedbinaries \
  --file Dockerfile.binaries \
  .

# Build the workload container image
docker build \
  --tag mountedbinariesworkload \
  --file Dockerfile.workload \
  .

# Start the binary container
docker run \
  --rm \
  --detach \
  --name mountedbinariescontainer \
  mountedbinaries

# Start the workload container. Notice how we are overriding
# the workload container image entrypoint and command.
docker run \
  --rm \
  --volumes-from mountedbinariescontainer:ro \
  --volume $HOME/.aws:/root/.aws:ro \
  --volume $PWD/falco.yaml:/data/falco.yaml:ro \
  --volume $PWD/falco_rules.local.yaml:/data/falco_rules.local.yaml:ro \
  --cap-add SYS_PTRACE \
  --env "AWS_REGION=eu-west-1" \
  --env "__CW_LOG_GROUP=/aws/ecs/service/falco_alerts" \
  --entrypoint /vendor/falco/bin/launcher \
  mountedbinariesworkload \
  /vendor/falco/bin/pdig /bin/bash /myfiles/myscript.sh -- /vendor/falco/bin/falco --userspace -c /data/falco.yaml
```

You can verify that the Falco logs are coming through, either by checking the
Amazon CloudWatch Console, or by using the `aws logs get-log-events` command.

```
$ aws logs get-log-events --log-group-name /aws/ecs/service/launcher_falco_alerts --log-stream-name c4bc416d81aaadcd9b8a53e78e0e9f8c636e35535b565bd2d50145b3117ba29a.0
{
    "events": [
        {
            "timestamp": 1662718564957,
            "message": "{\"output\":\"2022-09-09T10:15:24.893337209+0000: Warning Outbound network traffic connection (srcip=10.2.11.224 dstip=74.125.193.94 dstport=443 proto=udp procname=curl)\",\"priority\":\"Warning\",\"rule\":\"outbound connection\",\"source\":\"syscall\",\"tags\":[],\"time\":\"2022-09-09T10:15:24.893337209Z\", \"output_fields\": {\"evt.time.iso8601\":1662718524893337209,\"fd.cip\":\"10.2.11.224\",\"fd.l4proto\":\"udp\",\"fd.sip\":\"74.125.193.94\",\"fd.sport\":443,\"proc.name\":\"curl\"}}",
            "ingestionTime": 1662718565294
        },
```
### Side Car Pattern

In this pattern, the workload container will be instrumented with `pdig`,
however the Falco daemon will run in a side car container. For this to work, you
need to share the IPC namespace between 2 containers. This is not supported in
Amazon ECS for AWS Fargate but it is supported in Amazon EKS for AWS Fargate.
Sharing IPC namespaces is a primitive of a Kubernetes pod, so all containers in
the same Pod share an IPC namespace (and networking namespaces).

```bash
cd sidecarptrace

# Build the Falco Daemon container image
docker build \
  --tag sidecarptracefalco \
  --file Dockerfile.falco \
  .

# Build the Workload Container Image
docker build \
  --tag sidecarptraceworkload \
  --file Dockerfile.workload \
  .

# Start the Falco Daemon and make the IPC Namespace shareable
docker run \
  --rm \
  --detach \
  --name sidecarptracefalco \
  --ipc shareable \
  --volume $PWD/falco.yaml:/data/falco.yaml:ro \
  --volume $PWD/falco_rules.local.yaml:/data/falco_rules.local.yaml:ro \
  sidecarptracefalco

# Start the workload and share the IPC namespace
docker run \
  --rm \
  --detach \
  --name sidecarptraceworkload \
  --ipc container:sidecarptracefalco \
  --cap-add SYS_PTRACE \
  sidecarptraceworkload
```

Using Docker Logs on the Falco daemon container, we should see the Falco Logs.

```bash
docker logs -f sidecarptracefalco
{"hostname":"9f972d379b33","output":"Falco internal: timeouts notification. 1000 consecutive timeouts without event.","output_fields":{"last_event_time":"none"},"priority":"Debug","rule":"Falco internal: timeouts notification","time":"2022-09-21T15:08:17.731995145Z"}
```