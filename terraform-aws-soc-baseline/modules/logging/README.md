# Module: logging

CloudTrail multi-region + S3 com Object Lock + Athena.

## Features
- CloudTrail multi-region
- S3 com KMS encryption + Object Lock (WORM)
- Lifecycle Glacier/Deep Archive
- Insight events (anomaly detection no API rate)
- Athena workgroup pré-configurado

## Usage

```hcl
module "logging" {
  source = "github.com/kurimoto-thiago/terraform-aws-soc-baseline//modules/logging?ref=v1.0.0"

  project                    = "soc"
  retention_days             = 2555  # 7 anos
  enable_object_lock         = true
  object_lock_retention_days = 365
  create_athena_workgroup    = true
}
```

## Athena queries úteis

Após apply, no Athena workgroup criado:

```sql
-- Detectar root logins
SELECT eventtime, useridentity.arn, sourceipaddress, eventname
FROM cloudtrail_logs
WHERE useridentity.type = 'Root'
AND eventtime > current_date - interval '7' day;

-- Falhas de console login
SELECT eventtime, useridentity.username, sourceipaddress, errormessage
FROM cloudtrail_logs
WHERE eventname = 'ConsoleLogin'
AND responseelements LIKE '%Failure%';
```
