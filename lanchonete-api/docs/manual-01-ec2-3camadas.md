# Manual 01 — Implantação em EC2 (Arquitetura 3 Camadas)

| Campo         | Valor                                  |
|---------------|----------------------------------------|
| Modo          | EC2 puro — sem serviços gerenciados    |
| Dificuldade   | ⭐⭐ Intermediário                      |
| Tempo estimado| 40 – 60 minutos                        |
| Ambiente      | AWS Learner Labs (us-east-1)           |

---

## Visão Geral

Neste modo, toda a infraestrutura roda em instâncias EC2. Não há serviços gerenciados como RDS ou ElastiCache — o banco de dados e o cache também são instalados em EC2.

```
┌─────────────────────────────────────────────────────────┐
│                        Internet                          │
└──────────────────────────┬──────────────────────────────┘
                           │ HTTP :80
┌──────────────────────────▼──────────────────────────────┐
│  CAMADA 1 — WEB  (EC2 t3.micro — subnet pública)         │
│  Nginx :80                                               │
│  • Serve index.html (frontend)                           │
│  • Proxy /api/ → Camada App                              │
└──────────────────────────┬──────────────────────────────┘
                           │ HTTP :3000 (SG restrito)
┌──────────────────────────▼──────────────────────────────┐
│  CAMADA 2 — APP  (EC2 t3.small — subnet pública)         │
│  Node.js 20 + systemd :3000                              │
│  • API REST (cardápio, pedidos)                          │
│  • Lê variáveis de ambiente do .env                      │
└──────────────────────────┬──────────────────────────────┘
                           │ TCP :5432 / :6379 (SG restrito)
┌──────────────────────────▼──────────────────────────────┐
│  CAMADA 3 — BD   (EC2 t3.micro — subnet pública)         │
│  PostgreSQL 16 :5432 + Redis 6 :6379                     │
│  • Banco relacional + cache em memória                   │
└─────────────────────────────────────────────────────────┘
```

**Por que esse modo?**
- Conceito mais direto: cada camada é um servidor físico (virtualizado)
- Não depende de serviços gerenciados (sem RDS, sem ElastiCache)
- Ideal para entender o funcionamento básico antes de abstrações

**Recursos AWS utilizados:**
- 3 instâncias EC2 (t3.micro + t3.small + t3.micro)
- 1 VPC com subnet pública
- 3 Security Groups
- 1 Internet Gateway

---

## Pré-requisitos

Antes de começar, verifique:

- [ ] Conta no AWS Learner Labs ativa
- [ ] Terraform instalado (`terraform -version` → deve ser ≥ 1.6)
- [ ] AWS CLI instalado (`aws --version` → deve ser ≥ 2.x)
- [ ] Repositório clonado localmente
- [ ] Par de chaves `vockey` disponível no Learner Labs

```bash
# Verificar ferramentas
terraform -version
aws --version
git --version
```

---

## Passo 1 — Configurar Credenciais AWS

> As credenciais do Learner Labs **expiram a cada 4 horas**. Repita este passo sempre que receber `ExpiredTokenException`.

**1.1** No painel do Learner Labs, clique em **AWS Details → Show**

**1.2** Copie as três informações: `aws_access_key_id`, `aws_secret_access_key`, `aws_session_token`

**1.3** Configure o AWS CLI:

```bash
aws configure
```

Preencha quando solicitado:
```
AWS Access Key ID:     [cole o aws_access_key_id]
AWS Secret Access Key: [cole o aws_secret_access_key]
Default region name:   us-east-1
Output format:         json
```

**1.4** Configure o session token (obrigatório no Learner Labs):

```bash
aws configure set aws_session_token [cole o aws_session_token]
```

**1.5** Verifique se as credenciais funcionam:

```bash
aws sts get-caller-identity
```

Saída esperada:
```json
{
    "UserId": "AROAXXXXXXXXXXXXXXX:user",
    "Account": "123456789012",
    "Arn": "arn:aws:sts::123456789012:assumed-role/LabRole/user"
}
```

---

## Passo 2 — Baixar o Par de Chaves

> O par de chaves `vockey` é necessário para conectar nas instâncias EC2 via SSH (opcional, mas boa prática).

