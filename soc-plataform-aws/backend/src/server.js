const express = require('express');
const helmet = require('helmet');
const cors = require('cors');
const morgan = require('morgan');
const promClient = require('prom-client');
const logger = require('./services/logger');
const { connectDB } = require('./services/database');
const { connectRedis } = require('./services/cache');
const routes = require('./routes');
const errorHandler = require('./middleware/errorHandler');

const app = express();
const PORT = process.env.PORT || 3000;

// ============================================================
// Prometheus metrics
// ============================================================
const register = new promClient.Registry();
promClient.collectDefaultMetrics({ register });

const httpRequestDuration = new promClient.Histogram({
  name: 'http_request_duration_seconds',
  help: 'Duration of HTTP requests in seconds',
  labelNames: ['method', 'route', 'status_code'],
  buckets: [0.005, 0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1, 2.5, 5, 10],
});
register.registerMetric(httpRequestDuration);

const securityEventsCounter = new promClient.Counter({
  name: 'security_events_total',
  help: 'Total security events ingested',
  labelNames: ['severity', 'source', 'tenant'],
});
register.registerMetric(securityEventsCounter);

app.locals.metrics = { httpRequestDuration, securityEventsCounter };

// ============================================================
// Middlewares
// ============================================================
app.use(helmet());
app.use(cors({ origin: process.env.CORS_ORIGIN?.split(',') || '*' }));
app.use(express.json({ limit: '1mb' }));
app.use(morgan('combined', { stream: { write: (msg) => logger.info(msg.trim()) } }));

app.use((req, res, next) => {
  const end = httpRequestDuration.startTimer();
  res.on('finish', () => {
    end({
      method: req.method,
      route: req.route?.path || req.path,
      status_code: res.statusCode,
    });
  });
  next();
});

// ============================================================
// Routes
// ============================================================
app.get('/health', (req, res) => res.json({ status: 'ok', uptime: process.uptime() }));
app.get('/ready', async (req, res) => {
  try {
    await req.app.locals.db.query('SELECT 1');
    res.json({ status: 'ready' });
  } catch (err) {
    res.status(503).json({ status: 'not ready', error: err.message });
  }
});

app.get('/metrics', async (req, res) => {
  res.set('Content-Type', register.contentType);
  res.end(await register.metrics());
});

app.use('/api/v1', routes);
app.use(errorHandler);

// ============================================================
// Bootstrap
// ============================================================
async function start() {
  try {
    app.locals.db = await connectDB();
    app.locals.cache = await connectRedis();

    app.listen(PORT, () => {
      logger.info(`🚀 SOC Platform API running on port ${PORT}`);
    });
  } catch (err) {
    logger.error('Failed to start server', err);
    process.exit(1);
  }
}

process.on('SIGTERM', () => {
  logger.info('SIGTERM received, shutting down gracefully');
  process.exit(0);
});

start();

module.exports = app;
