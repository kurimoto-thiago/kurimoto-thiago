# Manual de Implantação — AWS Learner Labs

> **Restrições do Learner Labs aplicadas neste guia**
> - Região: **us-east-1** (única disponível)
> - IAM: use sempre **LabRole** / **LabInstanceProfile** — criação de roles é bloqueada
> - RDS: **gp2**, sem Multi-AZ, sem Enhanced Monitoring, `db.t3.micro`
> - ElastiCache: **1 nó** (`cache.t3.micro`), sem failover, sem criptografia em repouso
> - Lambda: **x86_64** (arm64 indisponível), máx. 10 execuções concorrentes
> - EC2: **máx. 9 instâncias** no total; ASG `min=1 max=2`
> - Não há suporte a EKS — use EC2 ou ECS Fargate

---

## Pré-requisitos (uma única vez)

```bash
# Ferramentas necessárias
node --version   # >= 20
terraform -version   # >= 1.6
aws --version    # >= 2.x
docker --version
sls --version    # Serverless Framework 3 (npm install -g serverless)
```

### Credenciais do Learner Labs

1. No painel do Learner Labs clique em **AWS Details → Show**
2. Copie `aws_access_key_id`, `aws_secret_access_key` e `aws_session_token`

```bash
aws configure
# AWS Access Key ID:     <aws_access_key_id>
# AWS Secret Access Key: <aws_secret_access_key>
# Default region name:   us-east-1
# Output format:         json

# Session token (obrigatório no Learner Labs)
aws configure set aws_session_token <aws_session_token>
```

> **Atenção**: a sessão expira a cada ~4 horas. Repita este passo quando receber `ExpiredTokenException`.

### Verificar LabRole disponível

```bash
aws iam get-role --role-name LabRole \
  --query 'Role.Arn' --output text
# Saída esperada: arn:aws:iam::<ACCOUNT_ID>:role/LabRole
```

---

## Parte 1 — Infraestrutura Compartilhada (VPC + RDS + ElastiCache)

```bash
cd infra/

# Inicializar
terraform init

# Revisar variáveis
cat terraform.tfvars.example
```

Crie `infra/terraform.tfvars`:

```hcl
region            = "us-east-1"
project_name      = "lanchonete"
db_password       = "SenhaForte123!"   # mude para produção
db_instance_class = "db.t3.micro"
redis_node_type   = "cache.t3.micro"
```

```bash
terraform plan -var-file=terraform.tfvars
terraform apply -var-file=terraform.tfvars -auto-approve
```

Resultado esperado:
```
Outputs:
db_host    = "lanchonete-postgres.xxxxxxxxx.us-east-1.rds.amazonaws.com"
redis_host = "lanchonete-redis.xxxxxx.ng.0001.use1.cache.amazonaws.com"
vpc_id     = "vpc-xxxxxxxxxxxxxxxxx"
```

### Parametrizar segredos no SSM

```bash
ACCOUNT=$(aws sts get-caller-identity --query Account --output text)
REGION=us-east-1

# Obter endpoints criados pelo Terraform
DB_HOST=$(terraform output -raw db_host)
REDIS_HOST=$(terraform output -raw redis_host)

# Armazenar no SSM
aws ssm put-parameter --name /lanchonete/prod/db_host \
  --type String --value "$DB_HOST" --region $REGION --overwrite

aws ssm put-parameter --name /lanchonete/prod/db_password \
  --type SecureString --value "SenhaForte123!" --region $REGION --overwrite

aws ssm put-parameter --name /lanchonete/prod/redis_host \
  --type String --value "$REDIS_HOST" --region $REGION --overwrite

aws ssm put-parameter --name /lanchonete/prod/jwt_secret \
  --type SecureString --value "$(openssl rand -hex 32)" --region $REGION --overwrite

aws ssm put-parameter --name /lanchonete/prod/pix_chave \
  --type String --value "00.000.000/0001-00" --region $REGION --overwrite

aws ssm put-parameter --name /lanchonete/prod/pix_nome \
  --type String --value "LANCHONETE" --region $REGION --overwrite

aws ssm put-parameter --name /lanchonete/prod/pix_cidade \
  --type String --value "SAO PAULO" --region $REGION --overwrite
```

### Inicializar banco de dados

```bash
# Acesso via Session Manager (sem SSH necessário)
# Temporariamente libere o RDS para acesso via Bastion ou Cloud9

# Opção 1 — Cloud9 dentro da mesma VPC
psql -h $DB_HOST -U lanchonete_user -d lanchonete \
  -f infra/sql/schema.sql

# Opção 2 — SSM Port Forwarding
INSTANCE_ID=$(aws ec2 describe-instances \
  --filters "Name=tag:Name,Values=lanchonete-app" \
  --query 'Reservations[0].Instances[0].InstanceId' --output text)

aws ssm start-session --target $INSTANCE_ID \
  --document-name AWS-StartPortForwardingSessionToRemoteHost \
  --parameters "host=$DB_HOST,portNumber=5432,localPortNumber=5432"
# Em outro terminal:
psql -h localhost -p 5432 -U lanchonete_user -d lanchonete \
  -f infra/sql/schema.sql
```

