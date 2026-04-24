'use strict';

require('dotenv').config();

const express      = require('express');
const helmet       = require('helmet');
const cors         = require('cors');
const morgan       = require('morgan');
const rateLimit    = require('express-rate-limit');
const client       = require('prom-client');
const logger       = require('./logger');

// ── Rotas ────────────────────────────────────────────────────────────────────
const healthRouter  = require('./routes/health');
const cardapioRouter= require('./routes/cardapio');
const pedidosRouter = require('./routes/pedidos');

// ── Conexões ─────────────────────────────────────────────────────────────────
const { testConnection: pgTest } = require('./db/postgres');
const { testConnection: redisTest } = require('./cache/redis');

const app  = express();
const PORT = parseInt(process.env.PORT || '3000');

// ── Prometheus ───────────────────────────────────────────────────────────────
client.collectDefaultMetrics({ prefix: 'lanchonete_' });

const httpRequestDuration = new client.Histogram({
  name:       'lanchonete_http_request_duration_seconds',
  help:       'Duração das requisições HTTP em segundos',
  labelNames: ['method', 'route', 'status_code'],
  buckets:    [0.005, 0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1, 2.5],
});

const httpRequestTotal = new client.Counter({
  name:       'lanchonete_http_requests_total',
  help:       'Total de requisições HTTP',
  labelNames: ['method', 'route', 'status_code'],
});

// ── Middlewares globais ──────────────────────────────────────────────────────
app.use(helmet());
app.use(cors());
app.use(express.json({ limit: '1mb' }));
app.use(morgan('combined', {
  stream: { write: (msg) => logger.http(msg.trim()) },
}));

// ── Rate limiting ────────────────────────────────────────────────────────────
app.use('/pedidos', rateLimit({
  windowMs: parseInt(process.env.RATE_LIMIT_WINDOW_MS || '60000'),
  max:      parseInt(process.env.RATE_LIMIT_MAX       || '100'),
  standardHeaders: true,
  legacyHeaders:   false,
  message: { error: 'Muitas requisições. Tente novamente em 1 minuto.' },
}));

// ── Métricas por requisição ──────────────────────────────────────────────────
app.use((req, res, next) => {
  const end = httpRequestDuration.startTimer();
  res.on('finish', () => {
    const route = req.route?.path || req.path;
    const labels = { method: req.method, route, status_code: res.statusCode };
    end(labels);
    httpRequestTotal.inc(labels);
  });
  next();
});

// ── Rotas ────────────────────────────────────────────────────────────────────
app.use('/health',   healthRouter);
app.use('/cardapio', cardapioRouter);
app.use('/pedidos',  pedidosRouter);

// ── Métricas Prometheus ──────────────────────────────────────────────────────
app.get('/metrics', async (_req, res) => {
  res.set('Content-Type', client.register.contentType);
  res.end(await client.register.metrics());
});

// ── 404 ──────────────────────────────────────────────────────────────────────
app.use((_req, res) => {
  res.status(404).json({ error: 'Rota não encontrada' });
});

// ── Error handler global ─────────────────────────────────────────────────────
// eslint-disable-next-line no-unused-vars
app.use((err, _req, res, _next) => {
  const status = err.status || 500;
  logger.error('Erro não tratado', { error: err.message, stack: err.stack });
  res.status(status).json({
    error:   status === 500 ? 'Erro interno do servidor' : err.message,
    ...(process.env.NODE_ENV !== 'production' && { stack: err.stack }),
  });
});

// ── Bootstrap ────────────────────────────────────────────────────────────────
async function start() {
  try {
    await pgTest();
    await redisTest();
    app.listen(PORT, '0.0.0.0', () => {
      logger.info(`Servidor iniciado na porta ${PORT}`, {
        env: process.env.NODE_ENV || 'development',
      });
    });
  } catch (err) {
    logger.error('Falha ao iniciar servidor', { error: err.message });
    process.exit(1);
  }
}

// Só faz listen quando executado diretamente (EC2 / Docker / PM2)
// No Lambda, src/lambda.js importa o app sem chamar start()
if (require.main === module) {
  start();
}

module.exports = app; // export para testes e Lambda
