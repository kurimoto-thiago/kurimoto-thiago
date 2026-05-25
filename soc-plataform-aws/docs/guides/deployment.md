# 🚀 Guia de Implantação

Guia passo a passo do zero ao SOC rodando em produção.

**Duração estimada:** 90-120 minutos
**Custo inicial:** ~US$ 5 (testes), US$ 45/mês em DEV

---

## Fase 0 — Pré-requisitos

### Ferramentas locais

```bash
# Linux/macOS
brew install awscli terraform kubectl helm jq cosign

# Verificar
./scripts/check-prereqs.sh
```

Versões mínimas: `aws 2.15`, `terraform 1.7`, `kubectl 1.29`, `helm 3.14`.

### Contas e acessos

- Conta AWS com permissões de admin (use IAM Identity Center para produção)
- Conta GitHub
- Domínio registrado (Route53 ou outro registrar)
- Webhook Slack (opcional)

### Configurar AWS

```bash
aws configure --profile soc-platform
# Region: sa-east-1
# Output: json

export AWS_PROFILE=soc-platform
aws sts get-caller-identity
```

---

## Fase 1 — Backend Terraform (state remoto)

### 1.1 Bucket de state

```bash
ACCOUNT=$(aws sts get-caller-identity --query Account --output text)
REGION=sa-east-1

aws s3api create-bucket \
  --bucket "soc-platform-tfstate-${ACCOUNT}" \
  --region "$REGION" \
  --create-bucket-configuration LocationConstraint="$REGION"

aws s3api put-bucket-versioning \
  --bucket "soc-platform-tfstate-${ACCOUNT}" \
  --versioning-configuration Status=Enabled

aws s3api put-bucket-encryption \
  --bucket "soc-platform-tfstate-${ACCOUNT}" \
  --server-side-encryption-configuration '{
    "Rules": [{"ApplyServerSideEncryptionByDefault": {"SSEAlgorithm": "AES256"}}]
  }'
```

### 1.2 Tabela DynamoDB para lock

```bash
aws dynamodb create-table \
  --table-name soc-platform-tflock \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region "$REGION"
```

### 1.3 Atualizar backend

Edite `terraform/main.tf`, ajuste `bucket` para incluir seu accountId.

---

## Fase 2 — Provisionar infraestrutura

### 2.1 Inicializar

```bash
cd terraform
terraform init
```

### 2.2 Plan

```bash
terraform plan -var-file=environments/dev.tfvars -out=tfplan
```

Revise: VPC, EKS, RDS, Redis, GuardDuty, Config.

### 2.3 Apply

```bash
terraform apply tfplan
```

⏱️ EKS demora **15-20 minutos** para provisionar.

### 2.4 Validar

```bash
aws eks update-kubeconfig --name soc-platform-dev --region sa-east-1
kubectl get nodes
```

Saída esperada: 5-7 nodes em estado `Ready`.

---

## Fase 3 — Bootstrap cluster

### 3.1 Stack base

```bash
cd ..
./scripts/bootstrap-cluster.sh
```

Instala: AWS LB Controller, cert-manager, ArgoCD, ApplicationSet.

### 3.2 Esperar ArgoCD sincronizar

```bash
watch kubectl get applications -n argocd
```

Aguarde todas `Synced` + `Healthy` (~10 min).

### 3.3 Senha inicial ArgoCD

```bash
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d
```

Troque imediatamente após login.

---

## Fase 4 — Banco de dados

### 4.1 Aplicar schema

```bash
./scripts/seed-database.sh
```

### 4.2 Validar conexão

```bash
kubectl run psql-test --rm -it --image=postgres:15-alpine -- \
  psql "$(aws secretsmanager get-secret-value \
    --secret-id soc-platform-dev/db/master \
    --query SecretString --output text | jq -r '"postgres://\(.username):\(.password)@\(.host):\(.port)/\(.database)"')" \
  -c '\dt'
```

---

## Fase 5 — Imagens de container

### 5.1 Criar repositórios ECR

```bash
aws ecr create-repository --repository-name soc-platform-backend
aws ecr create-repository --repository-name soc-platform-frontend
```

### 5.2 Configurar GitHub Actions (OIDC)

