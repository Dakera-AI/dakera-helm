#!/usr/bin/env bash
# Validate the chart: lint and render the defaults, every example values file (each v0.12
# feature and their combinations), the opt-in monitoring objects, and check that the
# combinations the server cannot run are refused with a message.
# Usage: scripts/validate-chart.sh            (HELM=/path/to/helm to choose the binary)
set -euo pipefail
# `grep -q` at the end of a pipe exits at the first match: with pipefail, a writer still
# writing (helm template, a long manifest) then dies of SIGPIPE (141) and fails the script.
# grep_q reads all of its input.
grep_q() { grep "$@" >/dev/null; }
HELM=${HELM:-helm}
CHART=charts/dakera
REQ=(--set dakera.rootApiKey=ci-lint --set minio.rootPassword=ci-lint)
fail=0

echo "== helm lint (defaults)"
"$HELM" lint "$CHART" "${REQ[@]}"

echo "== helm template (defaults): no v0.12 feature variable is rendered"
"$HELM" template r "$CHART" "${REQ[@]}" > /tmp/chart-default.yaml
for v in DAKERA_MODEL DAKERA_ATTACHMENTS DAKERA_VISION DAKERA_RECORDS DAKERA_SCORING_STRATEGY DAKERA_RABITQ_BITS \
         DAKERA_FULLTEXT_LANGUAGE DAKERA_QUERY_LANG; do
  if grep -q "$v" /tmp/chart-default.yaml; then echo "FAIL: $v rendered with every feature off"; fail=1; fi
done
# The optional 0.12.2 settings are left out unless set (the server's defaults apply).
for v in DAKERA_SESSION_IDLE_TIMEOUT_SECS DAKERA_MAX_MEMORY_CONTENT_BYTES DAKERA_VECTOR_CACHE_BYTES \
         DAKERA_ROCKSDB_RECORD_FORMAT; do
  if grep -q "$v" /tmp/chart-default.yaml; then echo "FAIL: $v rendered while unset"; fail=1; fi
done
if grep -q "initContainers" /tmp/chart-default.yaml; then echo "FAIL: init container rendered with every feature off"; fail=1; fi

for f in "$CHART"/examples/values-*.yaml; do
  echo "== lint + template: $f"
  "$HELM" lint "$CHART" "${REQ[@]}" -f "$f"
  "$HELM" template r "$CHART" "${REQ[@]}" -f "$f" > /dev/null
done

echo "== monitoring objects"
"$HELM" lint "$CHART" "${REQ[@]}" --set monitoring.prometheusRule.enabled=true --set monitoring.grafanaDashboard.enabled=true
"$HELM" template r "$CHART" "${REQ[@]}" --set monitoring.prometheusRule.enabled=true --set monitoring.grafanaDashboard.enabled=true \
  | grep_q "kind: PrometheusRule"

echo "== server 0.12.2 settings: rendered when set, 0 kept, numbers from a values file as integers"
OPT=(--set dakera.config.sessionIdleTimeoutSecs=0 --set dakera.config.maxMemoryContentBytes=200000
     --set dakera.config.vectorCacheBytes=256MB --set dakera.config.rocksdbRecordFormat=json)
"$HELM" lint "$CHART" "${REQ[@]}" "${OPT[@]}"
"$HELM" template r "$CHART" "${REQ[@]}" "${OPT[@]}" --show-only templates/configmap.yaml > /tmp/chart-opt.yaml
for kv in 'DAKERA_SESSION_IDLE_TIMEOUT_SECS: "0"' 'DAKERA_MAX_MEMORY_CONTENT_BYTES: "200000"' \
          'DAKERA_VECTOR_CACHE_BYTES: "256MB"' 'DAKERA_ROCKSDB_RECORD_FORMAT: "json"'; do
  grep -qF "$kv" /tmp/chart-opt.yaml || { echo "FAIL: $kv not rendered"; fail=1; }
