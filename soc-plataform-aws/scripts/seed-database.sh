#!/usr/bin/env bash
# Aplica schema e seeds no RDS
set -euo pipefail

DB_SECRET_ARN=$(terraform -chdir=terraform output -raw rds_secret_arn 2>/dev/null || echo "")
if [ -z "$DB_SECRET_ARN" ]; then
  echo "❌ Não foi possível obter secret ARN do Terraform output"
  exit 1
fi

CREDS=$(aws secretsmanager get-secret-value --secret-id "$DB_SECRET_ARN" --query SecretString --output text)
export PGHOST=$(echo "$CREDS" | jq -r .host)
export PGPORT=$(echo "$CREDS" | jq -r .port)
export PGDATABASE=$(echo "$CREDS" | jq -r .database)
export PGUSER=$(echo "$CREDS" | jq -r .username)
export PGPASSWORD=$(echo "$CREDS" | jq -r .password)

echo "→ Aplicando migration..."
psql -f backend/migrations/001_initial_schema.sql

echo "✓ Schema aplicado"
