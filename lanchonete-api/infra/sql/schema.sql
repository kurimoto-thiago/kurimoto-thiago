-- ╔══════════════════════════════════════════════════════════╗
-- ║  Schema — Lanchonete API                                ║
-- ║  PostgreSQL 16+                                         ║
-- ╚══════════════════════════════════════════════════════════╝

-- ── Extensões ────────────────────────────────────────────────────────────────
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pg_stat_statements";

-- ── Tipos ────────────────────────────────────────────────────────────────────
DO $$ BEGIN
  CREATE TYPE pedido_status AS ENUM ('recebido','preparando','pronto','entregue','cancelado');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  CREATE TYPE categoria_item AS ENUM ('lanche','bebida','acompanhamento','sobremesa','combo');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- ── Cardápio ─────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS cardapio (
  id               SERIAL PRIMARY KEY,
  nome             VARCHAR(100) NOT NULL,
  descricao        TEXT,
  preco            NUMERIC(10,2) NOT NULL CHECK (preco >= 0),
  categoria        categoria_item NOT NULL,
  disponivel       BOOLEAN NOT NULL DEFAULT true,
  tempo_preparo_min INT     NOT NULL DEFAULT 10 CHECK (tempo_preparo_min >= 0),
  imagem_url       TEXT,
  created_at       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at       TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ── Pedidos ───────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS pedidos (
  id           SERIAL PRIMARY KEY,
  mesa         SMALLINT    NOT NULL CHECK (mesa BETWEEN 1 AND 200),
  cliente_nome VARCHAR(100) NOT NULL,
  status       pedido_status NOT NULL DEFAULT 'recebido',
  total        NUMERIC(10,2) NOT NULL CHECK (total >= 0),
  created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at   TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ── Itens do pedido ───────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS pedido_itens (
  id          SERIAL PRIMARY KEY,
  pedido_id   INT     NOT NULL REFERENCES pedidos(id) ON DELETE CASCADE,
  cardapio_id INT     NOT NULL REFERENCES cardapio(id),
  quantidade  SMALLINT NOT NULL CHECK (quantidade > 0),
  preco_unit  NUMERIC(10,2) NOT NULL,
  subtotal    NUMERIC(10,2) NOT NULL,
  observacao  VARCHAR(200) DEFAULT ''
);

-- ── Índices ───────────────────────────────────────────────────────────────────
CREATE INDEX IF NOT EXISTS idx_cardapio_disponivel  ON cardapio(disponivel);
CREATE INDEX IF NOT EXISTS idx_cardapio_categoria   ON cardapio(categoria);
CREATE INDEX IF NOT EXISTS idx_pedidos_status       ON pedidos(status);
CREATE INDEX IF NOT EXISTS idx_pedidos_mesa         ON pedidos(mesa);
CREATE INDEX IF NOT EXISTS idx_pedidos_created      ON pedidos(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_pedido_itens_pedido  ON pedido_itens(pedido_id);

-- ── Trigger: updated_at automático ───────────────────────────────────────────
CREATE OR REPLACE FUNCTION set_updated_at()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_cardapio_updated  ON cardapio;
CREATE TRIGGER trg_cardapio_updated
  BEFORE UPDATE ON cardapio
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

DROP TRIGGER IF EXISTS trg_pedidos_updated   ON pedidos;
CREATE TRIGGER trg_pedidos_updated
  BEFORE UPDATE ON pedidos
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();
