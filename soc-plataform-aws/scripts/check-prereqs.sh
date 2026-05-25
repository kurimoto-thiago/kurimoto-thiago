#!/usr/bin/env bash
# Valida ferramentas necessárias
set -e

declare -A TOOLS=(
  [aws]="2.15"
  [terraform]="1.7"
  [kubectl]="1.29"
  [helm]="3.14"
  [docker]="24"
  [jq]="1.6"
)

echo "=== Verificando pré-requisitos ==="
MISSING=()
for tool in "${!TOOLS[@]}"; do
  if ! command -v "$tool" &>/dev/null; then
    MISSING+=("$tool (mínimo ${TOOLS[$tool]})")
  else
    echo "✓ $tool: $(command -v $tool)"
  fi
done

if [ ${#MISSING[@]} -gt 0 ]; then
  echo ""
  echo "❌ Faltam ferramentas:"
  printf '  - %s\n' "${MISSING[@]}"
  exit 1
fi

# AWS credentials
if ! aws sts get-caller-identity &>/dev/null; then
  echo "❌ AWS credentials não configuradas. Rode: aws configure"
  exit 1
fi

echo ""
echo "✓ AWS Account: $(aws sts get-caller-identity --query Account --output text)"
echo "✓ AWS Region:  $(aws configure get region)"
echo ""
echo "✓ Todos os pré-requisitos OK"
