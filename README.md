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
| **Latest** | **v0.12.2** | **0.12.2** (and later 0.12.x) | `main` (this branch), the Helm repository and the OCI registry |
| Previous | v0.11.x (last: v0.11.108) | 0.11.x | the [`release/0.11`](https://github.com/Dakera-AI/dakera-helm/tree/release/0.11) branch |

`main` and the latest chart are **v0.12.2**. The v0.11 chart is kept on the
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
v0.11, v0.12.0 or v0.12.1 to v0.12.2: read [charts/dakera/CHANGELOG.md](charts/dakera/CHANGELOG.md)
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
  --version 0.12.2 \
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

### Upgrading from chart 0.12.1

Chart 0.12.2 deploys server 0.12.2 and Dashboard 0.5.1; nothing is migrated by hand. Back up first
(`POST /admin/backups`), then `helm upgrade`. Behaviour that changes (server
[UPGRADE.md, "Upgrading from v0.12.1 to v0.12.2"](https://github.com/Dakera-AI/dakera/blob/main/docs/v0.12/UPGRADE.md#upgrading-from-v0121-to-v0122)):

- **Sessions end after 4 hours without activity** (`DAKERA_SESSION_IDLE_TIMEOUT_SECS`, server default 14400).
  Sessions already open longer (orphans of crashed agents) are closed, with their summaries, on the first
  passes after the upgrade. An agent that keeps a session open while idle sends
  `POST /v1/sessions/{id}/touch` or starts it with `idle_timeout_secs: 0`. To keep the 0.12.1 behaviour:
  `--set-string dakera.config.sessionIdleTimeoutSecs=0`.
- **Keys:** prefix patterns `p*` in a key's `namespaces` (strict: `team-*` reaches `team-a`, not `team`). An
  entry ending in `*` on a key created before 0.12.2 stays inert until the key's namespaces are saved again
  (`PATCH /admin/keys/{key_id}`, or "Re-save to activate patterns" in the dashboard); `GET /v1/auth/whoami`
  lists it under `inert_namespaces`. Keys no longer need `_dakera_sessions`. Invalid entries are refused.
- **Stricter validation (400):** reserved `dakera-curated` tags and `_dakera_*` metadata keys from clients,
  `mem_s` + 24 hex ids, memory-shaped writes through the raw vector routes of an agent namespace, agent ids
  over 241 bytes, content over `DAKERA_MAX_MEMORY_CONTENT_BYTES` (100000 bytes) on update as well as store.
- **Storage:** the RocksDB hot tier writes binary records. Back to chart 0.12.1 / 0.12.0: nothing to do. Back
  to v0.11.108: the rollback Job with the 0.12.2 image rewrites them as JSON (see "Rolling back to v0.11").

New optional values (rendered only when set; empty = the server's default): `dakera.config.sessionIdleTimeoutSecs`,
`maxMemoryContentBytes`, `vectorCacheBytes`, `rocksdbRecordFormat` (see "Common Options" and values.yaml). Details:
[charts/dakera/CHANGELOG.md](charts/dakera/CHANGELOG.md).

### Upgrading from chart 0.12.0

What changed in server 0.12.1 (going to 0.12.2 from 0.12.0, the 0.12.1 notes above apply too); nothing is migrated by hand. Full-text indexes still on the v0.11
analyzer are re-analysed in the background at the first start, and a changed `DAKERA_MODEL` re-embeds the
store in the background. **Clusters:** every node now needs the same `DAKERA_CLUSTER_SECRET` (a node without
it exits with code 78) and the chart refuses cluster mode without it; switch all nodes in one window (see
"Cluster mode" below). Memory totals drop and session totals rise in the statistics endpoints. Details:
[charts/dakera/README.md, "Upgrading from chart 0.12.0"](charts/dakera/README.md#upgrading-from-chart-0120).

### Upgrading from chart 0.11.x

Tested from 0.11.107 (server 0.11.108) to 0.12.0 on one release (kind): `helm upgrade` switches the
Deployment from `RollingUpdate` to `Recreate`, keeps the data PVC `<fullname>-rocksdb` and the Secret
`<fullname>-secrets` (same objects, same UIDs), and the memories v0.11.108 stored are recalled by 0.12.0
(the pod was Ready 13 s after the upgrade).

**The built-in MinIO is new in 0.12.0.** Chart 0.11.107 rendered no MinIO although it pointed
`DAKERA_S3_ENDPOINT` at `<fullname>-minio:9000`, so a working 0.11 install has its own S3 service under that
name. With `minio.enabled: true` (the default) the upgrade then fails with `Service "<fullname>-minio" exists
and cannot be imported into the current release`. Keep your S3: turn the chart's MinIO off, point the
server at it and pass the credentials yourself (with MinIO off the chart's Secret no longer carries
`AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY`):

```yaml
minio:
  enabled: false
dakera:
  config:
    s3Endpoint: http://<fullname>-minio:9000      # what 0.11.107 used
  extraEnv:
    - name: AWS_ACCESS_KEY_ID
      valueFrom: {secretKeyRef: {name: <your-s3-secret>, key: AWS_ACCESS_KEY_ID}}
    - name: AWS_SECRET_ACCESS_KEY
      valueFrom: {secretKeyRef: {name: <your-s3-secret>, key: AWS_SECRET_ACCESS_KEY}}
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
| `dakera.config.sessionIdleTimeoutSecs` | `""` (server: `14400`) | `DAKERA_SESSION_IDLE_TIMEOUT_SECS`: sessions with no activity for this long are ended by the server; `"0"` = never (unless a session sets its own `idle_timeout_secs`); at most 30 days |
| `dakera.config.maxMemoryContentBytes` | `""` (server: `100000`) | `DAKERA_MAX_MEMORY_CONTENT_BYTES`: longest memory content in UTF-8 **bytes** (integer > 0) |
| `dakera.config.vectorCacheBytes` | `""` (server: `128MB`) | `DAKERA_VECTOR_CACHE_BYTES`: the in-process L1 **vector** cache, a byte size (`256MB`). Not `l1CacheSize` |
| `dakera.config.rocksdbRecordFormat` | `""` (server: `binary`) | `DAKERA_ROCKSDB_RECORD_FORMAT`: how the RocksDB hot tier writes new records, `binary` or `json` (both always read) |
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
| `mcp.enabled` | `false` | dakera-mcp speaks MCP over stdio only: as a pod it exits at once (CrashLoopBackOff, measured with 0.10.11). Run it next to the MCP client |
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
| **Multilingual** (bge-m3, per-language full-text, CJK bigrams, query languages, per-request `lang`) | `features.multilingual.*` (`fulltextLanguage`, `cjkBigrams`, `queryLang`, `maxSeqLength`) | `values-multilingual.yaml` | bge-m3 ~570 MB (+ ORT copy), CPU ONNX only, truncation 2048 tokens | Fresh store, or an existing one re-embedded in the background (0.12.1); `config.tiered: "0"`; not with late interaction / vision; one-way for v0.11 | `default_model` = `bge-m3` |
| **Attachments + speech to text** (Whisper, five models) | `features.multimodal.*` (`attachmentMaxBytes`, `memHighWaterFraction`, `resources`) | `values-multimodal.yaml` | see the model table (whisper-tiny.en ~151 MB); 8Gi / 4 cores (the measured configuration: 530 MiB anonymous with every model, +1.9 GiB image peak) | Any store; WAV only (multilingual by default, language auto-detected); media jobs wait up to 10 s for memory, then `503` + `Retry-After` | `attachments.enabled` |
| **Image / page indexing, visual recall** (colmodernvbert) | `features.vision.*` (`resources`) | `values-vision.yaml` | ~966 MB (+ ORT copy), conversion reserves ~1 GB, ~10.7 s per page on CPU, one page at a time | **A dedicated store: its own release** (own MinIO / bucket and volume); `config.tiered: "0"`; PNG only; not with the text models; one-way for v0.11 | `vision.enabled`, `scoring.late_interaction.lane` = `visual` |
| **Multi-vector records** | `features.records.*` (`maxVectors`, `maxBytes`) | `values-records.yaml` | extras stored beside the primary vector; default limits 4096 vectors / 8 MiB per record | Any store; at most 8 extra representations per record | `records.enabled` |
| **Late interaction** (colbert-small, MaxSim) | `features.lateInteraction.enabled` | `values-late-interaction.yaml` | colbert-small ~34 MB; steady recall p50 0.10 s at 1k, 0.23 s at 10k memories | **Fresh store**; `config.tiered: "0"` (`501` under `DAKERA_TIERED=1`); not with multilingual / vision; one-way for v0.11 | `scoring.late_interaction.enabled`, `.model_supported` |
| **RaBitQ search mode** | `features.rabitq.*` (`bits`) | `values-rabitq.yaml` | **Saves latency, not memory** (codes sit next to the float vectors, rebuilt after a restart) | Any store | `search_mode` = `rabitq` |
| **Model store** (`models list / pull / prune`, mirror, proxy, offline) | `models.*`, `features.prePull`, `features.persistModelCache`, `extraEnv` (`HF_ENDPOINT`, `HTTPS_PROXY`, `NO_PROXY`, `HF_HUB_OFFLINE`) | `values-air-gapped.yaml` | model cache PVC, 10Gi by default | `https://` proxy URLs are not supported | `/health/ready`, `/health` `degraded` |

```bash
# multilingual search on a fresh install (from a clone of this repository, for the example file)
helm install dakera oci://ghcr.io/dakera-ai/dakera-helm/dakera --version 0.12.2 -n dakera --create-namespace \
  --set dakera.rootApiKey=$(openssl rand -hex 32) --set minio.rootPassword=$(openssl rand -hex 16) \
  -f charts/dakera/examples/values-multilingual.yaml
# several combinable features: examples/values-combined.yaml (multilingual + multimodal + records + rabitq)
```

### Multilingual

bge-m3 (1024-d, multilingual, CPU ONNX only) with full-text stemming and stop words per language, character-bigram
indexing of Chinese / Japanese / Korean / Thai text, and dates and temporal expressions understood in seven query
languages (`en de fr es it pt nl`). Use it when agents store or search text in languages other than English.

```yaml
dakera:
  config: {tiered: "0"}              # the tiered embedding engine pins bge-large
  features:
    multilingual:
      enabled: true
      fulltextLanguage: de           # or multilingual (no stemming), zh, ja, ko, th, ...
      queryLang: auto                # en de fr es it pt nl, or auto (per query)
```

Requests may also send `"lang"`. On an existing store the change of model re-embeds it in the background (see below).
Verify: `default_model` is `bge-m3`, `fulltext_language` and `query_languages` on `/v1/capabilities`. Existing full-text
indexes built with another analyzer are re-analysed in the background at the next start. The model is ~570 MB, not in the image; truncation defaults to 2048 tokens
(`maxSeqLength`: it supports 8192, at about 4 GiB of attention scores per layer per row).

### Multimodal: attachments and speech to text

Files stored per agent and referenced from memories (`attachment_ref`, counted by quotas, backed up, replicated), and a
transcription job that turns a WAV recording into a memory. Without it the routes answer
`501 FEATURE_DISABLED`. Works on an existing store.

The speech-to-text model is `DAKERA_WHISPER_MODEL` (default `whisper-base`), set through `dakera.extraEnv`. **Behaviour change on upgrade:** the default speech model is `whisper-base` (multilingual, language auto-detected), not English-only `whisper-tiny.en`. A deployment that enables `features.multimodal` and sets no `DAKERA_WHISPER_MODEL` now transcribes with `whisper-base`; set `DAKERA_WHISPER_MODEL=whisper-tiny.en` through `dakera.extraEnv` to keep the lightest English model.


| Model | Languages | Role |
|---|---|---|
| `whisper-base` | Multilingual (about 99 languages), language auto-detected | The default; the recommended choice (74M parameters) |
| `whisper-tiny.en` | English | The lightest English model (39M) |
| `whisper-base.en` | English | Better English (74M) |
| `whisper-tiny` | Multilingual, language auto-detected | The lightest multilingual model (39M) |
| `whisper-small` | Multilingual, language auto-detected | The quality option (244M) |

Multilingual models detect the spoken language themselves and record it on the stored memory as its `lang`, so full-text
stemming, date parsing and bge-m3 multilingual embeddings work downstream; an explicit per-request `lang` overrides
detection. Models are SHA-pinned, `dakera models list|pull|prune|--bake` covers every variant (`dakera.models.pull`
names them), memory admission reserves each model's footprint, and idle models are unloaded.
<!-- TODO: add download size, memory and speed for whisper-base.en, whisper-tiny, whisper-base and whisper-small once measured. -->

```yaml
dakera:
  features:
    multimodal:
      enabled: true
      attachmentMaxBytes: 26214400   # the default, 25 MiB; DAKERA_MAX_BODY_SIZE (dakera.config.maxBodySize) also applies
  extraEnv:
    - name: DAKERA_WHISPER_MODEL     # optional; default whisper-base
      value: whisper-tiny.en         # whisper-base | whisper-tiny.en | whisper-base.en | whisper-tiny | whisper-small
```

Every media job reserves its estimated peak memory first (limit x 0.85), waits up to 10 s, then answers `503` +
`Retry-After`: clients retry. Jobs live in memory (a restart forgets their ids; the stored memory stays). Verify:
`attachments.enabled` and `attachments.transcription.model` on `/v1/capabilities`.

### Vision: image and page indexing, visual recall

`colmodernvbert` embeds PNG pages (`POST .../attachments/{ref}/index`) and recall over the pages embeds the query with the
model's text side (ViDoRe nDCG@5: TabFQuAD 0.643, Shift Project 0.7705). About 10.7 s per page on CPU, one page at a time; up to
2 500 pages wait, then `503`. **A store of its own**: the namespaces hold 128-d page vectors, so install it as its own release
(own MinIO / bucket and volume), never over a text store.

```yaml
dakera:
  config: {tiered: "0"}              # late interaction is refused under the tiered embedding engine
  features:
    vision: {enabled: true}
```

~966 MB (+ an ORT-format copy); the conversion reserves ~1 GB from the memory budget, which is why the init container pulls it
before the server starts. Verify: `vision.enabled`, `scoring.late_interaction.lane` = `visual`.

### Multi-vector records

`POST /v1/namespaces/{ns}/records`: one indexed vector plus up to 8 named extra representations (`dense`, `token_multivector`,
`patch_multivector`, stored as `f32`, `f16` or `i8`). Limits of one record's extras: 4096 vectors and 8 MiB (`maxVectors`,
`maxBytes`; over = `413`). No record delete route: delete through the vector routes. Works on an existing store.

```yaml
dakera:
  features:
    records: {enabled: true}
```

### Late interaction

`DAKERA_MODEL=colbert-small` (96-d token vectors, ~34 MB) with `DAKERA_SCORING_STRATEGY=late-interaction`: recall shortlists by
each memory's fixed-dimensional encoding and reranks with MaxSim per token. Opt-in because on the same LoCoMo harness it scored
below bge-large (better only on multi-hop questions). Steady recall p50 0.10 s at 1k memories, 0.23 s at 10k; right after a bulk
ingest the dense first stage serves while the late-interaction stage rebuilds. Needs `config.tiered: "0"` (`501` otherwise) and a
fresh store.

```yaml
dakera:
  config: {tiered: "0"}
  features:
    lateInteraction: {enabled: true}
```

Verify: `scoring.late_interaction.enabled` and `.model_supported`; `late_interaction_stats.reranked` > 0 once searches ran.

### RaBitQ search mode

`DAKERA_SEARCH_MODE=rabitq` walks the HNSW graph on RaBitQ codes and re-ranks the shortlist with exact float distances; `bits` 1 to 8
(4 is the usual quality point). **A latency option: it saves no memory** (the codes sit next to the float vectors and are rebuilt
after a restart). Works on an existing store; remove it to go back.

```yaml
dakera:
  features:
    rabitq: {enabled: true, bits: "4"}
```

### Model store, mirrors, proxies and offline

See "Models, air-gapped installs" below: `dakera.models.*`, `features.prePull`, and `extraEnv` for `HF_ENDPOINT` (a Hub mirror),
`HTTPS_PROXY` / `NO_PROXY` (`http://` or `socks5h://`, never `https://`), `HF_HUB_OFFLINE=1`. `dakera models list / pull / prune` run
in the pod (`kubectl exec deploy/<release>-dakera -- dakera models list`).


### What the chart does for you when a feature is on

- Renders the feature's variables into the ConfigMap (every name is one the server reads), so the models
  init container and the server see the same configuration. Empty values are left out: the server's default applies.
- **Refuses combinations the server cannot run**, with a message, instead of a pod that exits at startup:
  multilingual + lateInteraction (one embedding model per store); vision with multilingual or lateInteraction;
  multilingual, lateInteraction or vision while `dakera.config.tiered` is on (the tiered embedding engine pins
  `bge-large` and refuses late interaction); rabitq with `dakera.config.searchMode` changed.
- **Model cache.** While multilingual, lateInteraction, multimodal or vision is on, the model cache is a PVC
  (`dakera.models.persistence.size`, default `10Gi`: measured: bge-m3 1.1 GB, whisper 367 MB, colmodernvbert 1.9 GB with their ORT copies; GLiNER ~782 MB to download, not measured converted; 10Gi holds all four; `features.persistModelCache: false` keeps an emptyDir) and an init container runs
  `dakera models pull configured` (`features.prePull: false` or an explicit `dakera.models.pull` list overrides it),
  so the pod becomes ready with the models on disk. The PVC is ReadWriteOnce: one server pod.
- **Resources.** multimodal and vision replace `dakera.resources` with 500m / 1Gi requests and 4 cores / 8Gi
  limits (the measured configuration); `features.multimodal.resources=null` keeps `dakera.resources`. The other features
  have no measured resource figure: size from the guide, and measure on your data.

### Before you switch one on

- **Multilingual, late interaction and vision change the embedding model or the lane.** The store records its model.
  Take a backup first.
  - **Multilingual** on an existing store (0.12.1): the pod starts and re-embeds the store with bge-m3 in the background,
    one agent namespace at a time; until its turn each namespace is answered with the model its memories are in, so
    recall stays correct. Progress: `/health` `embedding_model_change`, `/v1/capabilities` `reembed_pending`. No flag.
  - **Late interaction and vision** are not re-embedded in the background (nor is a change under `DAKERA_TIERED=1`, or
    from a recorded model this build does not know): a pod with another model exits at startup (the log names both).
    Use a fresh store, or migrate: acknowledge the change for ONE rollout with `extraEnv` `DAKERA_ALLOW_MODEL_CHANGE=1`,
    pull the model, re-embed with `POST /admin/namespaces/migrate-dimensions`
    (`{"target_dimension": <dim>, "reembed_same_dimension": true}`), then remove it.
  - `dakera downgrade` (the `rollback` Job) refuses a store on bge-m3, colbert-small or the visual lane.
- **Multilingual**: `fulltextLanguage` applies to every index; an existing one built with another analyzer is
  re-analysed in the background at the next start (0.12.1).
- **Vision**: deploy it as its own release (`helm install dakera-vision ...`): the agent namespaces hold page
  vectors, never put it over a text store.
- Check what a running server has on: `GET /v1/capabilities` (any key with Read scope) and `GET /health`.

## Models, air-gapped installs

The image ships `bge-large` and the reranker in its own model store; they load
in seconds with no network. Any other model (`DAKERA_MODEL=bge-m3`, whisper, the
vision model, ...) downloads into the model cache (`/app/models`) on first use.
The REST port answers while models load: `/health/live` is 200 from the start,
`/health/ready` is 503 until storage and the embedding engine are up. Measured on
kind with the images already on the node: a default install was Ready 24 s after
`helm install` (MinIO start included); with `values-multilingual.yaml` the models
init container pulled bge-m3 (570 MB, plus its ORT copy) in 11 s and the pod was
Ready 25 s after install.

- Pre-pull before the pod serves: `dakera.models.pull: [configured]` (or a list of names).
- Keep the cache across pod restarts: `dakera.models.persistence.enabled: true`.
- Air-gapped: seed that volume from a host that can reach the Hub
  (`docker run --rm -v <volume>:/app/models ghcr.io/dakera-ai/dakera:0.12.2 models pull --dir /app/models <model>`,
  then mount it as the PVC), and use only models the image or the volume holds.
  See the server's [models-and-docker.md](https://github.com/Dakera-AI/dakera/blob/main/docs/models-and-docker.md).

## Observability

The server pod is annotated for Prometheus (`prometheus.io/scrape`, port 3000, path `/metrics`). The server's v0.12 alert
rules and dashboard are shipped as opt-in objects (off by default), both copied from the server repository, and every
expression and panel reads a metric the v0.12 server emits (checked against a running 0.12.0 server; the files and the
metrics are unchanged in 0.12.1 and 0.12.2, which only adds metrics such as `dakera_sessions_auto_ended_total`; many appear in `/metrics` only once their event has happened: failures, cluster,
encryption, Redis, media jobs):

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
its data root: one release of this chart is one node. Give every release the same
secret (the chart does not generate one: a value generated per release would differ
from node to node).

From 0.12.1 the secret is required on every cluster node, fresh or upgraded: a node
without it exits with code 78, and the chart refuses to render cluster mode without
it. Nodes with and without the secret do not see each other, so a cluster that runs
without one (0.12.0, or v0.11.108) switches in one window: scale every release's
server to 0, then `helm upgrade` each with the secret. The rolling alternative and
the checks: [charts/dakera/README.md, "Cluster mode"](charts/dakera/README.md#cluster-mode)
and the server's
[UPGRADE.md, "Cluster secret (required from 0.12.1)"](https://github.com/Dakera-AI/dakera/blob/main/docs/v0.12/UPGRADE.md#cluster-secret-required-from-0121).

## Rolling back to v0.11

Going back from v0.12 to v0.11.108 is supported (any v0.11 embedding model,
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
kubectl -n dakera logs job/<fullname>-downgrade   # the log, then the JSON report (the last {...} block)
# 3. only when the Job completed (exit 0): go back to the v0.11 chart
helm upgrade dakera oci://ghcr.io/dakera-ai/dakera-helm/dakera --version 0.11.107 -n dakera \
  --set dakera.image.tag=0.11.108 <your v0.11 values>
```

Run the Job with the **0.12.2 image** (the default: the server's image; leave `rollback.image` empty).
0.12.2 writes binary RocksDB hot-tier records, and its `dakera downgrade` rewrites them as JSON before
v0.11.108 can read them (report field `hot_tier_records_rewritten_as_json`); an older v0.12 image would not.
v0.11.108 cannot address namespace names or record ids longer than 200 bytes that 0.12.2 stored (server
[rollback.md](https://github.com/Dakera-AI/dakera/blob/main/docs/v0.12/rollback.md), row 23b). Going back
to chart 0.12.1 or 0.12.0 needs no Job: they read binary records.

Exit code `0` = the data is v0.11.108's; `1` = not yet (do **not** start v0.11,
fix the cause and rerun); `78` = refused, nothing changed (a server still runs on
the data, a v0.12-only feature, or no data found). `kubectl logs` shows the
container's stderr (the log) and stdout (the report) together. Tested on kind:
with the server running the Job failed with exit 78; scaled to 0 it completed in
3 s (`completed: true`), and chart 0.11.107 with server 0.11.108 then recalled
the data. Clusters: roll back the whole cluster,
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
