# 🛡️ SOC Platform AWS

[![CI](https://github.com/USER/soc-platform-aws/actions/workflows/ci.yml/badge.svg)](#)
[![Security Scan](https://github.com/USER/soc-platform-aws/actions/workflows/security.yml/badge.svg)](#)
[![Terraform](https://img.shields.io/badge/Terraform-1.7+-7B42BC?logo=terraform)](#)
[![Kubernetes](https://img.shields.io/badge/Kubernetes-1.29-326CE5?logo=kubernetes)](#)
[![AWS](https://img.shields.io/badge/AWS-sa--east--1-FF9900?logo=amazonaws)](#)
[![License](https://img.shields.io/badge/license-MIT-green)](LICENSE)

> **SOC-as-a-Service multi-tenant em AWS.** Detecção, observabilidade, IaC e FinOps em produção.

Plataforma completa que demonstra arquitetura cloud-native, segurança defensiva e operação DevOps em escala. Construída como portfólio profissional e laboratório acadêmico.

---

## 🎯 O que faz

- **SIEM completo** com Wazuh + OpenSearch
- **Observabilidade 360°** com Prometheus, Grafana e Loki
- **Detecção de intrusão** Suricata (rede) + Falco (runtime K8s)
- **Compliance automatizado** CIS Benchmark + AWS Well-Architected
- **Pentest contínuo** OWASP ZAP integrado ao pipeline
- **Alertas inteligentes** Slack + Telegram + PagerDuty
- **FinOps dashboard** custo real por tenant

## 🏗️ Stack

| Camada | Tecnologia |
|--------|------------|
| IaC | Terraform 1.7 + Ansible |
| Compute | AWS EKS 1.29 + Lambda |
| Rede | VPC multi-AZ + WAF + GuardDuty + VPC Flow Logs |
| SIEM | Wazuh 4.7 + OpenSearch |
| Métricas | Prometheus 2.49 |
| Visualização | Grafana 10.3 |
| Logs | Loki 2.9 + Promtail |
| IDS/IPS | Suricata 7 + Falco 0.37 |
| Backend | Node.js 20 LTS + Express |
| Frontend | React 18 + Vite + TailwindCSS |
| Banco | PostgreSQL 15 (RDS) + Redis 7 (ElastiCache) |
| Secrets | AWS Secrets Manager + Vault |
| CI/CD | GitHub Actions + ArgoCD |
| Região | `sa-east-1` |

## 📐 Arquitetura

![Architecture](docs/architecture/diagram.png)

Detalhes completos em [`ARCHITECTURE.md`](ARCHITECTURE.md).

## 🚀 Quick start

```bash
# 1. Pré-requisitos
./scripts/check-prereqs.sh

# 2. Configurar AWS
aws configure --profile soc-platform

# 3. Provisionar infraestrutura
cd terraform
terraform init
terraform apply -var-file=environments/dev.tfvars

# 4. Deploy aplicações
./scripts/bootstrap-cluster.sh

# 5. Acessar dashboards
./scripts/port-forward.sh
```

Guia completo: [`docs/guides/deployment.md`](docs/guides/deployment.md)

## 📊 Demo ao vivo

- 🌐 Dashboard: https://soc.seudominio.dev
- 📈 Status: https://status.seudominio.dev
- 📚 Docs: https://docs.seudominio.dev

## 💰 Custo

Ambiente DEV: **~US$ 45/mês** (free tier + spot instances).
Ambiente PROD: **~US$ 280/mês** (HA, multi-AZ).

Detalhamento: [`docs/finops.md`](docs/finops.md)

## 📁 Estrutura

```
soc-platform-aws/
├── terraform/          # IaC - VPC, EKS, RDS, secrets
├── kubernetes/         # Manifests + Kustomize overlays
├── backend/            # API Node.js
├── frontend/           # Dashboard React
├── monitoring/         # Prometheus, Grafana, Loki configs
├── ci-cd/              # Pipelines GitHub Actions + ArgoCD
├── scripts/            # Bootstrap e operação
├── docs/               # Guias, runbooks, arquitetura
└── .github/            # Templates e workflows
```

## 🎓 Sobre o autor

**Thiago Kurimoto** — Cloud & Security Engineer
- Instrutor Técnico SENAI SP (Cyber + IA + Cloud)
- 25+ anos em TI, 4+ em educação
- Mestrando PPG-INF / UFABC (P4 + ML-IDS para IoT)

🔗 [LinkedIn](https://linkedin.com/in/thiagokurimoto) · [Site](https://seudominio.dev) · [GitHub](https://github.com/USER)

## 📝 Licença

MIT — veja [`LICENSE`](LICENSE).
