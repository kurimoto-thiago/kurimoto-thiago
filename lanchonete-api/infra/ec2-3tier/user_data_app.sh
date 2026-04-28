#!/bin/bash
# Camada 2 — App: Node.js 20 + PM2
set -euo pipefail
exec > >(tee /var/log/user-data.log | logger -t user-data) 2>&1

DB_HOST="${DB_HOST}"
DB_PASSWORD="${DB_PASSWORD}"
REDIS_HOST="${REDIS_HOST}"
APP_DIR="/home/ec2-user/lanchonete-api"

# ── Sistema ───────────────────────────────────────────────────────────────────
dnf update -y
dnf install -y git nmap-ncat

# ── Node.js 20 ────────────────────────────────────────────────────────────────
curl -fsSL https://rpm.nodesource.com/setup_20.x | bash -
dnf install -y nodejs
npm install -g pm2

# ── Aguarda BD ficar disponível ───────────────────────────────────────────────
echo "Aguardando PostgreSQL em $DB_HOST:5432..."
for i in $(seq 1 30); do
  if nc -z "$DB_HOST" 5432 2>/dev/null; then
    echo "PostgreSQL disponivel"
    break
  fi
  echo "  tentativa $i/30 — aguardando 10s..."
  sleep 10
done

# ── Código da aplicação ───────────────────────────────────────────────────────
git clone https://github.com/kurimoto-thiago/kurimoto-thiago.git /tmp/repo
cp -r /tmp/repo/lanchonete-api "$APP_DIR"
rm -rf /tmp/repo

# ── Variáveis de ambiente ─────────────────────────────────────────────────────
cat > "$APP_DIR/.env" <<ENV
NODE_ENV=production
PORT=3000
DB_HOST=$DB_HOST
DB_PORT=5432
DB_NAME=lanchonete
DB_USER=lanchonete_user
DB_PASSWORD=$DB_PASSWORD
DB_POOL_MIN=2
DB_POOL_MAX=10
REDIS_HOST=$REDIS_HOST
REDIS_PORT=6379
REDIS_TTL_CARDAPIO=300
RATE_LIMIT_WINDOW_MS=60000
RATE_LIMIT_MAX=100
LOG_LEVEL=info
ENV

# ── Dependências ──────────────────────────────────────────────────────────────
cd "$APP_DIR"
npm ci --omit=dev
mkdir -p logs
chown -R ec2-user:ec2-user "$APP_DIR"

# ── Serviço systemd ───────────────────────────────────────────────────────────
cat > /etc/systemd/system/lanchonete.service <<SERVICE
[Unit]
Description=Lanchonete API
After=network.target

[Service]
Type=simple
User=ec2-user
WorkingDirectory=$APP_DIR
ExecStart=/usr/bin/node src/app.js
Restart=on-failure
RestartSec=5
EnvironmentFile=$APP_DIR/.env
StandardOutput=append:$APP_DIR/logs/out.log
StandardError=append:$APP_DIR/logs/err.log

[Install]
WantedBy=multi-user.target
SERVICE

systemctl daemon-reload
systemctl enable --now lanchonete

echo "✅ Camada App pronta"
