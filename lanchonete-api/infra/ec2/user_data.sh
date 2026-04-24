#!/bin/bash
# ╔══════════════════════════════════════════════════════════════╗
# ║  EC2 User Data — lanchonete-api                             ║
# ║  Amazon Linux 2023 · Node 20 · PM2 · CloudWatch Agent      ║
# ╚══════════════════════════════════════════════════════════════╝
set -euo pipefail
exec > >(tee /var/log/user-data.log | logger -t user-data) 2>&1

# ── 1. Sistema ────────────────────────────────────────────────
dnf update -y
dnf install -y git wget unzip

# ── 2. Node.js 20 ─────────────────────────────────────────────
curl -fsSL https://rpm.nodesource.com/setup_20.x | bash -
dnf install -y nodejs
node -v && npm -v

# ── 3. PM2 ────────────────────────────────────────────────────
npm install -g pm2
pm2 startup systemd -u ec2-user --hp /home/ec2-user

# ── 4. CloudWatch Agent ───────────────────────────────────────
wget https://s3.amazonaws.com/amazoncloudwatch-agent/amazon_linux/amd64/latest/amazon-cloudwatch-agent.rpm
rpm -U ./amazon-cloudwatch-agent.rpm

cat > /opt/aws/amazon-cloudwatch-agent/bin/config.json <<'EOF'
{
  "logs": {
    "logs_collected": {
      "files": {
        "collect_list": [
          {
            "file_path": "/home/ec2-user/lanchonete-api/logs/*.log",
            "log_group_name": "/lanchonete/app",
            "log_stream_name": "{instance_id}",
            "timestamp_format": "%Y-%m-%dT%H:%M:%S"
          }
        ]
      }
    }
  },
  "metrics": {
    "namespace": "Lanchonete/EC2",
    "metrics_collected": {
      "mem":  { "measurement": ["mem_used_percent"] },
      "disk": { "measurement": ["disk_used_percent"], "resources": ["/"] },
      "cpu":  { "totalcpu": true }
    },
    "append_dimensions": {
      "InstanceId": "${aws:InstanceId}",
      "AutoScalingGroupName": "${aws:AutoScalingGroupName}"
    }
  }
}
EOF

/opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
  -a fetch-config -m ec2 \
  -c file:/opt/aws/amazon-cloudwatch-agent/bin/config.json -s

# ── 5. Código-fonte via S3 ────────────────────────────────────
# Substitua pelo seu bucket
S3_BUCKET="${S3_ARTIFACTS_BUCKET:-lanchonete-artifacts}"
APP_DIR="/home/ec2-user/lanchonete-api"

mkdir -p "$APP_DIR"
aws s3 cp "s3://${S3_BUCKET}/lanchonete-api.tar.gz" /tmp/app.tar.gz
tar -xzf /tmp/app.tar.gz -C /home/ec2-user/
cd "$APP_DIR"

# ── 6. Variáveis de ambiente via SSM Parameter Store ─────────
REGION=$(curl -s http://169.254.169.254/latest/meta-data/placement/region)

fetch_ssm() {
  aws ssm get-parameter --name "$1" --with-decryption \
    --region "$REGION" --query 'Parameter.Value' --output text
}

cat > "$APP_DIR/.env" <<ENV
NODE_ENV=production
PORT=3000
DB_HOST=$(fetch_ssm /lanchonete/db_host)
DB_PORT=5432
DB_NAME=lanchonete
DB_USER=lanchonete_user
DB_PASSWORD=$(fetch_ssm /lanchonete/db_password)
REDIS_HOST=$(fetch_ssm /lanchonete/redis_host)
REDIS_PORT=6379
REDIS_TTL_CARDAPIO=300
RATE_LIMIT_WINDOW_MS=60000
RATE_LIMIT_MAX=100
ENV

# ── 7. Instalar dependências ──────────────────────────────────
npm ci --omit=dev
chown -R ec2-user:ec2-user "$APP_DIR"

# ── 8. PM2 ecosystem + start ──────────────────────────────────
cat > "$APP_DIR/ecosystem.config.js" <<'PM2'
module.exports = {
  apps: [{
    name:          'lanchonete-api',
    script:        'src/app.js',
    instances:     'max',          // um processo por vCPU
    exec_mode:     'cluster',
    max_memory_restart: '400M',
    env_production: {
      NODE_ENV: 'production',
    },
    error_file:    'logs/err.log',
    out_file:      'logs/out.log',
    merge_logs:    true,
    log_date_format: 'YYYY-MM-DD HH:mm:ss Z',
  }],
};
PM2

mkdir -p "$APP_DIR/logs"
su -c "cd $APP_DIR && pm2 start ecosystem.config.js --env production && pm2 save" ec2-user

# ── 9. Nginx como reverse proxy ───────────────────────────────
dnf install -y nginx

cat > /etc/nginx/conf.d/lanchonete.conf <<'NGINX'
upstream app {
    least_conn;
    server 127.0.0.1:3000;
    keepalive 32;
}

server {
    listen 80;
    server_name _;

    location /health {
        proxy_pass http://app;
        access_log off;
    }

    location / {
        proxy_pass              http://app;
        proxy_http_version      1.1;
        proxy_set_header        Connection        "";
        proxy_set_header        Host              $host;
        proxy_set_header        X-Real-IP         $remote_addr;
        proxy_set_header        X-Forwarded-For   $proxy_add_x_forwarded_for;
        proxy_set_header        X-Forwarded-Proto $scheme;
        proxy_connect_timeout   5s;
        proxy_read_timeout      30s;
        proxy_send_timeout      30s;
    }
}
NGINX

systemctl enable --now nginx
echo "✅ Bootstrap concluído"
