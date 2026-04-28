# Manual 02 — Implantação em AWS Lambda (Serverless)

| Campo         | Valor                                      |
|---------------|--------------------------------------------|
| Modo          | Serverless — Lambda + API Gateway + RDS + ElastiCache |
| Dificuldade   | ⭐⭐⭐ Avançado                              |
| Tempo estimado| 60 – 90 minutos                            |
| Ambiente      | AWS Learner Labs (us-east-1)               |

---

## Visão Geral

Neste modo, a aplicação Node.js roda como função Lambda, invocada pelo API Gateway HTTP. Não há servidor para gerenciar — a AWS cuida de escalar, atualizar e monitorar automaticamente.

```
┌─────────────────────────────────────────────────────────┐
│                        Internet                          │
└──────────────────────────┬──────────────────────────────┘
                           │ HTTPS
┌──────────────────────────▼──────────────────────────────┐
│  API GATEWAY HTTP (API v2)                               │
│  https://xxxxxxxxxx.execute-api.us-east-1.amazonaws.com  │
│  • Roteamento de rotas                                   │
│  • Throttling (rate limiting)                            │
└──────────────────────────┬──────────────────────────────┘
                           │ Invocação síncrona
┌──────────────────────────▼──────────────────────────────┐
│  AWS LAMBDA  (Node.js 20, x86_64, 512 MB)               │
│  lanchonete-api-prod                                     │
│  • Wrapper serverless-http adapta Express → Lambda       │
│  • Concorrência reservada: 10 (limite Learner Labs)      │
│  • Warm-up agendado a cada 5 min                         │
└────────────┬──────────────────────────┬─────────────────┘
             │ TCP :5432                │ TCP :6379
┌────────────▼────────────┐  ┌─────────▼─────────────────┐
│  RDS PostgreSQL 16       │  │  ElastiCache Redis 6       │
│  (db.t3.micro, gp2)     │  │  (cache.t3.micro, 1 nó)   │
│  Subnet privada          │  │  Subnet privada            │
└─────────────────────────┘  └───────────────────────────┘
```

**Por que esse modo?**
- **Sem servidor para gerenciar**: escala automaticamente de 0 a N invocações
- **Paga por uso**: cobra por requisição e duração (ms), não por hora de servidor
- **Cold start**: primeira invocação após inatividade demora mais (~1-3s)

**Recursos AWS utilizados:**
- Lambda function (runtime Node.js 20)
- API Gateway HTTP (v2)
- CloudWatch Logs (automático)
- RDS PostgreSQL (db.t3.micro)
- ElastiCache Redis (cache.t3.micro)
- VPC com subnets privadas e NAT Gateway
- SSM Parameter Store (segredos)

---

## Pré-requisitos

- [ ] Conta no AWS Learner Labs ativa
- [ ] Node.js ≥ 20 instalado (`node --version`)
- [ ] Terraform ≥ 1.6 instalado
- [ ] AWS CLI ≥ 2 instalado
- [ ] Serverless Framework 3 instalado globalmente

```bash
# Instalar Serverless Framework (caso necessário)
npm install -g serverless

# Verificar versão (deve ser 3.x)
sls --version
```

---

## Passo 1 — Configurar Credenciais AWS

> As credenciais do Learner Labs **expiram a cada 4 horas**.

**1.1** No painel do Learner Labs: **AWS Details → Show**

**1.2** Configure o AWS CLI:

```bash
aws configure
# Access Key ID:     [cole aqui]
# Secret Access Key: [cole aqui]
# Default region:    us-east-1
# Output format:     json

aws configure set aws_session_token [cole o token aqui]
```

**1.3** Obtenha e anote o Account ID:

```bash
ACCOUNT=$(aws sts get-caller-identity --query Account --output text)
echo "Account ID: $ACCOUNT"
```

---

## Passo 2 — Criar a Infraestrutura Compartilhada (VPC + RDS + ElastiCache)

> O Lambda precisa de RDS e ElastiCache em subnet privada. Este passo cria toda essa base.

