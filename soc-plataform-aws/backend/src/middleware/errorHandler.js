const logger = require('../services/logger');

module.exports = (err, req, res, next) => {
  logger.error('Request error', { err: err.message, stack: err.stack, path: req.path });
  const status = err.status || 500;
  res.status(status).json({
    error: err.message || 'Internal server error',
    ...(process.env.NODE_ENV !== 'production' && { stack: err.stack }),
  });
};