done
printf 'dakera:\n  config:\n    sessionIdleTimeoutSecs: 14400\n    vectorCacheBytes: 268435456\n' > /tmp/chart-opt-values.yaml
"$HELM" template r "$CHART" "${REQ[@]}" -f /tmp/chart-opt-values.yaml --show-only templates/configmap.yaml > /tmp/chart-opt.yaml
for kv in 'DAKERA_SESSION_IDLE_TIMEOUT_SECS: "14400"' 'DAKERA_VECTOR_CACHE_BYTES: "268435456"'; do
  grep -qF "$kv" /tmp/chart-opt.yaml || { echo "FAIL: $kv not rendered from a values file"; fail=1; }
done

echo "== server 0.12.3 settings: left out unless set, rendered when set"
LATER_VARS="DAKERA_HTTP_HEADER_READ_TIMEOUT_SECS DAKERA_NEIGHBORHOOD_MODE DAKERA_NEIGHBORHOOD_EVENT_TIME DAKERA_RECALL_RANK_DEPTH
  DAKERA_RECALL_COLLAPSE_DERIVED DAKERA_RECALL_EXCLUDE_SUMMARIES DAKERA_RECALL_SESSION_CAP DAKERA_SENTENCE_DECOMP
  DAKERA_SUPERSEDES_EVENT_TIME DAKERA_MAX_CONNECTIONS DAKERA_SHUTDOWN_DRAIN_SECS DAKERA_ALLOWED_HOSTS"
for v in $LATER_VARS; do
  if grep -q "$v" /tmp/chart-default.yaml; then echo "FAIL: $v rendered while unset (a 0.12.2 image would report it)"; fail=1; fi
done
NEW=(--set-string dakera.config.httpHeaderReadTimeoutSecs=75 --set dakera.config.neighborhoodMode=separate
     --set dakera.config.neighborhoodEventTime=true --set-string dakera.config.recallRankDepth=20
     --set dakera.config.recallCollapseDerived=true --set dakera.config.recallExcludeSummaries=true
     --set-string dakera.config.recallSessionCap=0 --set dakera.config.sentenceDecomp=false
     --set-string dakera.config.supersedesEventTime=0 --set-string dakera.config.maxConnections=20000
     --set-string dakera.config.shutdownDrainSecs=10 --set dakera.config.allowedHosts=dakera.example.test)
"$HELM" lint "$CHART" "${REQ[@]}" "${NEW[@]}"
"$HELM" template r "$CHART" "${REQ[@]}" "${NEW[@]}" --show-only templates/configmap.yaml > /tmp/chart-new.yaml
for kv in 'DAKERA_HTTP_HEADER_READ_TIMEOUT_SECS: "75"' 'DAKERA_NEIGHBORHOOD_MODE: "separate"' \
          'DAKERA_NEIGHBORHOOD_EVENT_TIME: "true"' 'DAKERA_RECALL_RANK_DEPTH: "20"' 'DAKERA_RECALL_COLLAPSE_DERIVED: "true"' \
          'DAKERA_RECALL_EXCLUDE_SUMMARIES: "true"' 'DAKERA_RECALL_SESSION_CAP: "0"' 'DAKERA_SENTENCE_DECOMP: "false"' \
          'DAKERA_SUPERSEDES_EVENT_TIME: "0"' 'DAKERA_MAX_CONNECTIONS: "20000"' 'DAKERA_SHUTDOWN_DRAIN_SECS: "10"' \
          'DAKERA_ALLOWED_HOSTS: "dakera.example.test"'; do
  grep -qF "$kv" /tmp/chart-new.yaml || { echo "FAIL: $kv not rendered"; fail=1; }
done

echo "== hardening: read-only root, no service-account token, MinIO NetworkPolicy, probe timeouts"
server=$(awk 'BEGIN{RS="\n---\n"} /kind: Deployment/ && /component: server/' /tmp/chart-default.yaml)
printf '%s' "$server" | grep_q 'readOnlyRootFilesystem: true' || { echo "FAIL: server root filesystem not read-only"; fail=1; }
printf '%s' "$server" | grep_q 'timeoutSeconds: 5' || { echo "FAIL: server probes without timeoutSeconds"; fail=1; }
pods=$(grep -c '^kind: Deployment' /tmp/chart-default.yaml)
tokens=$(grep -c 'automountServiceAccountToken: false' /tmp/chart-default.yaml)
[ "$pods" = "$tokens" ] || { echo "FAIL: $tokens of $pods Deployments turn the service-account token off"; fail=1; }
grep -q '^kind: NetworkPolicy' /tmp/chart-default.yaml || { echo "FAIL: MinIO NetworkPolicy not rendered"; fail=1; }
if "$HELM" template r "$CHART" "${REQ[@]}" --set minio.enabled=false --set dakera.config.s3Endpoint=https://s3.example.test | grep_q '^kind: NetworkPolicy'; then
  echo "FAIL: NetworkPolicy rendered without the built-in MinIO"; fail=1