**2.1** Entrar no diretório da infraestrutura base:

```bash
cd lanchonete-api/infra/
```

**2.2** Criar o arquivo de variáveis:

```bash
cat > terraform.tfvars <<'EOF'
region            = "us-east-1"
project_name      = "lanchonete"
db_password       = "SenhaForte123!"
db_instance_class = "db.t3.micro"
redis_node_type   = "cache.t3.micro"
EOF
```

> **Atenção:** O arquivo `infra/main.tf` usa a região `sa-east-1` por padrão. Antes de continuar, atualize-o para `us-east-1`:

```bash
sed -i 's/sa-east-1/us-east-1/g' main.tf
sed -i 's/sa-east-1/us-east-1/g' modules/vpc/main.tf
sed -i 's/sa-east-1/us-east-1/g' modules/rds/main.tf
```

**2.3** Ajustar o módulo RDS para o Learner Labs:

O RDS padrão usa `multi_az = true` e `monitoring_interval = 60` (Enhanced Monitoring), que são bloqueados no Learner Labs. Edite `modules/rds/main.tf`:

```bash
# Desativar multi_az, enhanced monitoring e deletion_protection
sed -i 's/multi_az               = var.multi_az/multi_az               = false/' modules/rds/main.tf
sed -i 's/monitoring_interval                   = 60/monitoring_interval = 0/' modules/rds/main.tf
sed -i 's/monitoring_role_arn                   = aws_iam_role.rds_monitoring.arn/\/\/ monitoring_role_arn = null/' modules/rds/main.tf
sed -i 's/storage_type      = "gp3"/storage_type      = "gp2"/' modules/rds/main.tf
sed -i 's/deletion_protection    = var.deletion_protection/deletion_protection    = false/' modules/rds/main.tf
sed -i 's/performance_insights_enabled          = true/performance_insights_enabled = false/' modules/rds/main.tf
```

**2.4** Inicializar e aplicar:

```bash
terraform init
terraform plan -var-file=terraform.tfvars
terraform apply -var-file=terraform.tfvars -auto-approve
```

> **Tempo estimado:** 15–20 minutos (RDS e ElastiCache demoram para provisionar).

Ao final, anote os outputs:
```
Outputs:

db_host    = "lanchonete-postgres.xxxxxxxxx.us-east-1.rds.amazonaws.com"
redis_host = "lanchonete-redis.xxxxxx.use1.cache.amazonaws.com"
vpc_id     = "vpc-xxxxxxxxxxxxxxxxx"
sg_app_id  = "sg-xxxxxxxxxxxxxxxxx"
```

---

## Passo 3 — Armazenar Segredos no SSM Parameter Store

> O Lambda lê configurações diretamente do SSM — sem arquivos `.env`.

```bash
REGION=us-east-1
DB_HOST=$(terraform output -raw db_host)
REDIS_HOST=$(terraform output -raw redis_host)
SG_LAMBDA=$(terraform output -raw sg_app_id)
SUBNET_1=$(terraform output -json private_subnet_ids | python3 -c "import sys,json;print(json.load(sys.stdin)[0])")
SUBNET_2=$(terraform output -json private_subnet_ids | python3 -c "import sys,json;print(json.load(sys.stdin)[1])")

# Armazenar parâmetros
aws ssm put-parameter --name /lanchonete/prod/db_host \
  --type String --value "$DB_HOST" --region $REGION --overwrite

aws ssm put-parameter --name /lanchonete/prod/db_password \
  --type SecureString --value "SenhaForte123!" --region $REGION --overwrite

aws ssm put-parameter --name /lanchonete/prod/redis_host \
  --type String --value "$REDIS_HOST" --region $REGION --overwrite

aws ssm put-parameter --name /lanchonete/prod/sg_lambda_id \
  --type String --value "$SG_LAMBDA" --region $REGION --overwrite

aws ssm put-parameter --name /lanchonete/prod/private_subnet_1 \
  --type String --value "$SUBNET_1" --region $REGION --overwrite

aws ssm put-parameter --name /lanchonete/prod/private_subnet_2 \
  --type String --value "$SUBNET_2" --region $REGION --overwrite
```

