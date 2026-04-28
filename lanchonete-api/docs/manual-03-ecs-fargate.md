# Manual 03 — Implantação em ECS Fargate (Containers)

| Campo         | Valor                                          |
|---------------|------------------------------------------------|
| Modo          | Container — ECS Fargate + ECR + RDS + ElastiCache |
| Dificuldade   | ⭐⭐⭐⭐ Avançado                                |
| Tempo estimado| 90 – 120 minutos                               |
| Ambiente      | AWS Learner Labs (us-east-1)                   |

---

## Visão Geral

Neste modo, a aplicação é empacotada como imagem Docker e executada pelo ECS Fargate — serviço de containers gerenciado da AWS. Não é necessário gerenciar servidores para rodar os containers.

```
┌─────────────────────────────────────────────────────────┐
│                        Internet                          │
└──────────────────────────┬──────────────────────────────┘
                           │ HTTP :80
┌──────────────────────────▼──────────────────────────────┐
│  APPLICATION LOAD BALANCER (ALB)                         │
│  Subnet pública — balanceia entre tasks                  │
└──────────────────────────┬──────────────────────────────┘
                           │ HTTP :3000
┌──────────────────────────▼──────────────────────────────┐
│  ECS FARGATE — Cluster: lanchonete-cluster               │
│  Service: lanchonete-api                                 │
│  ┌──────────────────────┐  ┌──────────────────────────┐ │
│  │  Task (container)    │  │  Task (container)        │ │
│  │  Node.js :3000       │  │  Node.js :3000           │ │
│  │  512 CPU / 1024 MB   │  │  512 CPU / 1024 MB       │ │
│  └──────────────────────┘  └──────────────────────────┘ │
│  Subnet privada — sem IP público                         │
└────────────┬──────────────────────────┬─────────────────┘
             │                          │
┌────────────▼────────────┐  ┌─────────▼─────────────────┐
│  RDS PostgreSQL 16       │  │  ElastiCache Redis 6       │
│  (db.t3.micro, gp2)     │  │  (cache.t3.micro, 1 nó)   │
└─────────────────────────┘  └───────────────────────────┘

ECR (Elastic Container Registry):
Armazena a imagem Docker da aplicação
```

**Por que esse modo?**
- **Portabilidade**: a imagem Docker roda igual em qualquer ambiente
- **Escalabilidade automática**: o ECS ajusta o número de tasks conforme CPU
- **Sem gerenciar servidores**: Fargate cuida do hardware, SO e runtime

**Recursos AWS utilizados:**
- ECR (repositório de imagens Docker)
- ECS Cluster + Task Definition + Service
- Application Load Balancer
- RDS PostgreSQL (db.t3.micro)
- ElastiCache Redis (cache.t3.micro)
- VPC com subnets públicas e privadas
- SSM Parameter Store

---

## Pré-requisitos

- [ ] Conta no AWS Learner Labs ativa
- [ ] Docker instalado e rodando (`docker --version`)
- [ ] Terraform ≥ 1.6 instalado
- [ ] AWS CLI ≥ 2 instalado
- [ ] Repositório clonado localmente

```bash
# Verificar Docker
docker --version
docker info   # deve mostrar Server Running
```

---

## Passo 1 — Configurar Credenciais AWS

> As credenciais expiram a cada 4 horas. Repita quando necessário.

```bash
aws configure
# Access Key ID:     [Learner Labs → AWS Details → Show]
# Secret Access Key: [idem]
# Default region:    us-east-1
# Output format:     json

aws configure set aws_session_token [token]
```

Obtenha e anote o Account ID:

```bash
ACCOUNT=$(aws sts get-caller-identity --query Account --output text)
REGION=us-east-1
echo "Account: $ACCOUNT | Region: $REGION"
```

---

## Passo 2 — Criar a Infraestrutura Base (VPC + RDS + ElastiCache + ALB)

**2.1** Atualizar a região para us-east-1:

```bash
cd lanchonete-api/infra/

sed -i 's/sa-east-1/us-east-1/g' main.tf
sed -i 's/sa-east-1/us-east-1/g' modules/vpc/main.tf
sed -i 's/sa-east-1/us-east-1/g' modules/rds/main.tf
```

**2.2** Ajustar o módulo RDS para o Learner Labs (sem Enhanced Monitoring e sem Multi-AZ):

