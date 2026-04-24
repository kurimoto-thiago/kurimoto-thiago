# ╔══════════════════════════════════════════════════════════╗
# ║  Dockerfile — lanchonete-api                            ║
# ║  Multi-stage: build enxuto + imagem de produção mínima  ║
# ╚══════════════════════════════════════════════════════════╝

# ── Stage 1: dependências ────────────────────────────────────────────────────
FROM node:20-alpine AS deps

WORKDIR /app

COPY package*.json ./

# Instala APENAS dependências de produção
RUN npm ci --omit=dev --ignore-scripts && \
    npm cache clean --force

# ── Stage 2: imagem final ────────────────────────────────────────────────────
FROM node:20-alpine AS runner

# Usuário sem privilégios
RUN addgroup -S appgroup && adduser -S appuser -G appgroup

WORKDIR /app

# Copia deps do stage anterior
COPY --from=deps /app/node_modules ./node_modules

# Copia código-fonte
COPY src/ ./src/
COPY package.json ./

# Permissões
RUN chown -R appuser:appgroup /app
USER appuser

# Porta padrão
EXPOSE 3000

# Health check nativo do Docker
HEALTHCHECK --interval=30s --timeout=5s --start-period=15s --retries=3 \
  CMD wget -qO- http://localhost:3000/health || exit 1

# Variáveis de ambiente padrão (sobrescreva via docker run -e ou ECS task def)
ENV NODE_ENV=production \
    PORT=3000

CMD ["node", "src/app.js"]
