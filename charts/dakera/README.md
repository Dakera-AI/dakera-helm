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
  --version 0.11.56 \
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
| `dakera.config.storage` | `s3` | Storage backend (`s3` or `fs`) |
| `dakera.config.l1CacheSize` | `1073741824` | L1 in-memory cache size (bytes, default 1 GB) |
| `dakera.persistence.size` | `20Gi` | PVC size for RocksDB data |
| `dakera.resources.requests.memory` | `512Mi` | Memory request |
| `dakera.resources.limits.memory` | `4Gi` | Memory limit |
| `dakera.autoscaling.enabled` | `true` | Enable HPA |
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

---

## License

MIT — see [LICENSE](https://github.com/dakera-ai/dakera-helm/blob/main/LICENSE)