```bash
sed -i 's/multi_az               = var.multi_az/multi_az               = false/' modules/rds/main.tf
sed -i 's/monitoring_interval                   = 60/monitoring_interval = 0/' modules/rds/main.tf
sed -i 's/monitoring_role_arn                   = aws_iam_role.rds_monitoring.arn/\/\/ monitoring_role_arn = null/' modules/rds/main.tf
sed -i 's/storage_type      = "gp3"/storage_type      = "gp2"/' modules/rds/main.tf
sed -i 's/deletion_protection    = var.deletion_protection/deletion_protection    = false/' modules/rds/main.tf
sed -i 's/performance_insights_enabled          = true/performance_insights_enabled = false/' modules/rds/main.tf
```

**2.3** Criar o arquivo de variáveis:

```bash
cat > terraform.tfvars <<'EOF'
region            = "us-east-1"
project_name      = "lanchonete"
db_password       = "SenhaForte123!"
db_instance_class = "db.t3.micro"
redis_node_type   = "cache.t3.micro"
EOF
```

**2.4** Aplicar:

```bash
terraform init
terraform apply -var-file=terraform.tfvars -auto-approve
```

> **Tempo:** 15–20 minutos.

**2.5** Salvar outputs em variáveis de ambiente:

```bash
export VPC_ID=$(terraform output -raw vpc_id)
export SG_APP=$(terraform output -raw sg_app_id)
export SG_ALB=$(terraform output -raw sg_alb_id)
export DB_HOST=$(terraform output -raw db_host)
export REDIS_HOST=$(terraform output -raw redis_host)
export PRIVATE_SUBNETS=$(terraform output -json private_subnet_ids)
export PUBLIC_SUBNETS=$(terraform output -json public_subnet_ids)

echo "VPC: $VPC_ID"
echo "DB: $DB_HOST"
echo "Redis: $REDIS_HOST"
```

---

## Passo 3 — Armazenar Segredos no SSM

```bash
aws ssm put-parameter --name /lanchonete/prod/db_host \
  --type String --value "$DB_HOST" --overwrite

aws ssm put-parameter --name /lanchonete/prod/db_password \
  --type SecureString --value "SenhaForte123!" --overwrite

aws ssm put-parameter --name /lanchonete/prod/redis_host \
  --type String --value "$REDIS_HOST" --overwrite
```

---

## Passo 4 — Inicializar o Banco de Dados

O RDS está em subnet privada. Use um bastion (qualquer EC2 na mesma VPC):

**4.1** Criar uma EC2 bastion temporária (t3.micro) na subnet pública com SSM habilitado.

**4.2** Abrir port forwarding (terminal 1):

```bash
BASTION_ID=$(aws ec2 describe-instances \
  --filters "Name=instance-state-name,Values=running" \
  --query 'Reservations[0].Instances[0].InstanceId' --output text)

aws ssm start-session \
  --target $BASTION_ID \
  --document-name AWS-StartPortForwardingSessionToRemoteHost \
  --parameters "host=$DB_HOST,portNumber=5432,localPortNumber=5432"
```

**4.3** Aplicar o schema (terminal 2):

```bash
psql -h localhost -p 5432 -U lanchonete_user -d lanchonete \
  -f lanchonete-api/infra/sql/schema.sql

psql -h localhost -p 5432 -U lanchonete_user -d lanchonete \
  -f lanchonete-api/infra/sql/seed.sql
```

---

## Passo 5 — Criar o ECR e Fazer Build da Imagem Docker

**5.1** Entrar no diretório ECS:

```bash
cd lanchonete-api/infra/container/ecs/
```

**5.2** Atualizar a região no arquivo Terraform:

```bash
sed -i 's/sa-east-1/us-east-1/g' main.tf
```

**5.3** Corrigir as roles IAM para usar LabRole:

> No Learner Labs, não é possível criar roles IAM. Edite `main.tf` para remover os recursos `aws_iam_role` e usar o LabRole existente:

Abra `main.tf` em um editor e substitua os blocos de IAM:

```bash
# Remover criação de roles e usar LabRole
cat > /tmp/iam_patch.py <<'PYTHON'
import re, sys

content = open('main.tf').read()

# Substituir execution_role_arn pelo LabRole
content = re.sub(
  r'execution_role_arn\s*=\s*aws_iam_role\.task_exec\.arn',
  f'execution_role_arn = "arn:aws:iam::{sys.argv[1]}:role/LabRole"',
  content
)
content = re.sub(
  r'task_role_arn\s*=\s*aws_iam_role\.task\.arn',
  f'task_role_arn      = "arn:aws:iam::{sys.argv[1]}:role/LabRole"',
  content
)

open('main.tf', 'w').write(content)
print("IAM atualizado para LabRole")
PYTHON

python3 /tmp/iam_patch.py $ACCOUNT
```

