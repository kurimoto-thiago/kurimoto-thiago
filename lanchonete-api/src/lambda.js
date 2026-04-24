'use strict';
// src/lambda.js — wrapper que adapta Express para AWS Lambda
// Usa serverless-http para converter eventos API Gateway v2 (HTTP API)

const serverless = require('serverless-http');
const app        = require('./app');

const _handler = serverless(app, {
  request(req, event) {
    req.event   = event;
    req.context = event.requestContext;
  },
});

// Retorna 200 imediatamente para eventos de warmup (schedule)
module.exports.handler = (event, context) => {
  if (event.source === 'warmup') {
    return Promise.resolve({ statusCode: 200, body: 'warmed' });
  }
  return _handler(event, context);
};