fi
echo "== document import: rendered when set, left out by default; ingress accepts 25 MiB bodies"
grep -q 'DAKERA_DOCUMENT' /tmp/chart-default.yaml && { echo "FAIL: a DAKERA_DOCUMENT* variable rendered while unset"; fail=1; }
"$HELM" template r "$CHART" "${REQ[@]}" --set dakera.config.documents.enabled=false --set-string dakera.config.documents.maxBytes=52428800 \
  --set-string dakera.config.documents.chunkTokens=512 --set-string dakera.config.documents.extractConcurrency=1 \
  --show-only templates/configmap.yaml > /tmp/chart-docs.yaml
for kv in 'DAKERA_DOCUMENTS: "false"' 'DAKERA_DOCUMENT_MAX_BYTES: "52428800"' 'DAKERA_DOCUMENT_CHUNK_TOKENS: "512"' \
          'DAKERA_DOCUMENT_EXTRACT_CONCURRENCY: "1"'; do
  grep -qF "$kv" /tmp/chart-docs.yaml || { echo "FAIL: $kv not rendered"; fail=1; }
done
"$HELM" template r "$CHART" "${REQ[@]}" --set ingress.enabled=true --set ingress.apiHost=a.example.test --show-only templates/ingress.yaml \
  | grep_q -F 'nginx.ingress.kubernetes.io/proxy-body-size: 500m' || { echo "FAIL: ingress without proxy-body-size"; fail=1; }

echo "== dashboard 0.5.2: uid 10001, read-only root with a /tmp emptyDir, trusted proxies when set"
dashdep=$(awk 'BEGIN{RS="\n---\n"} /kind: Deployment/ && /component: dashboard/' /tmp/chart-default.yaml)
for want in 'runAsUser: 10001' 'readOnlyRootFilesystem: true' 'mountPath: /tmp' 'emptyDir: {}'; do
  printf '%s' "$dashdep" | grep_q -F "$want" || { echo "FAIL: dashboard: $want missing"; fail=1; }
done
printf '%s' "$dashdep" | grep_q 'DAKERA_TRUSTED_PROXIES' && { echo "FAIL: DAKERA_TRUSTED_PROXIES rendered while unset"; fail=1; }
"$HELM" template r "$CHART" "${REQ[@]}" --set dashboard.trustedProxies='10.0.0.0/8 172.16.0.0/12' \
  | grep -A1 'name: DAKERA_TRUSTED_PROXIES' | grep_q -F '"10.0.0.0/8 172.16.0.0/12"' || { echo "FAIL: trustedProxies not rendered"; fail=1; }
echo "== grace period follows terminationGracePeriodSeconds; a long drain needs a longer one"
printf '%s' "$server" | grep_q 'terminationGracePeriodSeconds: 30' || { echo "FAIL: server grace period not 30"; fail=1; }
"$HELM" template r "$CHART" "${REQ[@]}" --set-string dakera.config.shutdownDrainSecs=60 --set dakera.terminationGracePeriodSeconds=80 > /dev/null \
  || { echo "FAIL: drain 60 with grace 80 refused"; fail=1; }

echo "== persistence off: the data root is an emptyDir (writable with the read-only root)"
"$HELM" template r "$CHART" "${REQ[@]}" --set dakera.persistence.enabled=false --show-only templates/deployment.yaml \
  | awk 'BEGIN{RS="\n---\n"} /component: server/' | grep -A2 -- '- name: data$' | grep_q 'emptyDir' \
  || { echo "FAIL: no data volume with persistence off"; fail=1; }
