# ADR-002: Wazuh vs ELK puro

**Status:** Accepted
**Date:** 2026-05-24

## Decisão
**Wazuh 4.7** como SIEM principal.

## Razões
- SIEM out-of-the-box (rules CIS, MITRE, PCI já inclusas)
- Free e open source
- HIDS, FIM, compliance scan integrados
- Comunidade ativa, docs em PT-BR
- Integra naturalmente com OpenSearch

## Alternativas consideradas
- ELK puro: precisa construir tudo manualmente
- Splunk: licença cara
- AWS Security Lake: lock-in, custo OCSF
- SecurityOnion: foco NIDS, menos cloud-native
