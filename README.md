# dakera-helm

Helm chart source repository for [Dakera](https://dakera.ai) — AI agent memory platform.

[![Artifact Hub](https://img.shields.io/endpoint?url=https://artifacthub.io/badge/repository/dakera)](https://artifacthub.io/packages/helm/dakera/dakera)
[![Chart Version](https://img.shields.io/github/v/release/dakera-ai/dakera-helm?label=chart&style=flat-square&color=blue)](https://github.com/dakera-ai/dakera-helm/releases)
[![OCI](https://img.shields.io/badge/OCI-ghcr.io-purple?style=flat-square)](https://github.com/dakera-ai/dakera-helm/pkgs/container/dakera-helm%2Fdakera)
[![License: MIT](https://img.shields.io/badge/license-MIT-green?style=flat-square)](LICENSE)

Deploy Dakera on Kubernetes in seconds. Two install paths: OCI registry (no repo add) or GitHub Pages Helm repository.

→ **Landing page**: [dakera-ai.github.io/dakera-helm](https://dakera-ai.github.io/dakera-helm/)
→ **Documentation**: [dakera.ai/docs](https://dakera.ai/docs)

---

## Install

### OCI (recommended — no repo add needed)

```bash
helm install dakera oci://ghcr.io/dakera-ai/dakera-helm/dakera \
  --namespace dakera --create-namespace \
  --set dakera.rootApiKey=<your-key> \
  --set minio.rootPassword=<your-password>
```

Pin a specific version:

```bash
helm install dakera oci://ghcr.io/dakera-ai/dakera-helm/dakera \
  --version 0.11.55 \
  --namespace dakera --create-namespace \
  --set dakera.rootApiKey=<your-key> \
  --set minio.rootPassword=<your-password>
```

### Helm Repository (ArtifactHub / GitHub Pages)

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

### Required

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
| `service.type` | `ClusterIP` | Kubernetes service type |
| `ingress.enabled` | `false` | Enable ingress |
| `ingress.host` | `""` | Ingress hostname |

Full values reference: [charts/dakera/values.yaml](charts/dakera/values.yaml)

---

## Publishing

Charts are released automatically on every push to `charts/` on `main` via:
- `helm/chart-releaser-action` → GitHub Pages index: `https://dakera-ai.github.io/dakera-helm/`
- `helm push` → OCI: `oci://ghcr.io/dakera-ai/dakera-helm/dakera`

Push changes to `charts/` on `main` to trigger an automatic release.

---

## License

MIT — see [LICENSE](LICENSE)
