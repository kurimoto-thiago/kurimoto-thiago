# Runbook: Disaster Recovery

## RTO / RPO

| Componente | RTO | RPO |
|------------|-----|-----|
| RDS | 5 min | 5 min (PITR) |
| EKS workloads | 15 min | 0 (stateless) |
| Loki logs | 1h | 1h |
| Wazuh data | 4h | 24h |

## Cenários

### 1. Perda de AZ
- Multi-AZ resolve automaticamente
- Validação: `aws ec2 describe-availability-zones`
- HPA escala nas AZs sobreviventes

### 2. Perda de região (sa-east-1)
- Provisionar em `us-east-1` via mesmo Terraform
- Restore RDS snapshot cross-region
- Update Route53 health checks → failover
- Tempo: 2-4 horas

### 3. Comprometimento de credenciais
1. Rotate AWS access keys
2. Rotate Terraform state encryption key
3. Rotate KMS keys
4. Forçar logout de todas sessões

### 4. Corrupção de dados
1. Identificar timestamp do dano
2. PITR para 5 min antes
3. Aplicar replay de eventos do Wazuh archive

## Backups

| Item | Frequência | Retenção | Destino |
|------|------------|----------|---------|
| RDS auto | Contínuo (PITR) | 30d | AWS |
| RDS snapshot | Diário | 90d | S3 cross-region |
| Terraform state | Versionado | Indefinido | S3 |
| Loki | Diário | 30d | S3 |
| Wazuh | Diário | 90d | S3 Glacier |

## Teste DR

Mensal: simular falha de AZ via Chaos Mesh.
Trimestral: restore completo em ambiente isolado.
