# 🏗️ terraform-aws-soc-baseline

[![Terraform](https://img.shields.io/badge/Terraform-1.7+-7B42BC?logo=terraform)](#)
[![AWS Provider](https://img.shields.io/badge/AWS_Provider-5.x-FF9900?logo=amazonaws)](#)
[![License](https://img.shields.io/badge/license-MIT-green)](LICENSE)
[![CI](https://github.com/kurimoto-thiago/terraform-aws-soc-baseline/actions/workflows/ci.yml/badge.svg)](#)
[![tflint](https://img.shields.io/badge/tflint-passing-green)](#)
[![checkov](https://img.shields.io/badge/checkov-passing-green)](#)

> Módulos Terraform reutilizáveis para criar uma **baseline segura de SOC** na AWS. Pronto para produção, opinionado, com defaults seguros.

Extraído do projeto-mãe [soc-platform-aws](https://github.com/kurimoto-thiago/soc-platform-aws) e empacotado como conjunto de módulos consumíveis em qualquer projeto.

---

## 🎯 O que entrega

| Módulo | O que provisiona |
|--------|------------------|
| `vpc` | VPC multi-AZ, subnets pub/priv, NAT por AZ, Flow Logs, VPC Endpoints |
| `eks-baseline` | Cluster EKS com IRSA, KMS encryption, audit logs, OIDC, add-ons |
| `security-baseline` | GuardDuty + Config + Inspector + Macie + CloudTrail multi-region |
| `iam-baseline` | Roles least-privilege, password policy, MFA enforcement, Access Analyzer |
| `logging` | CloudTrail + Config logs em S3 com Object Lock + Athena workgroup |

## 🚀 Quick start

### Uso mínimo (VPC apenas)

```hcl
module "vpc" {
  source  = "github.com/kurimoto-thiago/terraform-aws-soc-baseline//modules/vpc?ref=v1.0.0"

  name               = "my-project"
  cidr               = "10.0.0.0/16"
  availability_zones = ["sa-east-1a", "sa-east-1b", "sa-east-1c"]
  enable_flow_logs   = true
}
```

### Uso completo (SOC baseline)

```hcl
module "vpc" {
  source = "github.com/kurimoto-thiago/terraform-aws-soc-baseline//modules/vpc?ref=v1.0.0"
  # ...
}

module "security" {
  source = "github.com/kurimoto-thiago/terraform-aws-soc-baseline//modules/security-baseline?ref=v1.0.0"

  project     = "my-project"
  environment = "prod"
  enable_guardduty = true
  enable_config    = true
  enable_inspector = true
  enable_macie     = true
}

module "logging" {
  source = "github.com/kurimoto-thiago/terraform-aws-soc-baseline//modules/logging?ref=v1.0.0"

  project        = "my-project"
  retention_days = 365
}

module "eks" {
  source = "github.com/kurimoto-thiago/terraform-aws-soc-baseline//modules/eks-baseline?ref=v1.0.0"

  cluster_name       = "my-project"
  vpc_id             = module.vpc.vpc_id
  private_subnet_ids = module.vpc.private_subnet_ids
  cluster_version    = "1.29"
}
```

Veja [`examples/`](examples/) para casos de uso completos.

## 🛡️ Princípios de design

1. **Secure by default** — encryption, logging e least-privilege são padrão (não opção)
2. **Multi-AZ** — sempre que possível, HA é built-in
3. **Compliance-ready** — alinhado com CIS AWS Benchmark 1.5, NIST CSF, AWS Well-Architected SEC pillar
4. **Cost-aware** — toggles para desabilitar serviços caros em DEV
5. **Tags obrigatórias** — Project, Environment, Owner, ManagedBy

## 📐 Compliance

Os módulos foram desenhados para passar nas seguintes verificações:

- ✅ AWS CIS Benchmark 1.5
- ✅ AWS Well-Architected — Security Pillar
- ✅ NIST CSF (Identify, Protect, Detect)
- ✅ checkov scan (sem HIGH/CRITICAL)
- ✅ tfsec scan (sem HIGH/CRITICAL)

## 📦 Versionamento

Semver. Use tags para fixar versão:

```hcl
source = "github.com/kurimoto-thiago/terraform-aws-soc-baseline//modules/vpc?ref=v1.0.0"
```

## 🧪 Testes

```bash
# Validate all
make validate

# Unit tests (Terratest)
cd test && go test -v -timeout 30m

# Security scan
make scan
```

## 📁 Estrutura

```
terraform-aws-soc-baseline/
├── modules/
│   ├── vpc/                 # VPC multi-AZ com Flow Logs
│   ├── eks-baseline/        # EKS hardened
│   ├── security-baseline/   # GuardDuty, Config, Inspector, Macie
│   ├── iam-baseline/        # IAM hardening
│   └── logging/             # CloudTrail + S3 + Athena
├── examples/
│   ├── minimal/             # Só VPC
│   ├── full/                # Stack completa SOC
│   └── multi-account/       # Org-level baseline
├── test/                    # Terratest
└── .github/workflows/       # CI: validate, scan, terratest
```

## 🤝 Como contribuir

1. Fork
2. Branch: `feat/nova-feature`
3. Conventional Commits
4. PR com testes

Veja [`CONTRIBUTING.md`](CONTRIBUTING.md).

## 📖 Referências

- [AWS Well-Architected Security Pillar](https://docs.aws.amazon.com/wellarchitected/latest/security-pillar/)
- [CIS AWS Foundations Benchmark](https://www.cisecurity.org/benchmark/amazon_web_services)
- [Terraform AWS Provider docs](https://registry.terraform.io/providers/hashicorp/aws/)

## 📝 Licença

MIT — veja [`LICENSE`](LICENSE).

## 👤 Autor

**Thiago Kurimoto** — Cloud & Security Engineer
[LinkedIn](https://www.linkedin.com/in/thiagokurimoto) · [GitHub](https://github.com/kurimoto-thiago)

---

> 💡 Este módulo é parte do meu portfólio público. Veja também:
> - [soc-platform-aws](https://github.com/kurimoto-thiago/soc-platform-aws) — plataforma SOC completa
> - [k8s-security-hardening](https://github.com/kurimoto-thiago/k8s-security-hardening) — Falco + OPA + NetworkPolicies
> - [aws-incident-response-runbooks](https://github.com/kurimoto-thiago/aws-incident-response-runbooks) — playbooks SRE
