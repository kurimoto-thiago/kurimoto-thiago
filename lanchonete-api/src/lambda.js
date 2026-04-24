'use strict';
// src/lambda.js — wrapper que adapta Express para AWS Lambda
// Usa serverless-http para converter eventos API Gateway v2 (HTTP API)

const serverless = require('serverless-http');
// Importa o app Express SEM chamar o app.listen()
const app        = require('./app');

// serverless-http envolve o Express e converte:
//   APIGatewayProxyEventV2 → req/res Express → APIGatewayProxyResultV2
const handler = serverless(app, {
  // Preserva o path real mesmo com stage prefix (/prod, /v1, etc.)
  request(req, event) {
    req.event   = event;
    req.context = event.requestContext;
  },
});

module.exports.handler = handler;
