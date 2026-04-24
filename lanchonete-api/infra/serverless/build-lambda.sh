#!/bin/bash
# build-lambda.sh — empacota a aplicação para deploy no Lambda
set -euo pipefail

echo "📦 Buildando pacote Lambda..."

# Instalar deps de produção
npm ci --omit=dev

# Adicionar serverless-http (só para Lambda)
npm install serverless-http --no-save

# Criar zip
zip -r lambda.zip src/ node_modules/ package.json \
  --exclude "node_modules/nodemon/*" \
  --exclude "node_modules/jest*/*" \
  --exclude "**/*.test.js" \
  --exclude "**/*.spec.js"

SIZE=$(du -sh lambda.zip | cut -f1)
echo "✅ lambda.zip criado — $SIZE"
echo "   Deploy: aws lambda update-function-code \\"
echo "     --function-name lanchonete-api-prod \\"
echo "     --zip-file fileb://lambda.zip"
