const express = require('express');
const authMiddleware = require('../middleware/auth');
const router = express.Router();

router.get('/', authMiddleware, async (req, res, next) => {
  try {
    const db = req.app.locals.db;
    const result = await db.query(`SELECT id, name, created_at FROM tenants`);
    res.json({ items: result.rows });
  } catch (err) { next(err); }
});

router.post('/', authMiddleware, async (req, res, next) => {
  try {
    const { name } = req.body;
    const db = req.app.locals.db;
    const result = await db.query(
      `INSERT INTO tenants (name) VALUES ($1) RETURNING id, name, created_at`,
      [name]
    );
    res.status(201).json(result.rows[0]);
  } catch (err) { next(err); }
});

module.exports = router;
