# Runbook: Eventos Críticos

## Trigger
Alerta `HighRateCriticalEvents` dispara quando rate de eventos severity=critical > 1/min por 2min.

## Diagnóstico

1. Abra Grafana → SOC Overview
2. Identifique tenant e source predominante
3. Top 10 rules disparadas

```bash
kubectl exec -n monitoring kps-prometheus-0 -c prometheus -- \
  promtool query instant 'http://localhost:9090' \
  'topk(5, sum by (rule_id) (increase(security_events_total{severity="critical"}[10m])))'
```

## Resposta por origem

### Wazuh: brute force SSH
- Bloquear IP no WAF + Security Group
- Forçar reset de senha do usuário
- Habilitar MFA

### Falco: shell em container
- Snapshot do pod
- `kubectl delete pod` (não `exec` — destrói evidência)
- Revisar imagem da origem

### Suricata: scan de portas
- Bloquear IP origem no WAF
- Verificar follow-up traffic

### GuardDuty: cryptocurrency mining
- Isolar instância
- Snapshot EBS
- Investigar vetor inicial (chave IAM comprometida?)
