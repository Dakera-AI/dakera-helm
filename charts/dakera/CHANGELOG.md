# Changelog

The chart version equals the Dakera server version it deploys. v0.11 lives on the
`release/0.11` branch and in the 0.11.x chart versions (last published: 0.11.107).

## 0.12.0 (Dakera server v0.12.0)

### Upgrade notes (0.11.x to 0.12.0)

Read the server's
[UPGRADE.md](https://github.com/Dakera-AI/dakera/blob/main/docs/v0.12/UPGRADE.md)
first; this chart follows it.

1. **Back up first** (`POST /admin/backups`).
2. **Check the configuration with the new image** before upgrading: run
   `dakera --check-config` with the new image, the same environment and the data
   volume (a one-off Pod/Job, or `docker run`). It lists every warning the first
   start will give and exits 0 (would start) or 78 (would refuse).
3. **Remove `dakera.config.l2CachePath`** from your values if you set it.
   v0.12 no longer reads `DAKERA_L2_CACHE_PATH` (an upgraded deployment only
   warns; a fresh install refuses to start). The data root is
   `dakera.config.dataRoot` (default `/data`, `DAKERA_STORAGE_PATH`); the data
   volume is mounted there.
4. **The data PVC keeps its name** (`<fullname>-rocksdb`) so `helm upgrade` keeps
   the volume. It is now mounted at the data root (`/data`) instead of
   `/data/rocksdb`; the former `/data/cache` emptyDir is gone (the warm tier
   lives under the data root on the volume).
5. **The server Deployment now uses `strategy: Recreate`** when persistence is on
   (a server locks its data root; the old pod must stop first). If `helm upgrade`
   rejects the strategy change, delete the Deployment (not the PVC) and upgrade
   again.
6. **Image tag**: `dakera.image.tag` defaults to the chart `appVersion` (it
   defaulted to a pinned tag before). Remove a stale pin from your values.
7. **Autoscaling is off by default** (`dakera.autoscaling.enabled: false`): one
   server per data root. Set it back only with persistence off and an external S3.
8. **Probes**: readiness `/health/ready`, liveness and startup `/health/live`.
   The port answers while models load.
9. **Clusters**: set `dakera.cluster.secret` (or `existingSecret`) and a stable
   node id **after** every node runs v0.12.0 (leave unset during a mixed
   v0.11/v0.12 period).
10. **Namespace quotas are enforced**, a stored backup schedule starts running,
    keys pinned to namespaces lose node-wide routes: see the server UPGRADE.md.
11. **Rollback** to v0.11.108: `rollback.enabled` Job (`dakera downgrade`), see
    the README, "Rolling back to v0.11".

### Changed
- Chart and `appVersion` 0.12.0; the server image tag follows `appVersion`.
- Readiness probe `/health/ready`; liveness `/health/live`; new startup probe
  (10 minutes) for write-ahead-log replay.
- `DAKERA_S3_ENDPOINT` points at the built-in MinIO, or at `dakera.config.s3Endpoint`
  when `minio.enabled=false` (it always pointed at MinIO before).
- `dakera.config.storage` accepts `memory`, `filesystem`, `s3` (the schema listed `local`).
- MinIO image pinned (`RELEASE.2025-04-08T15-41-24Z`), default user `dakera-minio`,
  resources raised to the server chart's.
- Brought in line with the server repo's `charts/dakera` (0.12.0): pod
  `fsGroup: 1000`, model cache, `extraEnv`, `readOnlyRootFilesystem` option.

### Added
- `dakera.cluster.secret` / `dakera.cluster.existingSecret`: `DAKERA_CLUSTER_SECRET`
  from a Secret (at least 16 characters, validated).
- `dakera.models.pull` (init container `dakera models pull`) and
  `dakera.models.persistence` (model cache PVC, air-gapped seeding).
- `dakera.extraEnv`, `dakera.podSecurityContext`, `dakera.readOnlyRootFilesystem`,
  `dakera.config.dataRoot`.
- `rollback.enabled`: a one-off Job that runs `dakera downgrade`.

### Removed
- `dakera.config.l2CachePath` / `DAKERA_L2_CACHE_PATH` (no longer read by v0.12;
  every local path derives from `DAKERA_STORAGE_PATH`).

### Fixed
- `minio.enabled=true` now deploys MinIO (Deployment, PVC, Service); chart 0.11.x
  referenced a MinIO service it never created.

### Known limitations
- `monitoring.enabled` still has no templates (Prometheus/Grafana are not
  deployed by this chart); unchanged from 0.11.x.
- One release of this chart is one server. Multi-node cluster topologies need one
  release per node (own bucket, own data root, shared `DAKERA_CLUSTER_SECRET`).
