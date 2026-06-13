# Module: security-baseline

Ativa serviços de segurança AWS recomendados (CIS-aligned).

## Features
- GuardDuty com K8s audit + S3 + Malware
- AWS Config com S3 bucket dedicado (encrypted, private)
- Inspector v2 (EC2, ECR, Lambda)
- Macie (opcional, caro)
- Security Hub com CIS standard

## Custo estimado
- GuardDuty: $1-5/mês ambiente DEV; $20-50 PROD
- Config: $2 + $0.003/record
- Inspector: $0.30/imagem ECR/mês
- Macie: caro ($1/GB classified) — habilite só em prod
- Security Hub: $0.0010 por check

## Usage

```hcl
module "security" {
  source = "github.com/kurimoto-thiago/terraform-aws-soc-baseline//modules/security-baseline?ref=v1.0.0"

  project     = "soc"
  environment = "prod"

  enable_guardduty    = true
  enable_config       = true
  enable_inspector    = true
  enable_macie        = true  # apenas prod
  enable_security_hub = true
}
```
