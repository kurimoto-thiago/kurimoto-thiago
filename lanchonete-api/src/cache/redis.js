'use strict';

const Redis  = require('ioredis');
const logger = require('../logger');

const redis = new Redis({
  host:            process.env.REDIS_HOST     || 'localhost',
  port:            parseInt(process.env.REDIS_PORT || '6379'),
  password:        process.env.REDIS_PASSWORD || undefined,
  maxRetriesPerRequest: 3,
  retryStrategy(times) {
    if (times > 5) return null; // desiste após 5 tentativas
    return Math.min(times * 200, 2000);
  },
  lazyConnect: true,
});

redis.on('connect',        () => logger.info('Redis conectado'));
redis.on('ready',          () => logger.info('Redis pronto'));
redis.on('error',    (err) => logger.error('Redis erro', { error: err.message }));
redis.on('reconnecting',   () => logger.warn('Redis reconectando...'));

const TTL_CARDAPIO = parseInt(process.env.REDIS_TTL_CARDAPIO || '300');

/**
 * Get com parse JSON automático
 */
async function get(key) {
  const val = await redis.get(key);
  return val ? JSON.parse(val) : null;
}

/**
 * Set com TTL padrão e serialização JSON
 */
async function set(key, value, ttl = TTL_CARDAPIO) {
  await redis.set(key, JSON.stringify(value), 'EX', ttl);
}

/**
 * Invalidar uma chave
 */
async function del(key) {
  await redis.del(key);
}

/**
 * Invalidar padrão de chaves (ex: "cardapio:*")
 */
async function delPattern(pattern) {
  const keys = await redis.keys(pattern);
  if (keys.length > 0) await redis.del(...keys);
  return keys.length;
}

async function testConnection() {
  await redis.connect();
  const pong = await redis.ping();
  logger.info('Redis ping', { response: pong });
}

module.exports = { redis, get, set, del, delPattern, testConnection, TTL_CARDAPIO };
