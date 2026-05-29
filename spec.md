# zidle — Thin Spec

`zidle` is a Zig node agent for finding **quiescent Kubernetes pods** by reading Linux reality: cgroups, procfs, and network namespace counters.

It is not a hibernation tool, not an autoscaler, and not a safety oracle. It only answers:

> Has this pod shown little or no CPU, IO, network, or process activity over a time window?

## Design Principle

Build a **Linux node tool that happens to understand Kubernetes cgroups**.

Kubernetes is the deployment environment. The learning target is Linux.

## MVP

First milestone:

```bash
zidle scan
```

Print one JSON row per discovered pod:

```json
{
  "pod_uid": "...",
  "namespace": "app",
  "pod": "admin-ui-abc",
  "containers": 2,
  "pids": 14,
  "cpu_usage_usec": 123456789,
  "memory_current_bytes": 481239040,
  "io_read_bytes": 1234,
  "io_write_bytes": 5678,
  "net_rx_bytes": 999999,
  "net_tx_bytes": 888888
}
```

## Counters

Read from cgroup v2:

- `cpu.stat` → `usage_usec`
- `io.stat` → `rbytes`, `wbytes`, `rios`, `wios`
- `memory.current`
- `memory.events` for context
- `pids.current` / `cgroup.procs`

Read network counters from one process in the pod network namespace:

- `/proc/<pid>/net/dev`
- track `eth0` RX/TX bytes and packets
- ignore `lo`

## Later Commands

```bash
zidle agent --sample 15s --window 30m
zidle report
zidle dump-json
```

Classification states:

- `idle` — all deltas below thresholds for the full window
- `low` — tiny but non-zero activity
- `active` — clear CPU, IO, network, or process activity
- `unknown` — insufficient samples, reset counters, or incomplete mapping

## Non-Goals for Now

- No Kubernetes API dependency
- No RBAC requirement
- No eBPF in v0
- No automatic scaling, deletion, hibernation, or remediation
- No claim that “idle” means “safe to stop”

## Learning Goals

This project exists to build Zig and Linux systems muscle:

- Zig allocators, slices, errors, `defer`, filesystem parsing
- cgroups v2
- procfs
- process/cgroup/pod mapping
- network namespaces
- resource accounting and measurement
