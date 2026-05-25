# ADR-001: EKS vs ECS

**Status:** Accepted
**Date:** 2026-05-24

## Contexto
Plataforma multi-tenant precisa de orquestração de containers escalável.

## Decisão
Adotar **AWS EKS** ao invés de ECS Fargate.

## Razões
- Portabilidade (Kubernetes é padrão de mercado)
- Ecossistema rico (Helm, ArgoCD, OPA, Falco)
- Skill demanda alta no mercado brasileiro (Guppy)
- Suporta workloads stateful complexos (Wazuh, OpenSearch)

## Trade-offs
- Maior custo control plane ($73/mês)
- Curva de aprendizado mais íngreme
- Mais peças móveis para gerenciar

## Mitigações
- Karpenter para reduzir custo de nodes
- Managed node groups para reduzir ops
- Documentação e runbooks robustos