**5.4** Criar apenas o ECR (primeiro apply — sem imagem ainda):

```bash
terraform init

terraform apply -auto-approve \
  -var="vpc_id=$VPC_ID" \
  -var="private_subnet_ids=$PRIVATE_SUBNETS" \
  -var="sg_app_id=$SG_APP" \
  -var="alb_target_group_arn=arn:placeholder" \
  -var="ecr_image_uri=placeholder" \
  -target=aws_ecr_repository.app \
  -target=aws_ecs_cluster.app \
  -target=aws_cloudwatch_log_group.app
```

Obter a URL do ECR:

```bash
ECR_REPO=$(terraform output -raw ecr_repo_url)
echo "ECR: $ECR_REPO"
```

---

## Passo 6 — Build e Push da Imagem Docker

**6.1** Entrar na raiz da aplicação:

```bash
cd lanchonete-api/
```

Verificar o Dockerfile:

```bash
cat Dockerfile
```

**6.2** Autenticar o Docker no ECR:

```bash
aws ecr get-login-password --region $REGION | \
  docker login --username AWS --password-stdin \
  $ACCOUNT.dkr.ecr.$REGION.amazonaws.com
```

Saída esperada:
```
Login Succeeded
```

**6.3** Build da imagem:

```bash
IMAGE_URI="$ECR_REPO:latest"

docker build -t lanchonete-api:latest .
docker tag lanchonete-api:latest $IMAGE_URI
```

> **Tempo:** 2–5 minutos dependendo da velocidade de conexão.

**6.4** Push para o ECR:

```bash
docker push $IMAGE_URI
```

Verificar se a imagem chegou:

```bash
aws ecr describe-images \
  --repository-name lanchonete-api \
  --query 'imageDetails[*].[imageTags[0],imageSizeInBytes]' \
  --output table
```

---

## Passo 7 — Criar o ALB (Load Balancer)

O serviço ECS precisa de um ALB para distribuir o tráfego. Se o módulo EC2 não foi usado, crie o ALB:

```bash
cd ../ec2/

sed -i 's/sa-east-1/us-east-1/g' main.tf

terraform init

# Criar apenas o ALB e Target Group
terraform apply -auto-approve \
  -var="vpc_id=$VPC_ID" \
  -var="private_subnet_ids=[$(echo $PRIVATE_SUBNETS | tr -d '[]')]" \
  -var="public_subnet_ids=[$(echo $PUBLIC_SUBNETS | tr -d '[]')]" \
  -var="sg_app_id=$SG_APP" \
  -var="sg_alb_id=$SG_ALB" \
  -var="s3_bucket=placeholder" \
  -target=aws_lb.app \
  -target=aws_lb_target_group.app \
  -target=aws_lb_listener.http

export TG_ARN=$(terraform output -raw target_group_arn)
export ALB_DNS=$(terraform output -raw alb_dns)
echo "ALB: http://$ALB_DNS"
echo "Target Group: $TG_ARN"
```

---

## Passo 8 — Deploy do Serviço ECS

```bash
cd ../container/ecs/

terraform apply -auto-approve \
  -var="vpc_id=$VPC_ID" \
  -var="private_subnet_ids=$PRIVATE_SUBNETS" \
  -var="sg_app_id=$SG_APP" \
  -var="alb_target_group_arn=$TG_ARN" \
  -var="ecr_image_uri=$IMAGE_URI" \
  -var="desired_count=1"
```

> **Tempo:** 3–5 minutos para o serviço estabilizar.

---

## Passo 9 — Verificar o funcionamento

**9.1** Verificar se as tasks estão rodando:

```bash
aws ecs list-tasks \
  --cluster lanchonete-cluster \
  --query 'taskArns' \
  --output table
```

**9.2** Testar o health check via ALB:

```bash
# Aguardar o ALB propagar (30–60 segundos)
sleep 60

curl http://$ALB_DNS/health
```

Saída esperada:
```json
{"status": "ok"}
```

**9.3** Testar o cardápio:

```bash
curl http://$ALB_DNS/cardapio | python3 -m json.tool | head -30
```

---

## Passo 10 — Usar a CLI e a Interface Web

**CLI:**
```bash
API_URL=http://$ALB_DNS bash lanchonete-api/src/cli/lanchonete.sh
```

**Interface Web:**