echo "== existingSecret: every reference uses it, the chart creates no Secret"
"$HELM" template r "$CHART" --set dakera.existingSecret=my-dakera --set rollback.enabled=true > /tmp/chart-es.yaml
grep -q 'r-dakera-secrets' /tmp/chart-es.yaml && { echo "FAIL: <release>-secrets still referenced with existingSecret"; fail=1; }
grep -q '^kind: Secret' /tmp/chart-es.yaml && { echo "FAIL: a Secret rendered with existingSecret"; fail=1; }
[ "$(grep -c 'name: my-dakera' /tmp/chart-es.yaml)" -ge 3 ] || { echo "FAIL: existingSecret not referenced by server, MinIO and rollback Job"; fail=1; }

echo "== refused combinations"
expect_refusal() {
  local why=$1; shift
  if "$HELM" template r "$CHART" "${REQ[@]}" "$@" > /dev/null 2>/tmp/chart-err.txt; then
    echo "FAIL: accepted ($why): $*"; fail=1
  else
    echo "ok: refused ($why)"
  fi
}
expect_refusal "multilingual under DAKERA_TIERED=1"      --set dakera.features.multilingual.enabled=true
expect_refusal "late interaction under DAKERA_TIERED=1"  --set dakera.features.lateInteraction.enabled=true
expect_refusal "vision under DAKERA_TIERED=1"            --set dakera.features.vision.enabled=true
expect_refusal "multilingual + late interaction"         --set dakera.features.multilingual.enabled=true --set dakera.features.lateInteraction.enabled=true --set dakera.config.tiered=0
expect_refusal "vision + multilingual"                   --set dakera.features.vision.enabled=true --set dakera.features.multilingual.enabled=true --set dakera.config.tiered=0
expect_refusal "rabitq with another search mode"         --set dakera.features.rabitq.enabled=true --set dakera.config.searchMode=float
expect_refusal "rabitq bits without rabitq"              --set dakera.features.rabitq.bits=4
expect_refusal "rabitq bits out of range"                --set dakera.features.rabitq.enabled=true --set dakera.features.rabitq.bits=9
# Values the 0.12.2 server refuses to boot on.
expect_refusal "memory content limit 0"                  --set dakera.config.maxMemoryContentBytes=0
expect_refusal "unknown record format"                   --set dakera.config.rocksdbRecordFormat=yaml
expect_refusal "vector cache not a byte size"            --set dakera.config.vectorCacheBytes=lots
expect_refusal "idle timeout not a number of seconds"    --set dakera.config.sessionIdleTimeoutSecs=4h
expect_refusal "header timeout 0"                       --set-string dakera.config.httpHeaderReadTimeoutSecs=0
expect_refusal "header timeout over a day"              --set dakera.config.httpHeaderReadTimeoutSecs=86401
expect_refusal "unknown neighbourhood mode"             --set dakera.config.neighborhoodMode=both
expect_refusal "rank depth 0"                           --set-string dakera.config.recallRankDepth=0
expect_refusal "rank depth over 1000"                   --set-string dakera.config.recallRankDepth=1001
expect_refusal "flag not a boolean"                     --set dakera.config.sentenceDecomp=maybe
expect_refusal "rootApiKey and existingSecret"          --set dakera.existingSecret=mine
expect_refusal "drain longer than the grace period"     --set-string dakera.config.shutdownDrainSecs=60
expect_refusal "drain over an hour"                     --set-string dakera.config.shutdownDrainSecs=3601 --set dakera.terminationGracePeriodSeconds=4000
expect_refusal "max connections 0"                      --set-string dakera.config.maxConnections=0
expect_refusal "allowed hosts with blanks"              --set-string 'dakera.config.allowedHosts=a.example b.example'
expect_refusal "document chunk tokens over 8192"        --set-string dakera.config.documents.chunkTokens=9000
expect_refusal "document chunk tokens under 32"         --set-string dakera.config.documents.chunkTokens=16
expect_refusal "document overlap over 1024"             --set-string dakera.config.documents.chunkOverlapTokens=2000
expect_refusal "document extraction concurrency 0"      --set-string dakera.config.documents.extractConcurrency=0
expect_refusal "unknown document setting"               --set dakera.config.documents.maxPages=10
expect_refusal "trusted proxies not addresses"          --set 'dashboard.trustedProxies=10.0.0.0/8;evil'
expect_refusal "cluster secret too short"                --set dakera.cluster.secret=short
expect_refusal "cluster secret and existingSecret"       --set dakera.cluster.secret=0123456789abcdef --set dakera.cluster.existingSecret.name=mine
# Server 0.12.1: a cluster node without DAKERA_CLUSTER_SECRET exits with code 78.
CM=(--set 'dakera.extraEnv[0].name=DAKERA_CLUSTER_MODE' --set-string 'dakera.extraEnv[0].value=true')
expect_refusal "cluster mode without a secret"           "${CM[@]}"
expect_refusal "cluster mode (valueFrom) without a secret" --set 'dakera.extraEnv[0].name=DAKERA_CLUSTER_MODE' \
  --set 'dakera.extraEnv[0].valueFrom.configMapKeyRef.name=x' --set 'dakera.extraEnv[0].valueFrom.configMapKeyRef.key=y'
