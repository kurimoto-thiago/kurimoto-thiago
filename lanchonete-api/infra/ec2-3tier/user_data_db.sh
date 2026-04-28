#!/bin/bash
# Camada 3 — BD: PostgreSQL 16 + Redis 6
set -euo pipefail
exec > >(tee /var/log/user-data.log | logger -t user-data) 2>&1

DB_PASSWORD="${DB_PASSWORD}"

# ── Sistema ───────────────────────────────────────────────────────────────────
dnf update -y
dnf install -y postgresql16-server postgresql16 redis6

# ── PostgreSQL ────────────────────────────────────────────────────────────────
/usr/bin/postgresql-setup --initdb

# Aceita conexões com senha de qualquer IP da VPC
cat >> /var/lib/pgsql/data/pg_hba.conf <<'PG_HBA'
host    all             all             10.0.0.0/8              md5
PG_HBA

# Escuta em todas as interfaces (necessário para app tier)
sed -i "s/^#listen_addresses = 'localhost'/listen_addresses = '*'/" \
  /var/lib/pgsql/data/postgresql.conf

systemctl enable --now postgresql

# ── Banco, usuário e schema ───────────────────────────────────────────────────
sudo -u postgres psql <<SQL
CREATE USER lanchonete_user WITH PASSWORD '$DB_PASSWORD';
CREATE DATABASE lanchonete OWNER lanchonete_user;
GRANT ALL PRIVILEGES ON DATABASE lanchonete TO lanchonete_user;
SQL

sudo -u postgres psql -d lanchonete <<'SQL'
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

DO $$ BEGIN
  CREATE TYPE pedido_status AS ENUM ('recebido','preparando','pronto','entregue','cancelado');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  CREATE TYPE categoria_item AS ENUM ('lanche','bebida','acompanhamento','sobremesa','combo');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

CREATE TABLE IF NOT EXISTS cardapio (
  id                SERIAL PRIMARY KEY,
  nome              VARCHAR(100)   NOT NULL,
  descricao         TEXT,
  preco             NUMERIC(10,2)  NOT NULL CHECK (preco >= 0),
  categoria         categoria_item NOT NULL,
  disponivel        BOOLEAN        NOT NULL DEFAULT true,
  tempo_preparo_min INT            NOT NULL DEFAULT 10,
  imagem_url        TEXT,
  created_at        TIMESTAMPTZ    NOT NULL DEFAULT NOW(),
  updated_at        TIMESTAMPTZ    NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS pedidos (
  id           SERIAL PRIMARY KEY,
  mesa         SMALLINT      NOT NULL CHECK (mesa BETWEEN 1 AND 200),
  cliente_nome VARCHAR(100)  NOT NULL,
  status       pedido_status NOT NULL DEFAULT 'recebido',
  total        NUMERIC(10,2) NOT NULL CHECK (total >= 0),
  created_at   TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
  updated_at   TIMESTAMPTZ   NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS pedido_itens (
  id          SERIAL PRIMARY KEY,
  pedido_id   INT           NOT NULL REFERENCES pedidos(id) ON DELETE CASCADE,
  cardapio_id INT           NOT NULL REFERENCES cardapio(id),
  quantidade  SMALLINT      NOT NULL CHECK (quantidade > 0),
  preco_unit  NUMERIC(10,2) NOT NULL,
  subtotal    NUMERIC(10,2) NOT NULL,
  observacao  VARCHAR(200)  DEFAULT ''
);

CREATE INDEX IF NOT EXISTS idx_pedidos_status   ON pedidos(status);
CREATE INDEX IF NOT EXISTS idx_pedidos_mesa     ON pedidos(mesa);
CREATE INDEX IF NOT EXISTS idx_pedidos_created  ON pedidos(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_cardapio_categ   ON cardapio(categoria);

INSERT INTO cardapio (nome, descricao, preco, categoria, tempo_preparo_min) VALUES
  ('X-Burguer',      'Pao brioche, carne 180g, queijo, alface, tomate', 28.90, 'lanche', 12),
  ('X-Bacon',        'Carne 180g, bacon crocante, queijo cheddar',       34.90, 'lanche', 15),
  ('X-Frango',       'File de frango grelhado, queijo, alface, tomate',  26.90, 'lanche', 12),
  ('X-Veggie',       'Hamburguer de grao-de-bico, queijo, rucula',       30.90, 'lanche', 14),
  ('X-Tudo',         'Carne, bacon, presunto, ovos, queijo duplo',       42.90, 'lanche', 18),
  ('Batata Frita P', 'Porcao pequena de batatas fritas crocantes',        9.90, 'acompanhamento', 8),
  ('Batata Frita G', 'Porcao grande de batatas fritas crocantes',        15.90, 'acompanhamento', 10),
  ('Onion Rings',    'Aneis de cebola empanados — 8 unidades',           14.90, 'acompanhamento', 10),
  ('Coca-Cola 350ml','Lata gelada',                                        6.00, 'bebida', 1),
  ('Suco de Laranja','Natural, 300ml',                                     9.90, 'bebida', 5),
  ('Milkshake',      'Chocolate, morango ou baunilha — 400ml',           18.90, 'bebida', 7),
  ('Agua Mineral',   '500ml, com ou sem gas',                              4.00, 'bebida', 1),
  ('Brownie',        'Brownie de chocolate com sorvete de creme',        14.90, 'sobremesa', 5),
  ('Sundae',         'Sorvete de creme com calda de chocolate',          11.90, 'sobremesa', 3),
  ('Combo Classico', 'X-Burguer + Batata Frita P + Coca-Cola',           39.90, 'combo', 15),
  ('Combo Familia',  '2x X-Burguer + 2x Batata Frita G + 2x Coca-Cola', 79.90, 'combo', 20)
ON CONFLICT DO NOTHING;

GRANT ALL ON ALL TABLES    IN SCHEMA public TO lanchonete_user;
GRANT ALL ON ALL SEQUENCES IN SCHEMA public TO lanchonete_user;
SQL

# ── Redis ─────────────────────────────────────────────────────────────────────
# Escuta em todas as interfaces para aceitar conexões da camada app
sed -i 's/^bind .*/bind 0.0.0.0/' /etc/redis6/redis6.conf
sed -i 's/^protected-mode yes/protected-mode no/' /etc/redis6/redis6.conf

systemctl enable --now redis6

echo "✅ Camada BD pronta"
