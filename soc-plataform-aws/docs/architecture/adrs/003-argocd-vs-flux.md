# ADR-003: ArgoCD vs Flux

**Status:** Accepted
**Date:** 2026-05-24

## Decisão
**ArgoCD** para GitOps.

## Razões
- UI rica facilita demo do portfólio
- Multi-tenancy nativo (AppProjects)
- ApplicationSets para padrões de fan-out
- SSO/RBAC robustos
- Maior adoção corporativa (Guppy match)

## Trade-offs
- Mais pesado que Flux
- Mais complexo de configurar inicialmente
