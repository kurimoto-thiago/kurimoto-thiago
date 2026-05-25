#!/usr/bin/env bash
# Port-forward para acessar serviços localmente
set -e

declare -A SERVICES=(
  ["argocd:argocd-server"]="8080:80"
  ["monitoring:kps-grafana"]="3000:80"
  ["monitoring:kps-prometheus"]="9090:9090"
  ["security:wazuh-dashboard"]="5601:443"
  ["soc-platform:soc-frontend"]="5173:80"
)

for k in "${!SERVICES[@]}"; do
  ns="${k%%:*}"
  svc="${k##*:}"
  port="${SERVICES[$k]}"
  echo "→ $svc ($ns) em http://localhost:${port%%:*}"
  kubectl port-forward -n "$ns" "svc/$svc" "$port" &
done

trap 'kill $(jobs -p) 2>/dev/null' EXIT
wait