**2.1** No painel do Learner Labs: **AWS Details → Download PEM**

**2.2** Salve o arquivo como `vockey.pem` e ajuste as permissões:

```bash
chmod 400 ~/Downloads/vockey.pem
```

---

## Passo 3 — Entrar no diretório da infraestrutura

```bash
cd lanchonete-api/infra/ec2-3tier/
```

Verifique os arquivos presentes:
```bash
ls -la
```

Saída esperada:
```
main.tf
user_data_db.sh
user_data_app.sh
user_data_web.sh
```

**O que cada arquivo faz:**

| Arquivo | Função |
|---------|--------|
| `main.tf` | Define toda a infraestrutura (VPC, SGs, EC2) |
| `user_data_db.sh` | Script de inicialização da Camada BD (PostgreSQL + Redis) |
| `user_data_app.sh` | Script de inicialização da Camada App (Node.js) |
| `user_data_web.sh` | Script de inicialização da Camada Web (Nginx + frontend) |

---

## Passo 4 — Inicializar o Terraform

```bash
terraform init
```

O Terraform fará o download dos providers necessários. Saída esperada:
```
Initializing the backend...
Initializing provider plugins...
- Finding hashicorp/aws versions matching "~> 5.0"...
- Installing hashicorp/aws v5.x.x...
Terraform has been successfully initialized!
```

---

## Passo 5 — Visualizar o plano de execução

```bash
terraform plan -var="db_password=SenhaForte123!" -var="key_name=vockey"
```

Leia o plano com atenção. Ao final você verá:
```
Plan: 11 to add, 0 to change, 0 to destroy.
```

Os recursos que serão criados:
- `aws_vpc.main` — rede virtual privada
- `aws_internet_gateway.main` — rota para internet
- `aws_subnet.public` — subnet pública
- `aws_route_table.public` + `aws_route_table_association.public`
- `aws_security_group.web` — regras de acesso da camada web
- `aws_security_group.app` — regras de acesso da camada app
- `aws_security_group.db` — regras de acesso da camada bd
- `aws_instance.db` — EC2 da Camada BD
- `aws_instance.app` — EC2 da Camada App
- `aws_instance.web` — EC2 da Camada Web

---

## Passo 6 — Aplicar a infraestrutura

```bash
terraform apply -var="db_password=SenhaForte123!" -var="key_name=vockey"
```

Quando solicitado, confirme digitando `yes`:
```
Do you want to perform these actions?
  Terraform will perform the actions described above.
  Only 'yes' will be accepted to approve.

  Enter a value: yes
```

> **Tempo estimado:** 3–5 minutos para criar todos os recursos.

Ao final, você verá os outputs:
```
Outputs:

app_ip  = "10.0.1.xxx"
db_ip   = "10.0.1.xxx"
url     = "http://54.xxx.xxx.xxx"
web_ip  = "54.xxx.xxx.xxx"
```

**Guarde a URL** — ela é o endereço público do sistema.

---

## Passo 7 — Aguardar a inicialização

As instâncias EC2 executam scripts de inicialização ao ligar (user_data). Esse processo leva entre **5 e 10 minutos**.

A ordem de inicialização é:
1. Camada BD: instala PostgreSQL e Redis, cria banco e tabelas
2. Camada App: aguarda o BD ficar disponível, instala Node.js, sobe a API
3. Camada Web: aguarda a App ficar disponível, instala Nginx, serve o frontend

**Como acompanhar o progresso:**

```bash
# Conectar via SSM Session Manager (sem SSH)
INSTANCE_ID=$(aws ec2 describe-instances \
  --filters "Name=tag:Name,Values=lanchonete-web" \
  --query 'Reservations[0].Instances[0].InstanceId' \
  --output text)

aws ssm start-session --target $INSTANCE_ID
```

Dentro da sessão, ver o log de inicialização:
```bash
sudo tail -f /var/log/user-data.log
```

Aguarde aparecer: `✅ Camada Web pronta`

---

## Passo 8 — Verificar o funcionamento

**8.1** Teste pelo browser:

Abra a URL do output no browser:
```
http://54.xxx.xxx.xxx
```

Você deve ver a interface do sistema de lanchonete.

**8.2** Teste pela linha de comando:

