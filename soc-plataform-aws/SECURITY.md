# Security Policy

## Versões suportadas

| Versão | Suportada |
|--------|-----------|
| 1.x | ✅ |
| < 1.0 | ❌ |

## Reportando vulnerabilidades

**Não abra issue pública.**

Envie para: `security@seudominio.dev` (PGP opcional)

Inclua:
- Descrição do problema
- Steps to reproduce
- Impacto estimado
- Versão afetada

## SLA de resposta

| Severidade | Resposta inicial | Patch |
|------------|------------------|-------|
| Critical | 24h | 7 dias |
| High | 48h | 14 dias |
| Medium | 5 dias | 30 dias |
| Low | 7 dias | 60 dias |

## Bug bounty

Não há programa formal, mas reconhecimento público no `HALL-OF-FAME.md`.

## Práticas de segurança

- Dependências escaneadas via Dependabot + Trivy
- Imagens assinadas com Cosign
- Secrets nunca commitados (Gitleaks no CI)
- Code review obrigatório
- Pentest manual trimestral
