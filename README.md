# dakera-helm

Helm chart source repository for [Dakera](https://dakera.ai) — AI agent memory platform.

## Install

### OCI (recommended — no repo add needed)
```bash
helm install dakera oci://ghcr.io/dakera-ai/charts/dakera \
  --namespace dakera --create-namespace \
  --set dakera.rootApiKey=<your-key> \
  --set minio.rootPassword=<your-password>
```

### Helm Repository (GitHub Pages)
```bash
helm repo add dakera https://dakera-ai.github.io/dakera-deploy
helm repo update
helm install dakera dakera/dakera \
  --namespace dakera --create-namespace \
  --set dakera.rootApiKey=<your-key> \
  --set minio.rootPassword=<your-password>
```

## Publishing

Charts are released via `helm/chart-releaser-action` to:
- GitHub Pages: `https://dakera-ai.github.io/dakera-deploy/`
- OCI: `oci://ghcr.io/dakera-ai/charts/dakera`

Push changes to `charts/` on `main` to trigger an automatic release.