expect_refusal "cluster secret of blanks"                --set-string 'dakera.cluster.secret=                x'
expect_refusal "cluster secret in extraEnv too short"    "${CM[@]}" --set 'dakera.extraEnv[1].name=DAKERA_CLUSTER_SECRET' --set-string 'dakera.extraEnv[1].value=short'
expect_refusal "cluster secret in extraEnv and cluster"  "${CM[@]}" --set 'dakera.extraEnv[1].name=DAKERA_CLUSTER_SECRET' \
  --set-string 'dakera.extraEnv[1].value=0123456789abcdef' --set dakera.cluster.secret=0123456789abcdef
echo "== cluster mode with a secret renders it"
"$HELM" template r "$CHART" "${REQ[@]}" "${CM[@]}" --set dakera.cluster.secret=0123456789abcdef \
  | grep_q 'DAKERA_CLUSTER_SECRET: "0123456789abcdef"' || { echo "FAIL: cluster.secret not in the Secret"; fail=1; }
"$HELM" template r "$CHART" "${REQ[@]}" "${CM[@]}" --set dakera.cluster.existingSecret.name=mine \
  | grep -A3 'name: DAKERA_CLUSTER_SECRET' | grep_q 'name: "mine"' || { echo "FAIL: existingSecret not referenced"; fail=1; }
"$HELM" template r "$CHART" "${REQ[@]}" --set-string 'dakera.extraEnv[0].value=false' --set 'dakera.extraEnv[0].name=DAKERA_CLUSTER_MODE' > /dev/null \
  || { echo "FAIL: DAKERA_CLUSTER_MODE=false refused"; fail=1; }
# The chart's Secret (where dakera.cluster.secret goes) is rendered only with rootApiKey.
if "$HELM" template r "$CHART" --set minio.rootPassword=ci-lint --set dakera.cluster.secret=0123456789abcdef > /dev/null 2>&1; then
  echo "FAIL: accepted (cluster secret without rootApiKey: it would be dropped)"; fail=1
else
  echo "ok: refused (cluster secret without rootApiKey)"
fi

echo "== built-in MinIO creates the server's bucket"
"$HELM" template r "$CHART" "${REQ[@]}" --set dakera.config.s3Bucket=ci-bucket | grep_q "mb --ignore-existing local/ci-bucket" \
  || { echo "FAIL: MinIO does not create the bucket"; fail=1; }

echo "== the dashboard gets no API key (0.3.x served it to every browser)"
# Whole render, one document per record (--show-only drops documents of a file that renders several).
dash=$("$HELM" template r "$CHART" "${REQ[@]}" | awk 'BEGIN{RS="\n---\n"} /kind: Deployment/ && /component: dashboard/')
if [ -z "$dash" ]; then
  echo "FAIL: dashboard Deployment not rendered"; fail=1
elif printf '%s' "$dash" | grep -Eq 'name: "?DAKERA_(ROOT_)?API_KEY'; then
  echo "FAIL: the dashboard pod is given an API key"; fail=1
else
  echo "ok: no key in the dashboard pod"
fi

[ "$fail" = 0 ] && echo "chart validation passed" || { echo "chart validation FAILED"; exit 1; }
