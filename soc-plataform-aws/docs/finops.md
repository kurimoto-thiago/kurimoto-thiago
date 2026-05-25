# 💰 FinOps - Custos detalhados

Estimativas em USD/mês para região `sa-east-1`. Variam ±20%.

## Ambiente DEV (~US$ 45/mês)

| Recurso | Configuração | Custo |
|---------|--------------|-------|
| EKS control plane | 1 cluster | $73 (rateado em horas) — usar Free Tier 12m |
| EC2 t3.medium on-demand | 2 nodes system | $18 (spot $6) |
| EC2 t3.large spot | 2-3 nodes apps | $12 |
| RDS t4g.micro single-AZ | 50GB gp3 | $9 |
| ElastiCache t4g.micro | 1 node | $7 |
| NAT Gateway | 2 AZs | $32 (otimizar: 1 NAT compartilhado) |
| ALB | 1 | $16 |
| S3 + CloudWatch logs | 50GB total | $5 |
| GuardDuty | base | $4 |
| Data transfer | baixo | $3 |
| **Subtotal raw** | | **~$190** |
| **Free Tier + spot** | | **~$45** |

**Otimizações DEV:**
- Use 1 NAT Gateway compartilhado (-$16)
- Spot instances 100% (-$12)
- Desligue cluster fora horário aula (-30%)
- RDS db.t4g.micro Free Tier 12 meses (-$9)
- Aurora Serverless v2 ACU mínima

## Ambiente PROD (~US$ 280/mês)

| Recurso | Configuração | Custo |
|---------|--------------|-------|
| EKS control plane | | $73 |
| EC2 system (on-demand) | 2× t3.medium | $60 |
| EC2 apps (spot+OD mix) | 3× t3.large | $50 |
| EC2 monitoring | 1× t3.xlarge | $80 |
| RDS Multi-AZ t4g.medium | 100GB | $55 |
| Redis Multi-AZ | 2× t4g.small | $30 |
| NAT × 3 AZ | | $48 |
| ALB + WAF | | $25 |
| S3 + CloudWatch | 500GB | $30 |
| GuardDuty + Config + Inspector | | $30 |
| Data transfer | | $20 |
| **Subtotal** | | **~$500** |
| **Com Savings Plans 1y** | | **~$280** |

## Tags obrigatórias

Toda infra deve ter:
```hcl
tags = {
  Project     = "soc-platform"
  Environment = "dev|staging|prod"
  Owner       = "thiago.kurimoto"
  CostCenter  = "portfolio|production"
  ManagedBy   = "terraform"
}
```

## Alertas de orçamento

Configurado em `terraform/modules/security` via AWS Budgets:
- Aviso 50%, 80%, 100% do limite
- Email para owner
- Slack #finops

## Otimização contínua

- **Cost Explorer** semanal: top 10 custos
- **AWS Compute Optimizer** mensal: rightsizing
- **Spot Advisor**: avaliar workloads tolerantes
- **S3 Lifecycle**: Glacier após 30d
- **Reserved Instances**: após 3 meses de uso estável
