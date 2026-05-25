const express = require('express');
const authMiddleware = require('../middleware/auth');
const router = express.Router();

router.get('/', authMiddleware, async (req, res, next) => {
  try {
    const db = req.app.locals.db;
    const result = await db.query(
      `SELECT * FROM alerts ORDER BY created_at DESC LIMIT 100`
    );
    res.json({ items: result.rows });
  } catch (err) { next(err); }
});

router.post('/:id/ack', authMiddleware, async (req, res, next) => {
  try {
    const db = req.app.locals.db;
    await db.query(
      `UPDATE alerts SET acknowledged_at = NOW(), acknowledged_by = $1 WHERE id = $2`,
      [req.user.id, req.params.id]
    );
    res.json({ status: 'acknowledged' });
  } catch (err) { next(err); }
});

module.exports = router;
