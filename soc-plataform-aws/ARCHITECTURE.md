# 🏗️ Arquitetura

## Visão geral

```
┌─────────────────────────────────────────────────────────────────┐
│                       INTERNET / USERS                          │
└────────────────────────────┬────────────────────────────────────┘
                             │
                    ┌────────▼────────┐
                    │  Route53 + WAF  │
                    └────────┬────────┘
                             │
                    ┌────────▼────────┐
                    │  CloudFront CDN │
                    └────────┬────────┘
                             │
        ┌────────────────────▼────────────────────┐
        │            AWS VPC (sa-east-1)          │
        │                                         │
        │  ┌──────────────┐    ┌──────────────┐ │
        │  │  Public AZ-A │    │  Public AZ-B │ │
        │  │     ALB      │    │     ALB      │ │
        │  └──────┬───────┘    └──────┬───────┘ │
        │         │                   │          │
        │  ┌──────▼────────────────────▼──────┐  │
        │  │       EKS Cluster (1.29)        │  │
        │  │                                  │  │
        │  │  ┌─────────┐  ┌──────────────┐ │  │
        │  │  │ Backend │  │  Frontend    │ │  │
        │  │  │ Node20  │  │  React/Nginx │ │  │
        │  │  └────┬────┘  └──────────────┘ │  │
        │  │       │                          │  │
        │  │  ┌────▼─────────────────────────┐│  │
        │  │  │   Observability Stack       ││  │
        │  │  │  Prometheus + Grafana + Loki││  │
        │  │  └─────────────────────────────┘│  │
        │  │                                  │  │
        │  │  ┌─────────────────────────────┐│  │
        │  │  │     SIEM Stack              ││  │
        │  │  │  Wazuh + OpenSearch         ││  │
        │  │  └─────────────────────────────┘│  │
        │  │                                  │  │
        │  │  ┌─────────────────────────────┐│  │
        │  │  │   Security Runtime          ││  │
        │  │  │  Falco + Suricata DaemonSet ││  │
        │  │  └─────────────────────────────┘│  │
        │  └──────────────────────────────────┘  │
        │                                         │
        │  ┌──────────────┐    ┌──────────────┐ │
        │  │  Private AZ-A│    │  Private AZ-B│ │
        │  │              │    │              │ │
        │  │  RDS Postgres│    │  ElastiCache │ │
        │  │  Multi-AZ    │    │  Redis 7     │ │
        │  └──────────────┘    └──────────────┘ │
        └─────────────────────────────────────────┘
                             │
              ┌──────────────┼──────────────┐
              │              │              │
        ┌─────▼─────┐  ┌─────▼─────┐  ┌────▼──────┐
        │ GuardDuty │  │  Secrets  │  │ CloudWatch│
        │ Detective │  │  Manager  │  │   X-Ray   │
        └───────────┘  └───────────┘  └───────────┘
```

## Componentes

### 1. Rede

- **VPC** /16 com 3 AZs em `sa-east-1`
- **Subnets públicas** /20 (ALB, NAT)
- **Subnets privadas** /20 (EKS nodes, RDS, Redis)
- **VPC Flow Logs** → CloudWatch Logs
- **NAT Gateway** HA por AZ
- **Security Groups** least-privilege
- **WAF** com regras OWASP Top 10
- **Shield Standard** ativo

### 2. Compute

- **EKS 1.29** managed control plane
- **Node groups:**
  - `system` — t3.medium on-demand (2-3 nodes)
  - `apps` — t3.large spot (2-6 nodes)
  - `monitoring` — t3.xlarge on-demand (1-2 nodes)
- **Karpenter** para auto-scaling avançado
- **AWS Load Balancer Controller**
- **Cluster Autoscaler**

### 3. Dados

- **RDS PostgreSQL 15** Multi-AZ
  - Encryption at rest (KMS)
  - Automated backups 7 dias
  - Performance Insights
- **ElastiCache Redis 7** cluster mode
- **S3 buckets:**
  - `logs-archive` (Glacier transition 30d)
  - `backups`
  - `artifacts`

### 4. Segurança

#### Camada AWS
- **GuardDuty** — detecção de ameaças
- **AWS Config** — compliance contínuo
- **CloudTrail** — auditoria multi-region
- **Inspector** — vuln scan EC2/ECR
- **Macie** — proteção S3 (PII)

#### Camada Kubernetes
- **Falco** — runtime security
- **OPA Gatekeeper** — policy as code
- **Network Policies** — segmentação
- **Pod Security Standards** — restricted
- **IRSA** — IAM roles for service accounts
- **Sealed Secrets** — secrets no Git

#### Camada Rede
- **Suricata** — IDS de rede via mirror
- **WAF + Shield** — borda
- **VPC endpoints** — tráfego privado

### 5. SIEM

- **Wazuh Manager** (StatefulSet, 3 réplicas)
- **Wazuh Indexer** (OpenSearch, 3 nodes)
- **Wazuh Dashboard** (acesso via ALB)
- **Agentes** em todos os hosts + integração com Falco

### 6. Observabilidade

| Pilar | Ferramenta |
|-------|------------|
| Métricas | Prometheus + Thanos (long-term) |
| Logs | Loki + Promtail |
| Traces | Tempo + OpenTelemetry |
| Visualização | Grafana 10.3 |
| Alertas | Alertmanager → Slack/Telegram/PagerDuty |

### 7. CI/CD

```
Developer Push
      │
      ▼
GitHub Actions
   ├─ Lint (eslint, tflint, hadolint)
   ├─ Test (unit + integration)
   ├─ Security Scan (Trivy, Checkov, Gitleaks, Snyk)
   ├─ Build (Docker multi-arch)
   ├─ Push → ECR
   └─ Update manifest → GitOps repo
              │
              ▼
       ArgoCD Sync
              │
              ▼
        EKS Cluster
```

## Decisões arquiteturais (ADRs)

Veja [`docs/architecture/adrs/`](docs/architecture/adrs/) para registros formais.

- **ADR-001:** EKS vs ECS → EKS (portabilidade, ecossistema)
- **ADR-002:** Wazuh vs ELK puro → Wazuh (SIEM out-of-box)
- **ADR-003:** ArgoCD vs Flux → ArgoCD (UI + multi-tenancy)
- **ADR-004:** Loki vs CloudWatch → Loki (custo + portabilidade)
- **ADR-005:** Terraform vs CDK → Terraform (HCL universal, equipe heterogênea)

## SLOs

| Serviço | SLO | Métrica |
|---------|-----|---------|
| API | 99.9% disponibilidade | HTTP 5xx < 0.1% |
| Dashboard | 99.5% disponibilidade | TTFB < 1s |
| Ingestão SIEM | < 30s latência | end-to-end |
| Alerta crítico | < 2min MTTA | Slack ack |

## Diagramas detalhados

- [Network topology](docs/architecture/network.md)
- [Data flow](docs/architecture/dataflow.md)
- [Threat model](docs/architecture/threat-model.md)
- [Disaster recovery](docs/architecture/dr.md)
