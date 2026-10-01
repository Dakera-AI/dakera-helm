# dakera-helm

Helm chart source repository for [Dakera](https://dakera.ai) — AI agent memory platform.

[![Artifact Hub](https://img.shields.io/endpoint?url=https://artifacthub.io/badge/repository/dakera-helm)](https://artifacthub.io/packages/helm/dakera-helm/dakera)
[![Chart Version](https://img.shields.io/github/v/release/dakera-ai/dakera-helm?label=chart&style=flat-square&color=blue)](https://github.com/dakera-ai/dakera-helm/releases)
[![OCI](https://img.shields.io/badge/OCI-ghcr.io-purple?style=flat-square)](https://github.com/dakera-ai/dakera-helm/pkgs/container/dakera-helm%2Fdakera)
[![License: MIT](https://img.shields.io/badge/license-MIT-green?style=flat-square)](LICENSE)

Deploy Dakera on Kubernetes in seconds. Two install paths: OCI registry (no repo add) or GitHub Pages Helm repository.

→ **Landing page**: [dakera-ai.github.io/dakera-helm](https://dakera-ai.github.io/dakera-helm/)
→ **Documentation**: [dakera.ai/docs](https://dakera.ai/docs)

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
v0.11 to v0.12.0: read [charts/dakera/CHANGELOG.md](charts/dakera/CHANGELOG.md)
and the server's
[UPGRADE.md](https://github.com/Dakera-AI/dakera/blob/main/docs/v0.12/UPGRADE.md).

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
  --version 0.12.0 \
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
| `dakera.config.storage` | `s3` | Storage backend: `memory`, `filesystem` or `s3` |
| `dakera.config.dataRoot` | `/data` | Data root (`DAKERA_STORAGE_PATH`); the persistence volume is mounted here and every local path (WAL, hot/warm tiers, graph, filesystem backend) lives under it |
| `dakera.config.l1CacheSize` | `1GB` | Tiered-storage hot-tier budget. A unit suffix is bytes; a bare number below 10 million is a vector **count** (the server's default is 100000 vectors) |
| `dakera.persistence.size` | `20Gi` | PVC size for the data root |
| `dakera.cluster.secret` / `dakera.cluster.existingSecret.name` | empty | `DAKERA_CLUSTER_SECRET` (cluster mode; at least 16 chars, same on every node), stored in a Secret |
| `dakera.extraEnv` | `[]` | Any other `DAKERA_*` setting (Kubernetes EnvVar list), e.g. `DAKERA_MODEL`, `DAKERA_ENCRYPTION_KEY` |
| `dakera.models.pull` | `[]` | Models an init container pre-pulls (`dakera models pull`); `configured` = what the env configures |
| `dakera.models.persistence.enabled` | `false` | Keep the model cache (`/app/models`) on a PVC (on automatically while a v0.12 feature that needs models is enabled) |
| `dakera.features.*` | all off | The v0.12 features: multilingual, multimodal, vision, records, lateInteraction, rabitq (see "Features in v0.12.0") |
| `dakera.podSecurityContext.fsGroup` | `1000` | Group that owns the mounted volumes (the image runs as uid/gid 1000) |
| `rollback.enabled` | `false` | Render the one-off `dakera downgrade` Job (see "Rolling back to v0.11") |
| `dakera.resources.requests.memory` | `512Mi` | Memory request |
| `dakera.resources.limits.memory` | `4Gi` | Memory limit |
| `dakera.autoscaling.enabled` | `false` | Enable HPA (one server per data root; see values.yaml) |
| `dakera.autoscaling.maxReplicas` | `5` | HPA max replicas |
| `service.type` | `ClusterIP` | Kubernetes service type |
| `ingress.enabled` | `false` | Enable ingress |
| `ingress.apiHost` / `ingress.dashboardHost` / `ingress.mcpHost` | unset | Ingress hostnames |

Full values reference: [charts/dakera/values.yaml](charts/dakera/values.yaml)

---

## Features in v0.12.0

v0.12.0 adds multilingual search, multimodal memory, multi-vector records, late interaction, a RaBitQ search
mode, rerank controls, a model store and more. **Every new feature is off by default**: with
`dakera.features.*` untouched the chart renders what it did for the plain upgrade. Each feature is a block under
`dakera.features` in [values.yaml](charts/dakera/values.yaml) (commented there) that sets the variables the
feature needs and wires what it implies: the model-cache volume, an init container that pulls the models, the
resources. Ready-to-use files are in [charts/dakera/examples/](charts/dakera/examples/). The full guide, with the
variables, constraints, sizing and verification per feature, is
[dakera-deploy `docs/features-v0.12.md`](https://github.com/Dakera-AI/dakera-deploy/blob/main/docs/features-v0.12.md).

| Feature | Values | Example file | Costs | Constraints | Verify (`GET /v1/capabilities`) |
|---|---|---|---|---|---|
| **Multilingual** (bge-m3, per-language full-text, CJK bigrams, query languages, per-request `lang`) | `features.multilingual.*` (`fulltextLanguage`, `cjkBigrams`, `queryLang`, `maxSeqLength`) | `values-multilingual.yaml` | bge-m3 ~570 MB (+ ORT copy), CPU ONNX only, truncation 2048 tokens | **Fresh store**; `config.tiered: "0"`; not with late interaction / vision; one-way for v0.11 | `default_model` = `bge-m3` |
| **Attachments + speech to text** (whisper-tiny.en) | `features.multimodal.*` (`attachmentMaxBytes`, `memHighWaterFraction`, `resources`) | `values-multimodal.yaml` | whisper ~151 MB; 8Gi / 4 cores (the measured configuration: 530 MiB anonymous with every model, +1.9 GiB image peak) | Any store; English, WAV only; media jobs wait up to 10 s for memory, then `503` + `Retry-After` | `attachments.enabled` |
| **Image / page indexing, visual recall** (colmodernvbert) | `features.vision.*` (`resources`) | `values-vision.yaml` | ~966 MB (+ ORT copy), conversion reserves ~1 GB, ~10.7 s per page on CPU, one page at a time | **A dedicated store: its own release** (own MinIO / bucket and volume); `config.tiered: "0"`; PNG only; not with the text models; one-way for v0.11 | `vision.enabled`, `scoring.late_interaction.lane` = `visual` |
| **Multi-vector records** | `features.records.*` (`maxVectors`, `maxBytes`) | `values-records.yaml` | extras stored beside the primary vector; default limits 4096 vectors / 8 MiB per record | Any store; at most 8 extra representations per record | `records.enabled` |
| **Late interaction** (colbert-small, MaxSim) | `features.lateInteraction.enabled` | `values-late-interaction.yaml` | colbert-small ~34 MB; steady recall p50 0.10 s at 1k, 0.23 s at 10k memories | **Fresh store**; `config.tiered: "0"` (`501` under `DAKERA_TIERED=1`); not with multilingual / vision; one-way for v0.11 | `scoring.late_interaction.enabled`, `.model_supported` |
| **RaBitQ search mode** | `features.rabitq.*` (`bits`) | `values-rabitq.yaml` | **Saves latency, not memory** (codes sit next to the float vectors, rebuilt after a restart) | Any store | `search_mode` = `rabitq` |
| **Model store** (`models list / pull / prune`, mirror, proxy, offline) | `models.*`, `features.prePull`, `features.persistModelCache`, `extraEnv` (`HF_ENDPOINT`, `HTTPS_PROXY`, `NO_PROXY`, `HF_HUB_OFFLINE`) | `values-air-gapped.yaml` | model cache PVC, 10Gi by default | `https://` proxy URLs are not supported | `/health/ready`, `/health` `degraded` |

```bash
# multilingual search on a fresh install (from a clone of this repository, for the example file)
helm install dakera oci://ghcr.io/dakera-ai/dakera-helm/dakera --version 0.12.0 -n dakera --create-namespace \
  --set dakera.rootApiKey=$(openssl rand -hex 32) --set minio.rootPassword=$(openssl rand -hex 16) \
  -f charts/dakera/examples/values-multilingual.yaml
# several combinable features: examples/values-combined.yaml (multilingual + multimodal + records + rabitq)
```

**What the chart does for you when a feature is on.**

- Renders the feature's variables into the ConfigMap (every name is one the server reads), so the models
  init container and the server see the same configuration. Empty values are left out: the server's default applies.
- **Refuses combinations the server cannot run**, with a message, instead of a pod that exits at startup:
  multilingual + lateInteraction (one embedding model per store); vision with multilingual or lateInteraction;
  multilingual, lateInteraction or vision while `dakera.config.tiered` is on (the tiered embedding engine pins
  `bge-large` and refuses late interaction); rabitq with `dakera.config.searchMode` changed.
- **Model cache.** While multilingual, lateInteraction, multimodal or vision is on, the model cache is a PVC
  (`dakera.models.persistence.size`, default `10Gi`: about 4.8 GB holds bge-m3, whisper, colmodernvbert and GLiNER
  with their ORT-format copies; `features.persistModelCache: false` keeps an emptyDir) and an init container runs
  `dakera models pull configured` (`features.prePull: false` or an explicit `dakera.models.pull` list overrides it),
  so the pod becomes ready with the models on disk. The PVC is ReadWriteOnce: one server pod.
- **Resources.** multimodal and vision replace `dakera.resources` with 500m / 1Gi requests and 4 cores / 8Gi
  limits (the measured configuration); `features.multimodal.resources=null` keeps `dakera.resources`. The other features
  have no measured resource figure: size from the guide, and measure on your data.

**Before you switch one on.**

- **Multilingual, late interaction and vision change the embedding model or the lane.** The store records its model and a
  pod with another one exits at startup (the log names both). Use a fresh store, or migrate: acknowledge the change for ONE
  rollout with `extraEnv` `DAKERA_ALLOW_MODEL_CHANGE=1`, pull the model, re-embed with
  `POST /admin/namespaces/migrate-dimensions` (`{"target_dimension": 1024, "reembed_same_dimension": true}` for
  bge-large to bge-m3), then remove it. Take a backup first. `dakera downgrade` (the `rollback` Job) refuses a
  store on bge-m3, colbert-small or the visual lane.
- **Multilingual**: `fulltextLanguage` applies to **new** namespace indexes; re-analyse an existing one with
  `POST /admin/fulltext/reindex {"namespace": "...", "rebuild": true}` (global admin key).
- **Vision**: deploy it as its own release (`helm install dakera-vision ...`): the agent namespaces hold page
  vectors, never put it over a text store.
- Check what a running server has on: `GET /v1/capabilities` (any key with Read scope) and `GET /health`.

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

## Observability

The server pod is annotated for Prometheus (`prometheus.io/scrape`, port 3000, path `/metrics`). The server's v0.12 alert
rules and dashboard are shipped as opt-in objects (off by default), both copied from the server repository, and every
expression and panel reads a metric the v0.12 server emits:

```yaml
monitoring:
  prometheusRule:            # needs the Prometheus Operator CRD
    enabled: true
    labels: {release: kube-prometheus-stack}   # what your Prometheus' ruleSelector matches
  grafanaDashboard:          # for Grafana's dashboard sidecar
    enabled: true
```

The rules (`dakera-signals`: config warnings, degraded components, WAL replay and write failures, memory read failures,
Redis cache failures, held cluster changes, failed model loads and backups, unreadable encrypted values; `dakera-service`: down,
5xx and 503 ratios, memory-budget refusals, cold-tier circuit and backlog, RocksDB write stop, dropped cluster changes,
storage write stalls, clock skew, corrupt records) include `DakeraDown`, which matches `job="dakera"`: name your scrape job
so, or edit the rule. About 25 Prometheus series per active agent: many thousands of agents make a large scrape.

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

## Publishing

Charts are released automatically on every push to `charts/` on `main` (v0.12.0 and later; `release/0.11` is a frozen snapshot and publishes nothing) via:
- `helm/chart-releaser-action` → GitHub Pages index: `https://dakera-ai.github.io/dakera-helm/`
- `helm push` → OCI: `oci://ghcr.io/dakera-ai/dakera-helm/dakera`

Push changes to `charts/` on `main` to trigger an automatic release.

---

## License

MIT — see [LICENSE](LICENSE)
