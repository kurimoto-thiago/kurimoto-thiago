# ADR-004: Loki vs CloudWatch Logs

**Status:** Accepted
**Date:** 2026-05-24

## Decisão
**Grafana Loki** como log aggregator principal.

## Razões
- Custo significativamente menor que CloudWatch Logs ($/GB)
- Query unificada com Grafana
- Portabilidade (não AWS-specific)
- Compressão eficiente

## Quando usar CloudWatch
- AWS service logs (VPC Flow, CloudTrail, RDS)
- Compliance que exige AWS-native
- Quando precisar de Insights queries

## Estratégia híbrida
- Aplicação → Loki
- AWS services → CloudWatch (com export S3 → Athena para análise)
