# Module: eks-baseline

EKS cluster hardened para SOC.

## Features
- KMS envelope encryption para secrets
- Audit logs completos (api, audit, authenticator, controller, scheduler) → CloudWatch
- IRSA habilitado via OIDC provider
- Add-ons gerenciados (vpc-cni, kube-proxy, coredns, ebs-csi)
- Node groups configuráveis (system, apps, monitoring)
- Tags Kubernetes prontas

## Usage

```hcl
module "eks" {
  source = "github.com/kurimoto-thiago/terraform-aws-soc-baseline//modules/eks-baseline?ref=v1.0.0"

  cluster_name       = "soc-prod"
  cluster_version    = "1.29"
  vpc_id             = module.vpc.vpc_id
  private_subnet_ids = module.vpc.private_subnet_ids

  endpoint_public_access = false  # private only em prod
  public_access_cidrs    = ["1.2.3.4/32"]

  node_groups = {
    system = {
      instance_types = ["t3.medium"]
      capacity_type  = "ON_DEMAND"
      min_size       = 2
      max_size       = 3
      desired_size   = 2
    }
    apps = {
      instance_types = ["t3.large"]
      capacity_type  = "SPOT"
      min_size       = 2
      max_size       = 6
      desired_size   = 3
    }
  }

  tags = { Project = "soc", Environment = "prod" }
}
```

## Hardening recomendado pós-criação

1. Aplicar Pod Security Standards `restricted` em todos namespaces
2. Instalar OPA Gatekeeper com policies obrigatórias
3. Instalar Falco para runtime security
4. NetworkPolicies default-deny por namespace
5. Veja [k8s-security-hardening](https://github.com/kurimoto-thiago/k8s-security-hardening)
