# zidle

`zidle` is a Linux node-local experiment for detecting quiescent Kubernetes pods from kernel-visible resource counters.

The core idea is simple:

> Build a Linux node tool that happens to understand Kubernetes cgroups.

Kubernetes is the environment, but the learning target is Linux: cgroup v2, procfs, network namespaces, and resource accounting.

## Goal

`zidle` should eventually answer questions like:

> Has this pod shown little or no CPU, IO, network, or process activity over a time window?

The useful output is not just raw metrics. The long-term aim is to emit evidence-backed state transitions such as idle, low-activity, active, or unknown.

## Data sources

The project focuses on read-only Linux interfaces:

- cgroup v2 CPU, memory, IO, and PID counters
- procfs process and network namespace files
- node-local Kubernetes/kubelet files where useful for pod identity

No Kubernetes API is required for the early design.

## Non-goals

`zidle` is not:

- a pod hibernation system
- an autoscaler
- a remediation tool
- a safety oracle for deleting or stopping workloads

It observes and reports. It should not mutate cluster state.

## Project notes

This is a learning project written in Zig. Prefer small, inspectable steps over large abstractions or dependencies.

For the fuller design sketch, see [`spec.md`](./spec.md).
