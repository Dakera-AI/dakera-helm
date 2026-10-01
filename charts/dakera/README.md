# Dakera

[![Artifact Hub](https://img.shields.io/endpoint?url=https://artifacthub.io/badge/repository/dakera-helm)](https://artifacthub.io/packages/helm/dakera-helm/dakera)
[![Chart Version](https://img.shields.io/github/v/release/dakera-ai/dakera-helm?label=chart&style=flat-square&color=blue)](https://github.com/dakera-ai/dakera-helm/releases)
[![License: MIT](https://img.shields.io/badge/license-MIT-green?style=flat-square)](https://github.com/dakera-ai/dakera-helm/blob/main/LICENSE)

**Dakera** is an AI agent memory platform. This Helm chart deploys the full Dakera stack on Kubernetes:

- **Dakera Server** — persistent, searchable agent memory via REST + gRPC
- **Dakera Dashboard** — web UI for inspecting and managing memories
- **Dakera MCP Server** — Model Context Protocol server for Claude and other AI clients
- **MinIO** — built-in S3-compatible object storage (or bring your own S3)

→ **Documentation**: [dakera.ai/docs](https://dakera.ai/docs)  
→ **GitHub**: [dakera-ai/dakera-helm](https://github.com/dakera-ai/dakera-helm)

---

## Versions

| | Dakera server | Chart version | Where |
|---|---|---|---|
| **Latest** | **v0.12.0** | **0.12.0** (and later 0.12.x) | `main` (this branch), the Helm repository and the OCI registry |
| Previous | v0.11.x (last: v0.11.108) | 0.11.x | the [`release/0.11`](https://github.com/Dakera-AI/dakera-helm/tree/release/0.11) branch |

`main` and the latest chart are **v0.12.0**. The v0.11 chart is kept on the
`release/0.11` branch, unchanged, so a v0.11 setup stays findable and working.
To stay on v0.11, pin the old chart version, for example:

```bash
helm install dakera oci://ghcr.io/dakera-ai/dakera-helm/dakera --version 0.11.107 ...
# or, with the Helm repository:
helm install dakera dakera/dakera --version 0.11.107 ...
```

0.11.107 is the last published v0.11 chart. Its default image tag is `0.11.101`;
set `--set dakera.image.tag=0.11.108` to run the final v0.11 server.
`helm search repo dakera/dakera --versions` lists every published version. The
chart version always equals the Dakera server version it deploys. Upgrading from
v0.11 to v0.12.0: read [CHANGELOG.md](CHANGELOG.md)
and the server's
[UPGRADE.md](https://github.com/Dakera-AI/dakera/blob/main/docs/v0.12/UPGRADE.md).

---

## Install

### OCI (recommended — no `helm repo add` needed)

```bash
helm install dakera oci://ghcr.io/dakera-ai/dakera-helm/dakera \
  --namespace dakera --create-namespace \
  --set dakera.rootApiKey=<your-key> \
  --set minio.rootPassword=<your-password>
```

Pin a specific version:

```bash
helm install dakera oci://ghcr.io/dakera-ai/dakera-helm/dakera \
  --version 0.12.0 \
  --namespace dakera --create-namespace \
  --set dakera.rootApiKey=<your-key> \
  --set minio.rootPassword=<your-password>
```

### Helm Repository (GitHub Pages)

```bash
helm repo add dakera https://dakera-ai.github.io/dakera-helm
helm repo update
helm install dakera dakera/dakera \
  --namespace dakera --create-namespace \
  --set dakera.rootApiKey=<your-key> \
  --set minio.rootPassword=<your-password>
```

---

## Upgrade

```bash
helm repo update
helm upgrade dakera dakera/dakera --namespace dakera \
  --set dakera.rootApiKey=<your-key> \
  --set minio.rootPassword=<your-password>
```

---

## Configuration

Pass values with `--set key=value` or a `values.yaml` file (`-f values.yaml`).

### Required Values

| Key | Description |
|---|---|
| `dakera.rootApiKey` | Root API key for Dakera. **Required.** |
| `minio.rootPassword` | MinIO root password for S3-compatible object storage. **Required.** |

### Common Options

| Key | Default | Description |
|---|---|---|
| `dakera.replicaCount` | `1` | Number of Dakera server replicas |
| `dakera.image.tag` | chart `appVersion` | Docker image tag |
| `dakera.config.storage` | `s3` | Storage backend: `memory`, `filesystem` or `s3` |
| `dakera.config.dataRoot` | `/data` | Data root (`DAKERA_STORAGE_PATH`); the persistence volume is mounted here and every local path (WAL, hot/warm tiers, graph, filesystem backend) lives under it |
| `dakera.config.l1CacheSize` | `1073741824` | Tiered-storage L1 cache (bytes, default 1 GB) |
| `dakera.persistence.size` | `20Gi` | PVC size for the data root |
| `dakera.cluster.secret` / `dakera.cluster.existingSecret.name` | empty | `DAKERA_CLUSTER_SECRET` (cluster mode; at least 16 chars, same on every node), stored in a Secret |
| `dakera.extraEnv` | `[]` | Any other `DAKERA_*` setting (Kubernetes EnvVar list), e.g. `DAKERA_MODEL`, `DAKERA_ENCRYPTION_KEY` |
| `dakera.models.pull` | `[]` | Models an init container pre-pulls (`dakera models pull`); `configured` = what the env configures |
| `dakera.models.persistence.enabled` | `false` | Keep the model cache (`/app/models`) on a PVC |
| `dakera.podSecurityContext.fsGroup` | `1000` | Group that owns the mounted volumes (the image runs as uid/gid 1000) |
| `rollback.enabled` | `false` | Render the one-off `dakera downgrade` Job (see "Rolling back to v0.11") |
| `dakera.resources.requests.memory` | `512Mi` | Memory request |
| `dakera.resources.limits.memory` | `4Gi` | Memory limit |
| `dakera.autoscaling.enabled` | `false` | Enable HPA (one server per data root; see values.yaml) |
| `dakera.autoscaling.maxReplicas` | `5` | HPA max replicas |
| `dashboard.enabled` | `true` | Deploy the web dashboard |
| `mcp.enabled` | `true` | Deploy the MCP server |
| `minio.enabled` | `true` | Deploy built-in MinIO (disable to use external S3) |
| `minio.persistence.size` | `50Gi` | MinIO PVC size |
| `ingress.enabled` | `false` | Enable ingress |
| `monitoring.enabled` | `false` | Enable Prometheus + Grafana |

### Use External S3 (instead of MinIO)

```yaml
minio:
  enabled: false

dakera:
  config:
    s3Endpoint: https://s3.amazonaws.com
    s3Bucket: my-dakera-bucket
    s3Region: us-east-1
```

### Enable Ingress

```yaml
ingress:
  enabled: true
  className: nginx
  apiHost: api.dakera.yourdomain.com
  dashboardHost: dashboard.dakera.yourdomain.com
  mcpHost: mcp.dakera.yourdomain.com
  tls:
    - secretName: dakera-tls
      hosts:
        - api.dakera.yourdomain.com
```

## Models, air-gapped installs

The image ships `bge-large` and the reranker in its own model store; they load
in seconds with no network. Any other model (`DAKERA_MODEL=bge-m3`, whisper, the
vision model, ...) downloads into the model cache (`/app/models`) on first use.
The REST port answers while models load: `/health/live` is 200 from the start,
`/health/ready` is 503 until storage and the embedding engine are up.

- Pre-pull before the pod serves: `dakera.models.pull: [configured]` (or a list of names).
- Keep the cache across pod restarts: `dakera.models.persistence.enabled: true`.
- Air-gapped: seed that volume from a host that can reach the Hub
  (`docker run --rm -v <volume>:/app/models ghcr.io/dakera-ai/dakera:0.12.0 models pull --dir /app/models <model>`,
  then mount it as the PVC), and use only models the image or the volume holds.
  See the server's [models-and-docker.md](https://github.com/Dakera-AI/dakera/blob/main/docs/models-and-docker.md).

## Cluster mode

Cluster mode needs `DAKERA_CLUSTER_SECRET` (at least 16 characters, identical on
every node) and a stable `DAKERA_CLUSTER_NODE_ID` per node. Enable it with
`dakera.extraEnv` (`DAKERA_CLUSTER_MODE=true`, ...) and give the secret through a
Secret, never the ConfigMap:

```yaml
dakera:
  cluster:
    existingSecret: {name: my-cluster-secret, key: DAKERA_CLUSTER_SECRET}   # or: secret: "<16+ chars>"
```

Cluster nodes must not share one S3 bucket as their store, and a server locks
its data root: one release of this chart is one node. When upgrading a running
v0.11 cluster leave the secret unset until every node runs v0.12.0 (server
UPGRADE.md, "Cluster").

## Rolling back to v0.11

Going back from v0.12.0 to v0.11.108 is supported (any v0.11 embedding model,
encrypted or not). The v0.12 binary converts the data back with
`dakera downgrade`, which must run **after** the server has stopped (it refuses,
exit 78 with nothing changed, while a server runs on the data):

```bash
# 1. stop the server
kubectl -n dakera scale deploy/<fullname> --replicas=0
# 2. run the downgrade as a one-off Job, with the server's env and volumes
helm template dakera dakera/dakera -n dakera <your usual values> \
  --set rollback.enabled=true --show-only templates/rollback-job.yaml \
  | kubectl -n dakera apply -f -
kubectl -n dakera wait --for=condition=complete job/<fullname>-downgrade --timeout=30m
kubectl -n dakera logs job/<fullname>-downgrade 2>/dev/null   # JSON report on stdout
# 3. only when the Job completed (exit 0): go back to the v0.11 chart
helm upgrade dakera oci://ghcr.io/dakera-ai/dakera-helm/dakera --version 0.11.107 -n dakera \
  --set dakera.image.tag=0.11.108 <your v0.11 values>
```

Exit code `0` = the data is v0.11.108's; `1` = not yet (do **not** start v0.11,
fix the cause and rerun); `78` = refused. Clusters: roll back the whole cluster,
not one node. Details, the memory-policy and knowledge-graph notes and the model
volume (`dakera models prune`) caveat: server
[UPGRADE.md, "Going back to v0.11"](https://github.com/Dakera-AI/dakera/blob/main/docs/v0.12/UPGRADE.md#going-back-to-v011).

---

## License

MIT — see [LICENSE](https://github.com/dakera-ai/dakera-helm/blob/main/LICENSE)