Verificar se foram criados:
```bash
aws ssm get-parameters-by-path --path /lanchonete/prod/ \
  --query 'Parameters[*].Name' --output table
```

---

## Passo 4 — Inicializar o Banco de Dados

> O RDS está em subnet privada. Use o SSM Port Forwarding para conectar.

**4.1** Encontre uma instância EC2 existente ou crie um bastion temporário:

```bash
# Verificar se há alguma instância disponível para port forwarding
aws ec2 describe-instances \
  --filters "Name=instance-state-name,Values=running" \
  --query 'Reservations[*].Instances[*].[InstanceId,Tags[?Key==`Name`].Value|[0]]' \
  --output table
```

**4.2** Iniciar port forwarding (em um terminal separado):

```bash
INSTANCE_ID=i-xxxxxxxxx   # substitua pelo ID de uma instância

aws ssm start-session \
  --target $INSTANCE_ID \
  --document-name AWS-StartPortForwardingSessionToRemoteHost \
  --parameters "host=$DB_HOST,portNumber=5432,localPortNumber=5432"
```

**4.3** Em outro terminal, executar o schema:

```bash
# Instalar o cliente psql se necessário
# Ubuntu: sudo apt install -y postgresql-client
# macOS:  brew install libpq

psql -h localhost -p 5432 -U lanchonete_user -d lanchonete \
  -f lanchonete-api/infra/sql/schema.sql

psql -h localhost -p 5432 -U lanchonete_user -d lanchonete \
  -f lanchonete-api/infra/sql/seed.sql
```

Quando solicitado, use a senha: `SenhaForte123!`

---

## Passo 5 — Configurar o serverless.yml

**5.1** Abrir o arquivo:

```bash
cd lanchonete-api/infra/serverless/
cat serverless.yml
```

**5.2** Substituir `<ACCOUNT_ID>` pelo Account ID real:

```bash
sed -i "s/<ACCOUNT_ID>/$ACCOUNT/g" serverless.yml
```

**5.3** Verificar se ficou correto:

```bash
grep "LabRole" serverless.yml
```

Saída esperada:
```
    role: arn:aws:iam::123456789012:role/LabRole
    deploymentRole: arn:aws:iam::123456789012:role/LabRole
```

---

## Passo 6 — Instalar as dependências da aplicação

```bash
cd ../../   # raiz do projeto lanchonete-api/

npm install --omit=dev
```

---

## Passo 7 — Fazer o deploy da função Lambda

```bash
cd infra/serverless/

npx sls deploy --stage prod --region us-east-1
```

> **Tempo estimado:** 3–5 minutos (empacota o código e faz upload para S3 antes de criar a função).

Saída esperada ao final:
```
✔ Service deployed to stack lanchonete-api-prod

endpoints:
  GET  - https://xxxxxxxxxx.execute-api.us-east-1.amazonaws.com/health
  GET  - https://xxxxxxxxxx.execute-api.us-east-1.amazonaws.com/cardapio
  POST - https://xxxxxxxxxx.execute-api.us-east-1.amazonaws.com/pedidos
  ...

functions:
  app: lanchonete-api-prod-app (X MB)
```

**Anote a URL base** (endpoint raiz, sem path).

---

## Passo 8 — Verificar o funcionamento

**8.1** Obter a URL do serviço:

```bash
SLS_URL=$(npx sls info --stage prod --verbose 2>/dev/null | \
  grep ServiceEndpoint | awk '{print $2}')
echo "URL: $SLS_URL"
```

**8.2** Testar o health check:

```bash
curl $SLS_URL/health
```

Saída esperada:
```json
{"status": "ok"}
```

> **Atenção — Cold Start:** A primeira chamada após um período de inatividade pode demorar 2–4 segundos. Isso é normal e chamado de "cold start". O warm-up agendado a cada 5 minutos reduz esse problema.

