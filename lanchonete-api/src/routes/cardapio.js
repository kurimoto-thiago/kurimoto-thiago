'use strict';

const express       = require('express');
const { query }     = require('../db/postgres');
const cache         = require('../cache/redis');
const logger        = require('../logger');

const router     = express.Router();
const CACHE_KEY  = 'cardapio:todos';

/**
 * GET /cardapio
 * Retorna todos os itens ativos do cardápio.
 * Cache Redis com TTL configurável (padrão 5 min).
 */
router.get('/', async (_req, res, next) => {
  try {
    // ── 1. Tentar cache ──────────────────────────────────
    const cached = await cache.get(CACHE_KEY).catch(() => null);
    if (cached) {
      logger.debug('Cache hit — cardápio');
      return res.json({ source: 'cache', data: cached });
    }

    // ── 2. Banco de dados ────────────────────────────────
    const { rows } = await query(`
      SELECT
        id,
        nome,
        descricao,
        preco,
        categoria,
        disponivel,
        tempo_preparo_min,
        imagem_url,
        created_at
      FROM cardapio
      WHERE disponivel = true
      ORDER BY categoria, nome
    `);

    // ── 3. Gravar cache ──────────────────────────────────
    await cache.set(CACHE_KEY, rows).catch(() => {});

    logger.info('Cardápio carregado do banco', { total: rows.length });
    return res.json({ source: 'database', data: rows });
  } catch (err) {
    next(err);
  }
});

/**
 * GET /cardapio/:id
 * Retorna um item específico pelo ID.
 */
router.get('/:id', async (req, res, next) => {
  const { id } = req.params;
  if (!Number.isInteger(Number(id))) {
    return res.status(400).json({ error: 'ID inválido' });
  }

  try {
    const cacheKey = `cardapio:item:${id}`;
    const cached   = await cache.get(cacheKey).catch(() => null);
    if (cached) return res.json(cached);

    const { rows } = await query(
      `SELECT * FROM cardapio WHERE id = $1 AND disponivel = true`,
      [id]
    );

    if (rows.length === 0) {
      return res.status(404).json({ error: 'Item não encontrado' });
    }

    await cache.set(cacheKey, rows[0]).catch(() => {});
    return res.json(rows[0]);
  } catch (err) {
    next(err);
  }
});

module.exports = router;
