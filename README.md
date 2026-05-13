# dakera-helm

Helm chart source repository for [Dakera](https://dakera.ai) — AI agent memory platform.

[![Artifact Hub](https://img.shields.io/endpoint?url=https://artifacthub.io/badge/repository/dakera)](https://artifacthub.io/packages/helm/dakera/dakera)

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

## Publishing

Charts are released automatically on every push to `charts/` on `main` via:
- `helm/chart-releaser-action` → GitHub Pages index: `https://dakera-ai.github.io/dakera-helm/`
- `helm push` → OCI: `oci://ghcr.io/dakera-ai/dakera-helm/dakera`

Push changes to `charts/` on `main` to trigger an automatic release.
