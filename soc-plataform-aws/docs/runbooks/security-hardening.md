# Runbook: Hardening para Produção

Checklist antes de promover ambiente para produção.

## AWS
- [ ] CloudTrail multi-region ativado
- [ ] AWS Config recording all resources
- [ ] GuardDuty habilitado em todas regiões usadas
- [ ] IAM Access Analyzer ativo
- [ ] MFA obrigatório em todos IAM users
- [ ] Root account com hardware MFA
- [ ] SCPs aplicadas no AWS Organizations
- [ ] Service Control Policies bloqueando regiões não-usadas

## EKS
- [ ] Private endpoint apenas (ou IP allowlist)
- [ ] Audit logs habilitados → CloudWatch
- [ ] OPA Gatekeeper com policies obrigatórias
- [ ] Pod Security Standards `restricted`
- [ ] Network Policies default-deny por namespace
- [ ] IRSA para todos service accounts
- [ ] Secrets via External Secrets Operator

## Rede
- [ ] WAF rules customizadas + AWS Managed Rules
- [ ] Shield Advanced em prod
- [ ] VPC Flow Logs → S3 + Athena
- [ ] VPC endpoints para S3, ECR, Secrets Manager

## Aplicação
- [ ] CORS allowlist específica (não `*`)
- [ ] Rate limiting no backend
- [ ] CSP header rigoroso
- [ ] JWT com rotação automática (30d)
- [ ] Passwords bcrypt cost 12+
- [ ] Audit log de operações sensíveis

## Dados
- [ ] RDS Multi-AZ
- [ ] Backups automáticos 30d
- [ ] Snapshots cross-region semanal
- [ ] Performance Insights ativo
- [ ] PII detectada via Macie

## Monitoramento
- [ ] SLO definidos e dashboard
- [ ] On-call rotation no PagerDuty
- [ ] Runbooks para cada alerta crítico
- [ ] Postmortem template
