# zidle

Idle detection experiments for Linux cgroups, written in Zig.

`zidle` is currently a learning project: first understand Linux cgroup/procfs counters, then layer Kubernetes pod awareness on top.

## Current status

Implemented so far:

- basic CLI command dispatch
- `zidle help`
- `zidle scan-cgroups`
- recursive cgroup v2 directory discovery
- configurable cgroup root via `--root`

## Usage

```bash
zig build run -- help
zig build run -- scan-cgroups
zig build run -- scan-cgroups --root /sys/fs/cgroup
```

`scan-cgroups` expects a cgroup v2 root. On a normal Linux host this is usually:

```text
/sys/fs/cgroup
```

When running inside a container with the host cgroup filesystem mounted, this may become something like:

```text
/host/sys/fs/cgroup
```

## Next milestone

Parse one cgroup counter file:

```text
cpu.stat -> usage_usec
```

Suggested next shape:

- add a small `CpuStat` struct
- write a pure parser for `cpu.stat` contents
- add tests using fixture strings before reading real files
