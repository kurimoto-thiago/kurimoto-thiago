# ADR-005: Terraform vs AWS CDK

**Status:** Accepted
**Date:** 2026-05-24

## Decisão
**Terraform** como IaC primário.

## Razões
- HCL universal (não exige linguagem específica)
- Multi-cloud (futuro-proof)
- Maior demanda no mercado BR
- Ecossistema de módulos público (registry)
- Equipe pode contribuir sem conhecer TypeScript/Python

## Quando usar CDK
- Lógica complexa em código (loops, conditionals avançados)
- Stacks AWS puras com necessidade de constructs próprios

## Trade-offs
- Sem tipagem forte
- State management exige cuidado
- DRY mais difícil que CDK