---

## Parte 2 — Deploy EC2

### 2.1 Criar bucket S3 para artefatos

```bash
aws s3 mb s3://lanchonete-artifacts-$ACCOUNT --region us-east-1
```

### 2.2 Provisionar EC2 + ASG + ALB

```bash
# Obter IDs da VPC criada na Parte 1
VPC_ID=$(cd infra && terraform output -raw vpc_id)
PRIVATE_SUBNETS=$(cd infra && terraform output -json private_subnet_ids | jq -r 'join(",")')
PUBLIC_SUBNETS=$(cd infra && terraform output -json public_subnet_ids | jq -r 'join(",")')
SG_APP=$(cd infra && terraform output -raw sg_app_id)
SG_ALB=$(cd infra && terraform output -raw sg_alb_id)

cd infra/ec2/
terraform init

terraform apply -auto-approve \
  -var="vpc_id=$VPC_ID" \
  -var="private_subnet_ids=[\"${PRIVATE_SUBNETS//,/\",\"}\"]" \
  -var="public_subnet_ids=[\"${PUBLIC_SUBNETS//,/\",\"}\"]" \
  -var="sg_app_id=$SG_APP" \
  -var="sg_alb_id=$SG_ALB" \
  -var="s3_bucket=lanchonete-artifacts-$ACCOUNT" \
  -var="key_name=vockey"
```

> O `key_name=vockey` é o par de chaves padrão do Learner Labs. Disponível em **AWS Details → Download PEM**.

### 2.3 Empacotar e publicar aplicação

```bash
cd ../../   # raiz do projeto

npm install --omit=dev
tar -czf lanchonete-api.tar.gz \
  src/ node_modules/ package.json .env.example

aws s3 cp lanchonete-api.tar.gz \
  s3://lanchonete-artifacts-$ACCOUNT/lanchonete-api.tar.gz
```

O User Data da EC2 baixa e instala o pacote automaticamente na inicialização. Para atualizar instâncias existentes:

```bash
aws autoscaling start-instance-refresh \
  --auto-scaling-group-name lanchonete-asg \
  --preferences '{"MinHealthyPercentage":50,"InstanceWarmup":120}'
```

### 2.4 Verificar

```bash
ALB_DNS=$(cd infra/ec2 && terraform output -raw alb_dns)
curl http://$ALB_DNS/health
# {"status":"ok"}
```

---

## Parte 3 — Deploy Lambda (Serverless Framework)

### 3.1 Configurar LabRole no serverless.yml

Edite `infra/serverless/serverless.yml` e substitua `<ACCOUNT_ID>`:

```yaml
provider:
  iam:
    deploymentRole: arn:aws:iam::<ACCOUNT_ID>:role/LabRole
```

Obtenha o Account ID:
```bash
aws sts get-caller-identity --query Account --output text
```

### 3.2 Parâmetros extras de SSM necessários

```bash
SG_LAMBDA=$(cd infra && terraform output -raw sg_app_id)
SUBNET_1=$(cd infra && terraform output -json private_subnet_ids | jq -r '.[0]')
SUBNET_2=$(cd infra && terraform output -json private_subnet_ids | jq -r '.[1]')

aws ssm put-parameter --name /lanchonete/prod/sg_lambda_id \
  --type String --value "$SG_LAMBDA" --overwrite
aws ssm put-parameter --name /lanchonete/prod/private_subnet_1 \
  --type String --value "$SUBNET_1" --overwrite
aws ssm put-parameter --name /lanchonete/prod/private_subnet_2 \
  --type String --value "$SUBNET_2" --overwrite
```

### 3.3 Deploy

```bash
npm install --omit=dev
npx sls deploy --stage prod --region us-east-1
```

Saída esperada:
```
endpoints:
  GET  - https://xxxxxxxxxx.execute-api.us-east-1.amazonaws.com/health
  POST - https://xxxxxxxxxx.execute-api.us-east-1.amazonaws.com/auth/login
  ...
```

### 3.4 Verificar

```bash
SLS_URL=$(npx sls info --stage prod --verbose 2>/dev/null | grep ServiceEndpoint | awk '{print $2}')
curl $SLS_URL/health
```

### 3.5 Atualização rápida (sem redeploy completo)

```bash
# Empacotar
zip -r lambda.zip src/ node_modules/ package.json

# Atualizar apenas o código
aws lambda update-function-code \
  --function-name lanchonete-api-prod \
  --zip-file fileb://lambda.zip \
  --architectures x86_64

aws lambda wait function-updated \
  --function-name lanchonete-api-prod
```

---

## Parte 4 — Deploy ECS Fargate

### 4.1 Provisionar ECR + Cluster

