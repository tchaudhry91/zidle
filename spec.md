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

## Final Desired Shape

The long-term goal is not to re-export raw resource counters. The desired product is an **idle period event detector**.

`zidle` should observe pod activity over time and emit compact semantic events such as:

```json
{
  "event": "idle_period_started",
  "pod_uid": "...",
  "namespace": "app",
  "pod": "admin-ui",
  "started_at": "...",
  "window_seconds": 1800,
  "reason": {
    "cpu_usage_usec_delta": 1200,
    "io_read_bytes_delta": 0,
    "io_write_bytes_delta": 0,
    "net_rx_bytes_delta": 50,
    "net_tx_bytes_delta": 20,
    "pids_current": 3
  }
}
```

and later:

```json
{
  "event": "idle_period_ended",
  "pod_uid": "...",
  "namespace": "app",
  "pod": "admin-ui",
  "started_at": "...",
  "ended_at": "...",
  "duration_seconds": 14400,
  "ended_by": "network_activity"
}
```

Raw counters are inputs to the detector. The useful output is a history of idle/low/active/unknown intervals with enough evidence to explain each transition.

Potential downstream users include systems that learn workload patterns or adjust pod/resource policy during recurring idle periods. Prometheus-style metrics may still be useful for debugging and visibility, but they are a sink, not the core goal.

### Event pipeline vision

`zidle` should remain a node-local witness. It observes only the pods currently running on its node and emits evidence-backed state transitions. A separate stateful system, currently referred to as `compacter`, can own Kubernetes API access, durable history, workload identity, pattern detection, and future policy decisions.

Example chain:

1. A DaemonSet runs one `zidle` instance per node.
2. `zidle` on `node-2` observes pod UID `pod-a` from local cgroups/procfs and emits `idle_period_started` after a quiet window.
3. `zidle` on `node-5` and `node-8` independently emit events for other pod UIDs they locally observe.
4. A relay or collector forwards these JSON events to `compacter`.
5. `compacter` uses the Kubernetes API/cache to enrich `pod_uid -> namespace/pod/owner`, for example `StatefulSet search/indexer` and ordinal `indexer-1`.
6. `compacter` stores durable pod-instance intervals and aggregates them into workload-level history.
7. If a pod becomes active, its local `zidle` emits `idle_period_ended` with the signal that ended idleness, such as CPU, IO, or network activity.
8. If a node or detector disappears, `compacter` treats open intervals as `unknown` or `observation_lost` rather than assuming they ended cleanly.

Important identity rule: Kubernetes pods do not truly move between nodes. A reschedule usually means the old pod UID disappeared and a new pod UID appeared elsewhere. `zidle` should report pod-instance truth by UID; `compacter` can connect those instances back to a stable workload identity such as Deployment, StatefulSet, Job, or CronJob.

Preferred responsibility split:

```text
zidle      = node-local witness: sample, classify, emit events
relay      = optional delivery/enrichment bridge, likely easier in Go
compacter  = historical interpreter: store intervals, map owners, find patterns
policy     = optional later actor: recommend or apply resource changes
```

The event stream should eventually include transition events, detector heartbeats, event IDs for dedupe, observation timestamps, and explicit unknown/lost-observation states.

## Open Design Notes

These are current working ideas, not fixed decisions.

### Kubernetes pod identity

Kubernetes pod cgroups are expected to expose the pod UID and runtime/container IDs, not friendly names like `namespace/pod`.

Possible node-local mapping sources:

- cgroup path → pod UID, QoS class, container/runtime ID
- `/host/var/log/pods/<namespace>_<pod-name>_<pod-uid>/` → best-effort UID to namespace/name mapping
- `/host/var/log/containers/*.log` → symlinks that may help map container name/ID to pod identity

This log-directory approach is useful for v0 because it keeps `zidle` Linux/node-local and avoids Kubernetes API/RBAC early. It is not authoritative: directories may be stale, missing, or affected by kubelet configuration.

A later Kubernetes API mapper could list pods assigned to the current node using the service account token and a selector like `spec.nodeName=<node>`. That is authoritative but adds HTTPS/TLS, CA handling, token auth, RBAC, JSON parsing, pagination, and eventually watch-cache complexity.

### CLI shape under consideration

Debug/learning commands should come before a daemon:

```bash
zidle scan-cgroups --root /host/sys/fs/cgroup
zidle scan-pods --cgroup-root /host/sys/fs/cgroup --pod-log-root /host/var/log/pods
zidle scan --cgroup-root /host/sys/fs/cgroup --proc-root /host/proc --pod-log-root /host/var/log/pods --output json
zidle sample --interval 15s --count 2
```

Potential progression:

1. `scan-cgroups` — raw cgroup discovery
2. `scan-pods` — extract pod UIDs and map to namespace/name when possible
3. `scan` — one-shot current pod counters
4. `sample` — two or more snapshots and deltas
5. `agent` — sampling loop plus HTTP endpoints
6. classification — `idle` / `low` / `active` / `unknown`

### Prometheus-style metrics

A future DaemonSet mode may expose `/metrics` and `/healthz`:

```bash
zidle agent \
  --cgroup-root /host/sys/fs/cgroup \
  --proc-root /host/proc \
  --pod-log-root /host/var/log/pods \
  --sample-interval 15s \
  --window 30m \
  --listen :9108
```

Prometheus exposition can start as plain text written by `zidle`; a full client library is not required for v0. The main details to handle are metric type/help lines and safe label escaping.

Example metric names under consideration:

```text
zidle_pod_cpu_usage_seconds_total{namespace,pod,uid}
zidle_pod_cpu_throttled_seconds_total{namespace,pod,uid}
zidle_pod_io_read_bytes_total{namespace,pod,uid}
zidle_pod_io_write_bytes_total{namespace,pod,uid}
zidle_pod_network_rx_bytes_total{namespace,pod,uid}
zidle_pod_network_tx_bytes_total{namespace,pod,uid}
zidle_pod_memory_current_bytes{namespace,pod,uid}
zidle_pod_pids_current{namespace,pod,uid}
zidle_pod_idle{namespace,pod,uid}
```

## Possible Later Commands

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
