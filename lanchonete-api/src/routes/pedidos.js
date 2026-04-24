'use strict';

const express    = require('express');
const Joi        = require('joi');
const { query }  = require('../db/postgres');
const { redis }  = require('../cache/redis');
const logger     = require('../logger');

const router = express.Router();

// ── Schemas de validação ────────────────────────────────────────────────────
const itemSchema = Joi.object({
  cardapio_id: Joi.number().integer().positive().required(),
  quantidade:  Joi.number().integer().min(1).max(50).required(),
  observacao:  Joi.string().max(200).optional().allow(''),
});

const pedidoSchema = Joi.object({
  mesa:          Joi.number().integer().min(1).max(200).required(),
  cliente_nome:  Joi.string().min(2).max(100).required(),
  itens:         Joi.array().items(itemSchema).min(1).max(20).required(),
});

// ── Helpers ─────────────────────────────────────────────────────────────────

/**
 * Calcula o total do pedido buscando preços no banco
 */
async function calcularTotal(itens) {
  const ids      = itens.map((i) => i.cardapio_id);
  const { rows } = await query(
    `SELECT id, nome, preco FROM cardapio WHERE id = ANY($1) AND disponivel = true`,
    [ids]
  );

  const precos = Object.fromEntries(rows.map((r) => [r.id, r]));

  for (const item of itens) {
    if (!precos[item.cardapio_id]) {
      throw Object.assign(new Error(`Item ${item.cardapio_id} indisponível`), { status: 422 });
    }
  }

  const total = itens.reduce((acc, item) => {
    return acc + precos[item.cardapio_id].preco * item.quantidade;
  }, 0);

  return { total, precos };
}

// ── Rotas ────────────────────────────────────────────────────────────────────

/**
 * GET /pedidos
 * Lista pedidos (últimas 24h por padrão). Suporta ?status=&mesa=
 */
router.get('/', async (req, res, next) => {
  try {
    const { status, mesa } = req.query;

    const conditions = ["p.created_at > NOW() - INTERVAL '24 hours'"];
    const params     = [];

    if (status) {
      params.push(status);
      conditions.push(`p.status = $${params.length}`);
    }
    if (mesa) {
      params.push(parseInt(mesa));
      conditions.push(`p.mesa = $${params.length}`);
    }

    const where = conditions.map((c) => `(${c})`).join(' AND ');

    const { rows } = await query(
      `SELECT
        p.id,
        p.mesa,
        p.cliente_nome,
        p.status,
        p.total,
        p.created_at,
        p.updated_at,
        json_agg(
          json_build_object(
            'cardapio_id', pi.cardapio_id,
            'nome',        c.nome,
            'quantidade',  pi.quantidade,
            'preco_unit',  pi.preco_unit,
            'subtotal',    pi.subtotal,
            'observacao',  pi.observacao
          )
        ) AS itens
      FROM pedidos p
      JOIN pedido_itens pi ON pi.pedido_id = p.id
      JOIN cardapio c      ON c.id = pi.cardapio_id
      WHERE ${where}
      GROUP BY p.id
      ORDER BY p.created_at DESC
      LIMIT 200`,
      params
    );

    res.json({ total: rows.length, data: rows });
  } catch (err) {
    next(err);
  }
});

/**
 * GET /pedidos/:id
 */
router.get('/:id', async (req, res, next) => {
  const { id } = req.params;
  if (!Number.isInteger(Number(id))) {
    return res.status(400).json({ error: 'ID inválido' });
  }

  try {
    const { rows } = await query(
      `SELECT
        p.*,
        json_agg(
          json_build_object(
            'cardapio_id', pi.cardapio_id,
            'nome',        c.nome,
            'quantidade',  pi.quantidade,
            'preco_unit',  pi.preco_unit,
            'subtotal',    pi.subtotal,
            'observacao',  pi.observacao
          )
        ) AS itens
      FROM pedidos p
      JOIN pedido_itens pi ON pi.pedido_id = p.id
      JOIN cardapio c      ON c.id = pi.cardapio_id
      WHERE p.id = $1
      GROUP BY p.id`,
      [id]
    );

    if (rows.length === 0) {
      return res.status(404).json({ error: 'Pedido não encontrado' });
    }

    res.json(rows[0]);
  } catch (err) {
    next(err);
  }
});

/**
 * POST /pedidos
 * Cria um novo pedido dentro de uma transação.
 */
router.post('/', async (req, res, next) => {
  const { error, value } = pedidoSchema.validate(req.body, { abortEarly: false });
  if (error) {
    return res.status(400).json({
      error:   'Dados inválidos',
      details: error.details.map((d) => d.message),
    });
  }

  const { mesa, cliente_nome, itens } = value;
  const client = await require('../db/postgres').pool.connect();

  try {
    const { total, precos } = await calcularTotal(itens);

    await client.query('BEGIN');

    // ── Inserir pedido ──────────────────────────────────────────────────────
    const { rows: [pedido] } = await client.query(
      `INSERT INTO pedidos (mesa, cliente_nome, status, total)
       VALUES ($1, $2, 'recebido', $3)
       RETURNING *`,
      [mesa, cliente_nome, total]
    );

    // ── Inserir itens ───────────────────────────────────────────────────────
    for (const item of itens) {
      const preco_unit = precos[item.cardapio_id].preco;
      const subtotal   = preco_unit * item.quantidade;
      await client.query(
        `INSERT INTO pedido_itens (pedido_id, cardapio_id, quantidade, preco_unit, subtotal, observacao)
         VALUES ($1, $2, $3, $4, $5, $6)`,
        [pedido.id, item.cardapio_id, item.quantidade, preco_unit, subtotal, item.observacao || '']
      );
    }

    await client.query('COMMIT');

    // ── Pub/Sub — notifica cozinha via Redis ────────────────────────────────
    await redis.publish('novos-pedidos', JSON.stringify({
      pedido_id:    pedido.id,
      mesa,
      cliente_nome,
      total,
      timestamp:    new Date().toISOString(),
    })).catch(() => {});

    logger.info('Pedido criado', { pedido_id: pedido.id, mesa, total });

    res.status(201).json({ message: 'Pedido criado com sucesso', pedido });
  } catch (err) {
    await client.query('ROLLBACK');
    next(err);
  } finally {
    client.release();
  }
});

/**
 * PATCH /pedidos/:id/status
 * Atualiza o status: recebido → preparando → pronto → entregue
 */
router.patch('/:id/status', async (req, res, next) => {
  const { id }     = req.params;
  const { status } = req.body;

  const STATUS_VALIDOS = ['recebido', 'preparando', 'pronto', 'entregue', 'cancelado'];
  if (!STATUS_VALIDOS.includes(status)) {
    return res.status(400).json({ error: `Status inválido. Use: ${STATUS_VALIDOS.join(', ')}` });
  }

  try {
    const { rows } = await query(
      `UPDATE pedidos SET status = $1, updated_at = NOW() WHERE id = $2 RETURNING *`,
      [status, id]
    );
    if (rows.length === 0) return res.status(404).json({ error: 'Pedido não encontrado' });

    // Notifica mudança de status
    await redis.publish('status-pedidos', JSON.stringify({ pedido_id: id, status })).catch(() => {});

    res.json({ message: 'Status atualizado', pedido: rows[0] });
  } catch (err) {
    next(err);
  }
});

module.exports = router;
