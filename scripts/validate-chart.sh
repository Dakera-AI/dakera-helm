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
expect_refusal "cluster secret too short"                --set dakera.cluster.secret=short

[ "$fail" = 0 ] && echo "chart validation passed" || { echo "chart validation FAILED"; exit 1; }
