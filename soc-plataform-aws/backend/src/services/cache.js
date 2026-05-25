const redis = require('redis');
const logger = require('./logger');

async function connectRedis() {
  const client = redis.createClient({
    url: `redis://${process.env.REDIS_HOST}:${process.env.REDIS_PORT || 6379}`,
    socket: { tls: process.env.REDIS_TLS === 'true' },
  });

  client.on('error', (err) => logger.error('Redis error', err));
  await client.connect();
  logger.info('Redis connected');
  return client;
}

module.exports = { connectRedis };
