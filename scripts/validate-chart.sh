#!/usr/bin/env bash
# Validate the chart: lint and render the defaults, every example values file (each v0.12
# feature and their combinations), the opt-in monitoring objects, and check that the
# combinations the server cannot run are refused with a message.
# Usage: scripts/validate-chart.sh            (HELM=/path/to/helm to choose the binary)
set -euo pipefail
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
  | grep -q "kind: PrometheusRule"

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
  | grep -q 'DAKERA_CLUSTER_SECRET: "0123456789abcdef"' || { echo "FAIL: cluster.secret not in the Secret"; fail=1; }
"$HELM" template r "$CHART" "${REQ[@]}" "${CM[@]}" --set dakera.cluster.existingSecret.name=mine \
  | grep -A3 'name: DAKERA_CLUSTER_SECRET' | grep -q 'name: "mine"' || { echo "FAIL: existingSecret not referenced"; fail=1; }
"$HELM" template r "$CHART" "${REQ[@]}" --set-string 'dakera.extraEnv[0].value=false' --set 'dakera.extraEnv[0].name=DAKERA_CLUSTER_MODE' > /dev/null \
  || { echo "FAIL: DAKERA_CLUSTER_MODE=false refused"; fail=1; }
# The chart's Secret (where dakera.cluster.secret goes) is rendered only with rootApiKey.
if "$HELM" template r "$CHART" --set minio.rootPassword=ci-lint --set dakera.cluster.secret=0123456789abcdef > /dev/null 2>&1; then
  echo "FAIL: accepted (cluster secret without rootApiKey: it would be dropped)"; fail=1
else
  echo "ok: refused (cluster secret without rootApiKey)"
fi

echo "== built-in MinIO creates the server's bucket"
"$HELM" template r "$CHART" "${REQ[@]}" --set dakera.config.s3Bucket=ci-bucket | grep -q "mb --ignore-existing local/ci-bucket" \
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
