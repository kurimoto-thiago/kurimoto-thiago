#!/bin/bash
# infra/sql/init-db.sh
# Executa schema.sql + seed.sql contra o RDS (ou local)
# Uso: ./init-db.sh [host] [port] [db] [user]
set -euo pipefail

DB_HOST="${1:-localhost}"
DB_PORT="${2:-5432}"
DB_NAME="${3:-lanchonete}"
DB_USER="${4:-lanchonete_user}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "🔗 Conectando em $DB_HOST:$DB_PORT/$DB_NAME..."

# Schema
psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" \
  -f "$SCRIPT_DIR/schema.sql" \
  -v ON_ERROR_STOP=1
echo "✅ Schema aplicado"

# Seed
psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" \
  -f "$SCRIPT_DIR/seed.sql" \
  -v ON_ERROR_STOP=1
echo "✅ Seed aplicado"

# Verificar
echo "📊 Itens no cardápio:"
psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" \
  -c "SELECT categoria, COUNT(*) FROM cardapio GROUP BY categoria ORDER BY categoria;"
