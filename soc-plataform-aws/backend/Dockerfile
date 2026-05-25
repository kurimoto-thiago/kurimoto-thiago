# syntax=docker/dockerfile:1.6
FROM node:20-alpine AS builder

WORKDIR /app
COPY package*.json ./
RUN npm ci --omit=dev && npm cache clean --force

# ============================================================
FROM node:20-alpine AS runtime

LABEL org.opencontainers.image.title="soc-platform-backend"
LABEL org.opencontainers.image.source="https://github.com/USER/soc-platform-aws"

RUN apk add --no-cache tini curl && \
    addgroup -S app && adduser -S app -G app

WORKDIR /app
COPY --from=builder --chown=app:app /app/node_modules ./node_modules
COPY --chown=app:app src ./src
COPY --chown=app:app package.json ./

USER app
EXPOSE 3000

HEALTHCHECK --interval=30s --timeout=3s --start-period=10s \
    CMD curl -f http://localhost:3000/health || exit 1

ENTRYPOINT ["/sbin/tini", "--"]
CMD ["node", "src/server.js"]