**8.3** Testar o cardápio:

```bash
curl $SLS_URL/cardapio | python3 -m json.tool | head -40
```

---

## Passo 9 — Usar a CLI apontando para o Lambda

```bash
API_URL=$SLS_URL bash lanchonete-api/src/cli/lanchonete.sh
```

---

## Passo 10 — Usar a interface web

Abra o arquivo `lanchonete-api/src/public/index.html` no browser e:

1. No campo **API** no topo, informe: `https://xxxxxxxxxx.execute-api.us-east-1.amazonaws.com`
2. Clique em **Aplicar**
3. O cardápio deve carregar automaticamente

> **CORS:** O API Gateway está configurado para aceitar requisições de qualquer origem (`allowedOrigins: ['*']`).

---

## Passo 11 — Monitorar logs (CloudWatch)

```bash
# Ver logs em tempo real (requer serverless-offline instalado)
npx sls logs -f app --stage prod --tail
```

Ou pelo console AWS:
1. Acesse **CloudWatch → Log Groups**
2. Procure `/aws/lambda/lanchonete-api-prod-app`

---

## Atualização rápida (sem redeploy completo)

Após alterar o código, para atualizar apenas a função:

```bash
cd lanchonete-api/

# Empacotar
zip -r /tmp/lambda.zip src/ node_modules/ package.json

# Atualizar apenas o código
aws lambda update-function-code \
  --function-name lanchonete-api-prod-app \
  --zip-file fileb:///tmp/lambda.zip \
  --architectures x86_64

# Aguardar atualização
aws lambda wait function-updated \
  --function-name lanchonete-api-prod-app

echo "Função atualizada!"
```

---

## Solução de Problemas

### `ExpiredTokenException` durante o deploy

As credenciais expiraram. Repita o **Passo 1** completo.

### `AccessDeniedException` no SSM

```bash
# Verificar se o parâmetro existe
aws ssm get-parameter --name /lanchonete/prod/db_host --region us-east-1
```

Se não existir, repita o **Passo 3**.

### Timeout no Lambda (504)

O Lambda está na VPC e precisa de acesso ao RDS. Verificar:

```bash
# Verificar security group do Lambda
aws ec2 describe-security-groups \
  --group-ids $SG_LAMBDA \
  --query 'SecurityGroups[*].{Name:GroupName,Outbound:IpPermissionsEgress}' \
  --output table
```

O egress deve permitir todo o tráfego (`0.0.0.0/0`).

### Erro de conexão com RDS

```bash
# Verificar se o RDS está disponível
aws rds describe-db-instances \
  --query 'DBInstances[*].[DBInstanceIdentifier,DBInstanceStatus,Endpoint.Address]' \
  --output table
```

O status deve ser `available`.

---

## Limpeza

Execute sempre ao final da aula:

```bash
# 1. Remover a função Lambda e API Gateway
cd lanchonete-api/infra/serverless/
npx sls remove --stage prod --region us-east-1

# 2. Remover a infraestrutura base (RDS, ElastiCache, VPC)
cd ../
terraform destroy -var-file=terraform.tfvars -auto-approve
```

> **Atenção:** O RDS cria um snapshot final antes de ser removido. Remova-o manualmente no console se quiser liberar espaço.

---

## Conceitos abordados nesta aula

| Conceito | Onde aparece |
|----------|-------------|
| Serverless / FaaS | Lambda executa código sem servidor |
| Event-driven | Lambda invocado por evento do API Gateway |
| Cold start | Primeira invocação após inatividade |
| Concorrência reservada | Limite de execuções paralelas |
| API Gateway HTTP (v2) | Roteamento de requisições HTTP para Lambda |
| SSM Parameter Store | Gestão segura de segredos e configurações |
| VPC Lambda | Lambda na mesma rede do RDS/Redis |
| Serverless Framework | Ferramenta de deploy de funções serverless |
| Warm-up agendado | EventBridge Schedule invoca Lambda periodicamente |
| Infrastructure as Code | serverless.yml define toda a infraestrutura |