```bash
URL=$(terraform output -raw url)

# Health check
curl $URL/api/health

# Cardápio
curl $URL/api/cardapio | python3 -m json.tool
```

Saída esperada do health check:
```json
{"status": "ok", "timestamp": "..."}
```

---

## Passo 9 — Usar a interface web

**9.1** Abra `http://<web_ip>` no browser

**9.2** Explore as seções:
- **Cardápio**: lista todos os itens disponíveis organizados por categoria
- **Fazer Pedido**: selecione itens, informe mesa e nome, confirme
- **Pedidos**: lista pedidos das últimas 24 horas com status

---

## Passo 10 — Usar a CLI

A CLI é um script bash que usa `curl` para chamar a API. Necessita de `curl` e `jq`.

```bash
# Instalar jq (se necessário)
sudo dnf install -y jq   # Amazon Linux
# ou
sudo apt install -y jq   # Ubuntu/Debian

# Usar a CLI apontando para a URL do sistema
API_URL=http://<web_ip> bash lanchonete-api/src/cli/lanchonete.sh
```

Menu disponível:
```
╔══════════════════════╗
║   🍔  LANCHONETE     ║
╚══════════════════════╝

  1) Ver cardápio
  2) Fazer pedido
  3) Ver pedidos
  4) Detalhe do pedido
  5) Atualizar status
  6) Saúde da API
  0) Sair
```

---

## Solução de Problemas

### A página não abre no browser

```bash
# Verificar se o Nginx está rodando na camada Web
INSTANCE_ID=$(aws ec2 describe-instances \
  --filters "Name=tag:Name,Values=lanchonete-web" \
  --query 'Reservations[0].Instances[0].InstanceId' --output text)

aws ssm start-session --target $INSTANCE_ID
# Dentro da sessão:
sudo systemctl status nginx
sudo cat /var/log/user-data.log | tail -30
```

### Erro "502 Bad Gateway"

O Nginx não consegue conectar na Camada App. Verifique:

```bash
# Na instância Web, verificar conectividade com App
nc -z <app_private_ip> 3000 && echo "OK" || echo "Falhou"

# Verificar se a App está rodando
INSTANCE_ID=$(aws ec2 describe-instances \
  --filters "Name=tag:Name,Values=lanchonete-app" \
  --query 'Reservations[0].Instances[0].InstanceId' --output text)
aws ssm start-session --target $INSTANCE_ID
# Dentro da sessão:
sudo systemctl status lanchonete
sudo journalctl -u lanchonete -n 50
```

### API retorna erro de banco de dados

O Node.js não consegue conectar no PostgreSQL. Verifique:

```bash
# Na instância App, testar conexão com BD
nc -z <db_private_ip> 5432 && echo "OK" || echo "Falhou"

# Na instância BD, verificar PostgreSQL
INSTANCE_ID=$(aws ec2 describe-instances \
  --filters "Name=tag:Name,Values=lanchonete-db" \
  --query 'Reservations[0].Instances[0].InstanceId' --output text)
aws ssm start-session --target $INSTANCE_ID
# Dentro da sessão:
sudo systemctl status postgresql
sudo -u postgres psql -c "\l"   # listar bancos
```

### Inicialização ainda em andamento

Se o sistema não responder após 15 minutos:

```bash
# Verificar o log completo de qualquer instância
sudo cat /var/log/user-data.log
```

---

## Limpeza (Remover todos os recursos)

> Execute sempre ao final da aula para não consumir créditos desnecessariamente.

```bash
cd lanchonete-api/infra/ec2-3tier/

terraform destroy -var="db_password=SenhaForte123!" -var="key_name=vockey"
```

Confirme digitando `yes`. Todos os recursos serão removidos.

---

## Conceitos abordados nesta aula

| Conceito | Onde aparece |
|----------|-------------|
| Arquitetura em camadas (3-tier) | Separação Web / App / BD |
| Security Groups | Controle de acesso entre camadas |
| VPC e subnets | Isolamento de rede |
| User Data | Automação de inicialização de EC2 |
| Nginx como reverse proxy | Camada Web proxy para App |
| systemd | Gerenciamento de serviços Linux |
| Terraform | Infraestrutura como código (IaC) |
| IaC idempotente | `terraform apply` pode ser re-executado com segurança |
