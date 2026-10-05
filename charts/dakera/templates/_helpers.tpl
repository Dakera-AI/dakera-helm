{{/*
Expand the name of the chart.
*/}}
{{- define "dakera.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
*/}}
{{- define "dakera.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "dakera.labels" -}}
helm.sh/chart: {{ printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
app.kubernetes.io/name: {{ include "dakera.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "dakera.selectorLabels" -}}
app.kubernetes.io/name: {{ include "dakera.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
MCP selector labels
*/}}
{{- define "dakera.mcp.selectorLabels" -}}
app.kubernetes.io/name: {{ include "dakera.name" . }}-mcp
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Dashboard selector labels
*/}}
{{- define "dakera.dashboard.selectorLabels" -}}
app.kubernetes.io/name: {{ include "dakera.name" . }}-dashboard
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
MinIO selector labels
*/}}
{{- define "dakera.minio.selectorLabels" -}}
app.kubernetes.io/name: {{ include "dakera.name" . }}-minio
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
DAKERA_CLUSTER_SECRET from a Secret the operator manages (cluster.existingSecret).
The chart-managed variant (cluster.secret) is a key of <fullname>-secrets, which
the server container loads with envFrom. Renders nothing when neither is set.
*/}}
{{- define "dakera.clusterSecretEnv" -}}
{{- with .Values.dakera.cluster.existingSecret }}
{{- if .name }}
- name: DAKERA_CLUSTER_SECRET
  valueFrom:
    secretKeyRef:
      name: {{ .name | quote }}
      key: {{ .key | default "DAKERA_CLUSTER_SECRET" | quote }}
{{- end }}
{{- end }}
{{- end }}

{{/*
"true" when dakera.extraEnv switches cluster mode on: DAKERA_CLUSTER_MODE set to a value the
server reads as on (1, true, yes, on; any case), or set with valueFrom, which the chart cannot
read. The last entry wins, as in Kubernetes.
*/}}
{{- define "dakera.clusterMode" -}}
{{- $on := false -}}
{{- range .Values.dakera.extraEnv -}}
{{- if eq (toString .name) "DAKERA_CLUSTER_MODE" -}}
{{- if .valueFrom -}}
{{- $on = true -}}
{{- else -}}
{{- $on = has (lower (trim (toString .value))) (list "1" "true" "yes" "on") -}}
{{- end -}}
{{- end -}}
{{- end -}}
{{- if $on -}}true{{- end -}}
{{- end }}

{{/*
Check DAKERA_CLUSTER_SECRET. From server 0.12.1 every cluster node needs it (at least 16
characters after trimming, the same on every node) or exits with code 78. The chart does not
generate one: one release is one node, so a secret generated per release would differ from
node to node and the nodes would not see each other. Rendered, and so evaluated, by
configmap.yaml.
*/}}
{{- define "dakera.cluster.validate" -}}
{{- $c := .Values.dakera.cluster -}}
{{- $fromEnv := false -}}
{{- range .Values.dakera.extraEnv -}}
{{- if eq (toString .name) "DAKERA_CLUSTER_SECRET" -}}
{{- $fromEnv = true -}}
{{- if and (not .valueFrom) (lt (len (trim (toString (.value | default "")))) 16) -}}
{{- fail "DAKERA_CLUSTER_SECRET in dakera.extraEnv must be at least 16 characters (the server trims it first)" -}}
{{- end -}}
{{- end -}}
{{- end -}}
{{- if and $c.secret $c.existingSecret.name -}}
{{- fail "set only one of dakera.cluster.secret and dakera.cluster.existingSecret.name" -}}
{{- end -}}
{{- if and $fromEnv (or $c.secret $c.existingSecret.name) -}}
{{- fail "DAKERA_CLUSTER_SECRET is set in dakera.extraEnv and in dakera.cluster: set it one way" -}}
{{- end -}}
{{- if and $c.secret (lt (len (trim (toString $c.secret))) 16) -}}
{{- fail "dakera.cluster.secret must be at least 16 characters (DAKERA_CLUSTER_SECRET; the server trims it first)" -}}
{{- end -}}
{{- if and (eq (include "dakera.clusterMode" .) "true") (not (or $c.secret $c.existingSecret.name $fromEnv)) -}}
{{- fail (printf "cluster mode (DAKERA_CLUSTER_MODE in dakera.extraEnv) needs DAKERA_CLUSTER_SECRET: from server 0.12.1 a cluster node without it exits with code 78, upgraded or not. Give every node (every release) the same value of at least 16 characters (openssl rand -hex 32): dakera.cluster.existingSecret (name, key) for a Secret you manage, or dakera.cluster.secret (stored in %s-secrets, needs dakera.rootApiKey). If you created %s-secrets yourself with the key DAKERA_CLUSTER_SECRET, set dakera.cluster.existingSecret.name=%s-secrets. Nodes with and without the secret do not see each other: see the chart README, \"Cluster mode\"" (include "dakera.fullname" .) (include "dakera.fullname" .) (include "dakera.fullname" .)) -}}
{{- end -}}
{{- end }}

{{/*
v0.12 features (dakera.features.*): every one is off by default; with all of them off
nothing below renders anything and the chart behaves as before.
*/}}

{{/* "true" when a feature that needs a model outside the image is enabled. */}}
{{- define "dakera.featuresNeedModels" -}}
{{- $f := .Values.dakera.features -}}
{{- if or $f.multilingual.enabled $f.lateInteraction.enabled $f.multimodal.enabled $f.vision.enabled -}}true{{- end -}}
{{- end }}

