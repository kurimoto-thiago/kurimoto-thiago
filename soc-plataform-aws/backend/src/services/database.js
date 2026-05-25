const { Pool } = require('pg');
const logger = require('./logger');

async function connectDB() {
  const pool = new Pool({
    host: process.env.DB_HOST,
    port: process.env.DB_PORT || 5432,
    database: process.env.DB_NAME,
    user: process.env.DB_USER,
    password: process.env.DB_PASSWORD,
    ssl: process.env.DB_SSL === 'true' ? { rejectUnauthorized: false } : false,
    max: 20,
    idleTimeoutMillis: 30000,
  });

  await pool.query('SELECT 1');
  logger.info('PostgreSQL connected');
  return pool;
}

module.exports = { connectDB };
