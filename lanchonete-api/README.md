# lanchonete-api

API REST — Node.js · Express · PostgreSQL · Redis · Docker

## Rotas

| Método | Rota                     | Descrição                        |
|--------|--------------------------|----------------------------------|
| GET    | /health                  | Liveness probe                   |
| GET    | /health/ready            | Readiness probe (PG + Redis)     |
| GET    | /cardapio                | Lista cardápio (cache Redis)     |
| GET    | /cardapio/:id            | Item por ID                      |
| GET    | /pedidos                 | Lista pedidos (últimas 24h)      |
| GET    | /pedidos/:id             | Pedido por ID                    |
| POST   | /pedidos                 | Cria pedido                      |
| PATCH  | /pedidos/:id/status      | Atualiza status                  |
| GET    | /metrics                 | Métricas Prometheus              |

## Subir local (Docker Compose)

```bash
# 1. Copiar variáveis
cp .env.example .env

# 2. Subir tudo
docker compose up --build

# 3. Testar
curl http://localhost:3000/health
curl http://localhost:3000/cardapio
curl -X POST http://localhost:3000/pedidos \
  -H "Content-Type: application/json" \
  -d '{"mesa":5,"cliente_nome":"João","itens":[{"cardapio_id":1,"quantidade":2}]}'
```

## Variáveis de ambiente

Veja `.env.example`.

## Build da imagem

```bash
docker build -t lanchonete-api:latest .

# Push para ECR
aws ecr get-login-password --region sa-east-1 | \
  docker login --username AWS --password-stdin <ACCOUNT>.dkr.ecr.sa-east-1.amazonaws.com

docker tag  lanchonete-api:latest <ACCOUNT>.dkr.ecr.sa-east-1.amazonaws.com/lanchonete-api:latest
docker push <ACCOUNT>.dkr.ecr.sa-east-1.amazonaws.com/lanchonete-api:latest
```

## Estrutura

```
lanchonete-api/
├── src/
│   ├── app.js              # Entry point Express + Prometheus
│   ├── logger.js           # Winston JSON/colorido
│   ├── routes/
│   │   ├── pedidos.js      # GET/POST/PATCH /pedidos
│   │   ├── cardapio.js     # GET /cardapio (cache Redis)
│   │   └── health.js       # GET /health + /health/ready
│   ├── db/
│   │   └── postgres.js     # Pool PG com retry
│   └── cache/
│       └── redis.js        # ioredis com helpers get/set/del
├── infra/sql/
│   ├── schema.sql          # DDL completo
│   └── seed.sql            # Dados iniciais
├── Dockerfile              # Multi-stage, usuário não-root
├── docker-compose.yml      # Ambiente local completo
└── .env.example
```
