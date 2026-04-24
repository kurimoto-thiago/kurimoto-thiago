'use strict';

const { Pool } = require('pg');
const logger   = require('../logger');

const pool = new Pool({
  host:     process.env.DB_HOST     || 'localhost',
  port:     parseInt(process.env.DB_PORT || '5432'),
  database: process.env.DB_NAME     || 'lanchonete',
  user:     process.env.DB_USER     || 'lanchonete_user',
  password: process.env.DB_PASSWORD || '',
  min:      parseInt(process.env.DB_POOL_MIN || '2'),
  max:      parseInt(process.env.DB_POOL_MAX || '10'),
  idleTimeoutMillis:    30000,
  connectionTimeoutMillis: 5000,
});

pool.on('error', (err) => {
  logger.error('PostgreSQL pool error', { error: err.message });
});

/**
 * Executa uma query com parâmetros
 * @param {string} text   - SQL
 * @param {Array}  params - valores parametrizados
 */
async function query(text, params = []) {
  const start = Date.now();
  try {
    const result = await pool.query(text, params);
    logger.debug('Query executada', {
      sql:      text.substring(0, 80),
      rows:     result.rowCount,
      duration: Date.now() - start + 'ms',
    });
    return result;
  } catch (err) {
    logger.error('Erro na query', { sql: text.substring(0, 80), error: err.message });
    throw err;
  }
}

/**
 * Testa a conexão com o banco
 */
async function testConnection() {
  const { rows } = await query('SELECT NOW() AS now, current_database() AS db');
  logger.info('PostgreSQL conectado', rows[0]);
}

module.exports = { pool, query, testConnection };
