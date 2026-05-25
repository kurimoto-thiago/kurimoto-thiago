# Runbook: Resposta a Incidentes

## Severidade

| Nível | Definição | MTTA | MTTR |
|-------|-----------|------|------|
| SEV1 | Comprometimento ativo, exfiltração | 5 min | 1h |
| SEV2 | Ataque em progresso sem dano | 15 min | 4h |
| SEV3 | Comportamento anômalo | 1h | 24h |
| SEV4 | Findings informativos | 24h | 7d |

## Fluxo

1. **Detectar** — alerta dispara via Wazuh, Falco, GuardDuty
2. **Triagem** — analista verifica falso-positivo
3. **Contenção** — isolar host, revogar credenciais, bloquear IP
4. **Erradicação** — remover artefatos, aplicar patches
5. **Recuperação** — restaurar de backup, validar
6. **Lições** — postmortem em 5 dias

## Comandos rápidos

### Isolar pod
```bash
kubectl label pod $POD quarantine=true
kubectl apply -f - <<YAML
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata: { name: quarantine, namespace: $NS }
spec:
  podSelector: { matchLabels: { quarantine: "true" } }
  policyTypes: [Ingress, Egress]
YAML
```

### Revogar credencial IAM
```bash
aws iam delete-access-key --user-name $USER --access-key-id $AKID
aws iam attach-user-policy --user-name $USER \
  --policy-arn arn:aws:iam::aws:policy/AWSDenyAll
```

### Snapshot forense EBS
```bash
aws ec2 create-snapshot --volume-id $VOL --description "forensic-$(date +%s)"
```

### Coletar logs do incidente
```bash
kubectl logs $POD --previous --all-containers > incident-$(date +%s).log
aws logs filter-log-events --log-group-name /aws/eks/cluster \
  --start-time $(date -d '1 hour ago' +%s)000
```

## Comunicação

- SEV1/SEV2: Slack `#soc-war-room` + telefone líder
- SEV3/SEV4: Slack `#soc-alerts`
- Cliente: somente após aprovação CISO

## Postmortem

Template padrão blameless. Inclua: timeline, impacto, root cause (5 whys), ações corretivas com owner e prazo.
