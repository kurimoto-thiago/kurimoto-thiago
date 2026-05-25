# Runbook: RDS Failover

## Cenário
Alerta `RDSConnectionsHigh` ou primary indisponível.

## Verificação

```bash
aws rds describe-db-instances --db-instance-identifier soc-platform-prod \
  --query 'DBInstances[0].{Status:DBInstanceStatus,AZ:AvailabilityZone,Multi:MultiAZ}'
```

## Failover manual (Multi-AZ)

```bash
aws rds reboot-db-instance \
  --db-instance-identifier soc-platform-prod \
  --force-failover
```

Tempo típico: 60-120s.

## Restore point-in-time

```bash
aws rds restore-db-instance-to-point-in-time \
  --source-db-instance-identifier soc-platform-prod \
  --target-db-instance-identifier soc-platform-recovery \
  --restore-time "$(date -u -d '15 minutes ago' +%Y-%m-%dT%H:%M:%SZ)"
```

## Validação pós-failover

- [ ] Backend reconecta (logs)
- [ ] `/ready` retorna 200
- [ ] Sem aumento em error rate
- [ ] Atualizar secret se endpoint mudou