```bash
VPC_ID=$(cd infra && terraform output -raw vpc_id)
PRIVATE_SUBNETS_JSON=$(cd infra && terraform output -json private_subnet_ids)
SG_APP=$(cd infra && terraform output -raw sg_app_id)

cd infra/container/ecs/
terraform init

# Primeiro apply — cria apenas o ECR (sem imagem ainda)
terraform apply -auto-approve \
  -var="vpc_id=$VPC_ID" \
  -var="private_subnet_ids=$PRIVATE_SUBNETS_JSON" \
  -var="sg_app_id=$SG_APP" \
  -var="alb_target_group_arn=arn:placeholder" \
  -var="ecr_image_uri=placeholder" \
  -target=aws_ecr_repository.app \
  -target=aws_ecs_cluster.app \
  -target=aws_cloudwatch_log_group.app
```

### 4.2 Build e push da imagem

```bash
ACCOUNT=$(aws sts get-caller-identity --query Account --output text)
ECR_REGISTRY="$ACCOUNT.dkr.ecr.us-east-1.amazonaws.com"
IMAGE_URI="$ECR_REGISTRY/lanchonete-api:latest"

# Login
aws ecr get-login-password --region us-east-1 | \
  docker login --username AWS --password-stdin $ECR_REGISTRY

# Build (usa Dockerfile multi-stage existente)
docker build -t lanchonete-api:latest .
docker tag lanchonete-api:latest $IMAGE_URI
docker push $IMAGE_URI
```

### 4.3 Deploy do serviço

```bash
# Obter ARN do target group criado pelo módulo EC2
TG_ARN=$(cd ../../ec2 && terraform output -raw target_group_arn)

terraform apply -auto-approve \
  -var="vpc_id=$VPC_ID" \
  -var="private_subnet_ids=$PRIVATE_SUBNETS_JSON" \
  -var="sg_app_id=$SG_APP" \
  -var="alb_target_group_arn=$TG_ARN" \
  -var="ecr_image_uri=$IMAGE_URI" \
  -var="desired_count=1"
```

### 4.4 Verificar

```bash
ALB_DNS=$(cd ../../../infra/ec2 && terraform output -raw alb_dns)
curl http://$ALB_DNS/health
```

### 4.5 Atualização de imagem

```bash
docker build -t $IMAGE_URI .
docker push $IMAGE_URI

aws ecs update-service \
  --cluster lanchonete-cluster \
  --service lanchonete-api \
  --force-new-deployment

aws ecs wait services-stable \
  --cluster lanchonete-cluster \
  --services lanchonete-api
```

---

## Solução de Problemas

### Credenciais expiradas
```bash
# Sintoma: ExpiredTokenException ou InvalidClientTokenId
# Solução: renovar credenciais no painel do Learner Labs e reconfigurá-las
aws configure set aws_session_token <novo_token>
```

### EC2 não inicializa corretamente
```bash
# Ver log do User Data
INSTANCE_ID=i-xxxxxxxxx
aws ssm start-session --target $INSTANCE_ID
# Dentro da sessão:
sudo cat /var/log/user-data.log
```

### Lambda com timeout na VPC
```bash
# Verificar se a subnet privada tem rota para NAT Gateway
aws ec2 describe-route-tables \
  --filters "Name=association.subnet-id,Values=$SUBNET_1"
```

### RDS recusa conexão
```bash
# Verificar security group
aws ec2 describe-security-groups --group-ids $SG_RDS
# Porta 5432 deve estar liberada para o sg_app_id
```

### Limite de instâncias EC2
```bash
# Learner Labs: máx. 9 instâncias no total (incluindo NAT, Bastion, etc.)
aws ec2 describe-instances \
  --query 'Reservations[*].Instances[?State.Name==`running`].[InstanceId,InstanceType]' \
  --output table
```

---

## Limpeza (evitar cobranças)

```bash
# 1. Parar serviço ECS
aws ecs update-service --cluster lanchonete-cluster \
  --service lanchonete-api --desired-count 0

# 2. Destruir infra ECS
cd infra/container/ecs && terraform destroy -auto-approve

# 3. Destruir infra EC2
cd ../../ec2 && terraform destroy -auto-approve \
  -var="vpc_id=$VPC_ID" \
  -var="private_subnet_ids=$PRIVATE_SUBNETS_JSON" \
  -var="public_subnet_ids=$PUBLIC_SUBNETS_JSON" \
  -var="sg_app_id=$SG_APP" \
  -var="sg_alb_id=$SG_ALB" \
  -var="s3_bucket=lanchonete-artifacts-$ACCOUNT"

# 4. Remover Lambda
npx sls remove --stage prod --region us-east-1

# 5. Destruir infra base
cd ../../ && terraform destroy -var-file=terraform.tfvars -auto-approve
```

> **Importante**: o Learner Labs encerra a sessão automaticamente após o tempo limite. Recursos criados são **destruídos ao fim da sessão** — não confie na persistência entre sessões sem backend remoto.