{{/* "true" when the model cache must be a PVC (explicitly, or because a feature needs models). */}}
{{- define "dakera.modelsPersist" -}}
{{- if or .Values.dakera.models.persistence.enabled (and (eq (include "dakera.featuresNeedModels" .) "true") .Values.dakera.features.persistModelCache) -}}true{{- end -}}
{{- end }}

{{/*
Refuse combinations the server cannot run (a clear message instead of a pod that exits at
startup). Rendered, and so evaluated, by configmap.yaml.
*/}}
{{- define "dakera.features.validate" -}}
{{- $f := .Values.dakera.features -}}
{{- $tiered := lower (toString .Values.dakera.config.tiered) -}}
{{- $tieredOn := or (eq $tiered "1") (eq $tiered "true") -}}
{{- if and $f.multilingual.enabled $f.lateInteraction.enabled }}
{{- fail "dakera.features.multilingual (DAKERA_MODEL=bge-m3) and dakera.features.lateInteraction (DAKERA_MODEL=colbert-small) are exclusive: a store has one embedding model" }}
{{- end }}
{{- if and $f.vision.enabled (or $f.multilingual.enabled $f.lateInteraction.enabled) }}
{{- fail "dakera.features.vision is a store of its own (its namespaces hold 128-d page vectors): do not combine it with multilingual or lateInteraction; install it as its own release" }}
{{- end }}
{{- if and $tieredOn (or $f.multilingual.enabled $f.lateInteraction.enabled $f.vision.enabled) }}
{{- fail "dakera.features.multilingual / lateInteraction / vision need dakera.config.tiered=\"0\": the tiered embedding engine (DAKERA_TIERED=1) always embeds with bge-large, ignores DAKERA_MODEL and refuses late interaction" }}
{{- end }}
{{- if and $f.rabitq.enabled (ne (toString .Values.dakera.config.searchMode) "hybrid") }}
{{- fail "dakera.features.rabitq sets DAKERA_SEARCH_MODE=rabitq: leave dakera.config.searchMode at its default (hybrid)" }}
{{- end }}
{{- if and $f.rabitq.bits (not $f.rabitq.enabled) }}
{{- fail "dakera.features.rabitq.bits only applies with dakera.features.rabitq.enabled=true" }}
{{- end }}
{{- end }}

{{/*
The environment of the enabled features, as ConfigMap data (key: "value"). Empty values are
left out, so the server's own default applies. Every name is a variable the server reads
(crates/config/src/known_env.rs).
*/}}
{{- define "dakera.features.env" -}}
{{- $f := .Values.dakera.features -}}
{{- if $f.multilingual.enabled }}
DAKERA_MODEL: "bge-m3"
{{- with $f.multilingual.fulltextLanguage }}
DAKERA_FULLTEXT_LANGUAGE: {{ . | quote }}
{{- end }}
{{- with $f.multilingual.cjkBigrams }}
DAKERA_FULLTEXT_CJK_BIGRAMS: {{ . | quote }}
{{- end }}
{{- with $f.multilingual.queryLang }}
DAKERA_QUERY_LANG: {{ . | quote }}
{{- end }}
{{- with $f.multilingual.maxSeqLength }}
DAKERA_MAX_SEQ_LENGTH: {{ . | quote }}
{{- end }}
{{- end }}
{{- if $f.lateInteraction.enabled }}
DAKERA_MODEL: "colbert-small"
{{- end }}
{{- if or $f.lateInteraction.enabled $f.vision.enabled }}
DAKERA_SCORING_STRATEGY: "late-interaction"
{{- end }}
{{- if or $f.multimodal.enabled $f.vision.enabled }}
DAKERA_ATTACHMENTS: "1"
{{- with $f.multimodal.attachmentMaxBytes }}
DAKERA_ATTACHMENT_MAX_BYTES: {{ . | quote }}
{{- end }}
{{- with $f.multimodal.memHighWaterFraction }}
DAKERA_MEM_HIGH_WATER_FRACTION: {{ . | quote }}
{{- end }}
{{- end }}
{{- if $f.vision.enabled }}
DAKERA_VISION: "1"
{{- end }}
{{- if $f.records.enabled }}
DAKERA_RECORDS: "1"
{{- with $f.records.maxVectors }}
DAKERA_RECORD_MAX_VECTORS: {{ . | quote }}
{{- end }}
{{- with $f.records.maxBytes }}
DAKERA_RECORD_MAX_BYTES: {{ . | quote }}
{{- end }}
{{- end }}
{{- if $f.rabitq.enabled }}
{{- with $f.rabitq.bits }}
DAKERA_RABITQ_BITS: {{ . | quote }}
{{- end }}
{{- end }}
{{- end }}

{{/* DAKERA_SEARCH_MODE: rabitq when that feature is on, else dakera.config.searchMode. */}}
{{- define "dakera.searchMode" -}}
{{- if .Values.dakera.features.rabitq.enabled -}}rabitq{{- else -}}{{ .Values.dakera.config.searchMode }}{{- end -}}
{{- end }}

{{/*
The server container's resources: the vision / multimodal feature's own block when that
feature is enabled and sets one (the measured configuration is 4 cores / 8 GiB), else
dakera.resources.
*/}}
{{- define "dakera.serverResources" -}}
{{- $f := .Values.dakera.features -}}
{{- if and $f.vision.enabled $f.vision.resources -}}
{{- toYaml $f.vision.resources -}}
{{- else if and $f.multimodal.enabled $f.multimodal.resources -}}
{{- toYaml $f.multimodal.resources -}}
{{- else -}}
{{- toYaml .Values.dakera.resources -}}
{{- end -}}
{{- end }}