1. Crie role IAM `github-actions-soc-platform` com trust policy OIDC
2. Anexe políticas: `AmazonEC2ContainerRegistryPowerUser`, `AmazonEKSClusterPolicy`
3. Adicione secrets ao repo:
   - `AWS_DEPLOY_ROLE_ARN`
   - `ECR_REGISTRY` (formato: `ACCOUNT.dkr.ecr.sa-east-1.amazonaws.com`)
   - `GH_PAT`

### 5.3 Push inicial

```bash
git push origin main
```

GitHub Actions: build → scan → push → update manifests → ArgoCD sync.

---

## Fase 6 — DNS + Certificados

### 6.1 Certificado ACM

```bash
aws acm request-certificate \
  --domain-name "soc.seudominio.dev" \
  --subject-alternative-names "*.seudominio.dev" \
  --validation-method DNS \
  --region sa-east-1
```

Adicione registros CNAME validation no Route53.

### 6.2 Atualizar Ingress

Edite `kubernetes/apps/frontend/deployment.yaml`:
```yaml
alb.ingress.kubernetes.io/certificate-arn: arn:aws:acm:...
```

### 6.3 Apontar DNS

Crie ALIAS no Route53 apontando para o ALB criado.

```bash
ALB_HOST=$(kubectl get ingress soc-platform -n soc-platform \
  -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
echo "$ALB_HOST"
```

---

## Fase 7 — Configurar SIEM

### 7.1 Wazuh dashboard

```bash
kubectl port-forward -n security svc/wazuh-dashboard 5601:443
```

Acesse `https://localhost:5601`. Login: `admin/admin` (trocar).

### 7.2 Onboarding de agentes

Em cada host monitorado:
```bash
WAZUH_MANAGER='wazuh-manager.security.svc.cluster.local' \
  bash -c "$(curl -fsSL https://packages.wazuh.com/4.7/install-agent.sh)"
```

### 7.3 Integrações

- Slack: `kubectl create secret generic slack-webhook ...`
- VirusTotal: edite `kubernetes/apps/wazuh/values.yaml`

---

## Fase 8 — Observabilidade

### 8.1 Grafana

```bash
kubectl port-forward -n monitoring svc/kps-grafana 3000:80
# Login: admin / (kubectl get secret -n monitoring grafana-admin -o jsonpath='{.data.password}' | base64 -d)
```

### 8.2 Importar dashboards

Settings → Data Sources confirmar Prometheus + Loki. Dashboards → Import → ID `15760` (Kubernetes), `12175` (Wazuh), upload `monitoring/grafana/dashboards/soc-overview.json`.

### 8.3 Alertas

Alertmanager já configurado via `kube-prometheus-stack`. Teste:
```bash
kubectl exec -n monitoring kps-alertmanager-0 -- amtool alert add test \
  severity=warning --alertmanager.url=http://localhost:9093
```

---

## Fase 9 — Validação E2E

Checklist:

- [ ] `kubectl get pods -A` — todos `Running`
- [ ] `https://soc.seudominio.dev` carrega frontend
- [ ] Login funciona (admin@soc.local / changeMe!)
- [ ] Dashboard mostra eventos
- [ ] `https://grafana.seudominio.dev` acessível
- [ ] `https://wazuh.seudominio.dev` acessível
- [ ] Alert teste chega no Slack
- [ ] Falco gera evento ao criar shell em pod: `kubectl run test --rm -it --image=alpine sh`
- [ ] GuardDuty findings em `aws guardduty list-findings`

---

## Fase 10 — Hardening produção

Antes de promover para PROD, leia:

- [`docs/runbooks/security-hardening.md`](../runbooks/security-hardening.md)
- [`docs/runbooks/disaster-recovery.md`](../runbooks/disaster-recovery.md)
- [`docs/finops.md`](../finops.md)

Apply prod:
```bash
terraform apply -var-file=environments/prod.tfvars
```

---

## Troubleshooting

| Sintoma | Causa | Ação |
|---------|-------|------|
| `terraform apply` trava em EKS | Cota EKS atingida | `aws service-quotas list-service-quotas --service-code eks` |
| Pods `Pending` | Sem nodes spot disponíveis | Aumente max ou troque AZ |
| ALB não cria | LBC não tem IAM | Verifique IRSA do `aws-load-balancer-controller` |
| RDS connection refused | SG bloqueando | Confirme CIDR nos `allowed_cidrs` |
| ArgoCD `OutOfSync` | Helm chart desatualizado | `argocd app sync APP --force` |

Suporte: abra issue no GitHub.