Abra `lanchonete-api/src/public/index.html` no browser e configure o campo API:
```
http://<ALB_DNS>
```

---

## Passo 11 — Monitorar logs (CloudWatch)

```bash
# Obter o log stream mais recente
LOG_STREAM=$(aws logs describe-log-streams \
  --log-group-name /ecs/lanchonete \
  --order-by LastEventTime \
  --descending \
  --query 'logStreams[0].logStreamName' \
  --output text)

# Ver logs
aws logs get-log-events \
  --log-group-name /ecs/lanchonete \
  --log-stream-name "$LOG_STREAM" \
  --query 'events[*].message' \
  --output text | tail -30
```

---

## Atualização da imagem (redeploy)

Após alterar o código:

```bash
# Rebuild e push
docker build -t $IMAGE_URI .
docker push $IMAGE_URI

# Forçar novo deploy
aws ecs update-service \
  --cluster lanchonete-cluster \
  --service lanchonete-api \
  --force-new-deployment

# Aguardar estabilização
aws ecs wait services-stable \
  --cluster lanchonete-cluster \
  --services lanchonete-api

echo "Deploy concluído!"
```

---

## Solução de Problemas

### Tasks com status `STOPPED`

```bash
# Ver o motivo de parada
TASK_ARN=$(aws ecs list-tasks --cluster lanchonete-cluster \
  --desired-status STOPPED \
  --query 'taskArns[0]' --output text)

aws ecs describe-tasks \
  --cluster lanchonete-cluster \
  --tasks $TASK_ARN \
  --query 'tasks[*].containers[*].{Status:lastStatus,Reason:reason,Exit:exitCode}' \
  --output table
```

### Health check falhando no ALB

```bash
# Verificar se a porta 3000 está exposta no container
aws ecs describe-task-definition \
  --task-definition lanchonete-api \
  --query 'taskDefinition.containerDefinitions[*].portMappings'
```

### Erro de credenciais IAM no container

O Learner Labs bloqueia a criação de roles. Verifique se o patch do **Passo 5.3** foi aplicado corretamente:

```bash
grep "LabRole" main.tf
```

### ECR: `no basic auth credentials`

Reautentique o Docker:
```bash
aws ecr get-login-password --region $REGION | \
  docker login --username AWS --password-stdin \
  $ACCOUNT.dkr.ecr.$REGION.amazonaws.com
```

---

## Limpeza

```bash
# 1. Parar o serviço ECS
aws ecs update-service \
  --cluster lanchonete-cluster \
  --service lanchonete-api \
  --desired-count 0

# 2. Remover infraestrutura ECS
cd lanchonete-api/infra/container/ecs/
terraform destroy -auto-approve \
  -var="vpc_id=$VPC_ID" \
  -var="private_subnet_ids=$PRIVATE_SUBNETS" \
  -var="sg_app_id=$SG_APP" \
  -var="alb_target_group_arn=$TG_ARN" \
  -var="ecr_image_uri=$IMAGE_URI"

# 3. Remover ALB/Target Group
cd ../../ec2/
terraform destroy -auto-approve \
  -var="vpc_id=$VPC_ID" \
  -var="private_subnet_ids=[...]" \
  -var="public_subnet_ids=[...]" \
  -var="sg_app_id=$SG_APP" \
  -var="sg_alb_id=$SG_ALB" \
  -var="s3_bucket=placeholder"

# 4. Remover infraestrutura base (RDS, ElastiCache, VPC)
cd ../
terraform destroy -var-file=terraform.tfvars -auto-approve
```

---

## Conceitos abordados nesta aula

| Conceito | Onde aparece |
|----------|-------------|
| Container / Docker | Empacotamento da aplicação em imagem |
| Dockerfile | Receita para construir a imagem |
| ECR | Repositório privado de imagens Docker na AWS |
| ECS Fargate | Execução de containers sem gerenciar servidores |
| Task Definition | "Receita" do container no ECS (CPU, memória, imagem, env vars) |
| ECS Service | Mantém N tasks rodando e reinicia se falhar |
| Task Role | Permissões que o container tem durante execução |
| Execution Role | Permissões para o ECS baixar imagem e escrever logs |
| Application Load Balancer | Distribui tráfego entre múltiplas tasks |
| Health Check | ALB verifica `/health` antes de enviar tráfego |
| Auto Scaling | ECS aumenta/reduz tasks baseado em CPU |
| CloudWatch Logs | Captura logs dos containers automaticamente |
| Blue/Green deploy | `force-new-deployment` sobe tasks novas antes de derrubar antigas |
