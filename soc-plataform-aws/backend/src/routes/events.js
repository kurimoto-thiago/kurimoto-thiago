const express = require('express');
const Joi = require('joi');
const authMiddleware = require('../middleware/auth');

const router = express.Router();

const eventSchema = Joi.object({
  tenant_id: Joi.string().uuid().required(),
  source: Joi.string().valid('wazuh', 'falco', 'suricata', 'cloudtrail', 'guardduty').required(),
  severity: Joi.string().valid('low', 'medium', 'high', 'critical').required(),
  rule_id: Joi.string().required(),
  description: Joi.string().required(),
  raw: Joi.object().required(),
  occurred_at: Joi.date().iso().required(),
});

router.post('/', authMiddleware, async (req, res, next) => {
  try {
    const { error, value } = eventSchema.validate(req.body);
    if (error) return res.status(400).json({ error: error.details[0].message });

    const db = req.app.locals.db;
    const result = await db.query(
      `INSERT INTO security_events (tenant_id, source, severity, rule_id, description, raw, occurred_at)
       VALUES ($1, $2, $3, $4, $5, $6, $7) RETURNING id, created_at`,
      [value.tenant_id, value.source, value.severity, value.rule_id, value.description, value.raw, value.occurred_at]
    );

    req.app.locals.metrics.securityEventsCounter.inc({
      severity: value.severity,
      source: value.source,
      tenant: value.tenant_id,
    });

    res.status(201).json(result.rows[0]);
  } catch (err) {
    next(err);
  }
});

router.get('/', authMiddleware, async (req, res, next) => {
  try {
    const { tenant_id, severity, source, limit = 100, offset = 0 } = req.query;
    const db = req.app.locals.db;

    const filters = [];
    const params = [];
    let idx = 1;

    if (tenant_id) { filters.push(`tenant_id = $${idx++}`); params.push(tenant_id); }
    if (severity) { filters.push(`severity = $${idx++}`); params.push(severity); }
    if (source) { filters.push(`source = $${idx++}`); params.push(source); }

    const where = filters.length ? `WHERE ${filters.join(' AND ')}` : '';

    const result = await db.query(
      `SELECT id, tenant_id, source, severity, rule_id, description, occurred_at, created_at
       FROM security_events ${where}
       ORDER BY occurred_at DESC
       LIMIT $${idx++} OFFSET $${idx}`,
      [...params, parseInt(limit), parseInt(offset)]
    );

    res.json({
      total: result.rowCount,
      items: result.rows,
    });
  } catch (err) {
    next(err);
  }
});

router.get('/stats', authMiddleware, async (req, res, next) => {
  try {
    const db = req.app.locals.db;
    const cache = req.app.locals.cache;
    const cached = await cache.get('events:stats');
    if (cached) return res.json(JSON.parse(cached));

    const result = await db.query(`
      SELECT 
        severity,
        COUNT(*) as total,
        COUNT(*) FILTER (WHERE occurred_at > NOW() - INTERVAL '1 hour') as last_hour,
        COUNT(*) FILTER (WHERE occurred_at > NOW() - INTERVAL '24 hours') as last_24h
      FROM security_events
      GROUP BY severity
    `);

    const data = { stats: result.rows, generated_at: new Date().toISOString() };
    await cache.setEx('events:stats', 30, JSON.stringify(data));
    res.json(data);
  } catch (err) {
    next(err);
  }
});

module.exports = router;
