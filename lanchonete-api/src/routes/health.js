'use strict';

const express  = require('express');
const { query }= require('../db/postgres');
const { redis }= require('../cache/redis');
const logger   = require('../logger');

const router = express.Router();

/**
 * GET /health
 * Liveness probe — resposta rápida para o ALB/K8s
 */
router.get('/', (_req, res) => {
  res.status(200).json({
    status:    'ok',
    timestamp: new Date().toISOString(),
    uptime:    Math.floor(process.uptime()),
  });
});

/**
 * GET /health/ready
 * Readiness probe — verifica dependências antes de receber tráfego
 */
router.get('/ready', async (_req, res) => {
  const checks = { postgres: 'ok', redis: 'ok' };
  let statusCode = 200;

  // ── PostgreSQL ──────────────────────────────────────────
  try {
    await query('SELECT 1');
  } catch (err) {
    checks.postgres = 'error: ' + err.message;
    statusCode = 503;
    logger.error('Health check — PostgreSQL falhou', { error: err.message });
  }

  // ── Redis ───────────────────────────────────────────────
  try {
    await redis.ping();
  } catch (err) {
    checks.redis = 'error: ' + err.message;
    statusCode = 503;
    logger.error('Health check — Redis falhou', { error: err.message });
  }

  res.status(statusCode).json({
    status:    statusCode === 200 ? 'ready' : 'not_ready',
    timestamp: new Date().toISOString(),
    checks,
  });
});

module.exports = router;
