#!/usr/bin/env bash
# bootstrap-cluster.sh — instala stack pós-Terraform
set -euo pipefail

CLUSTER_NAME="${CLUSTER_NAME:-soc-platform-dev}"
REGION="${REGION:-sa-east-1}"

echo "=== Bootstrap SOC Platform ==="

# 1. kubeconfig
echo "→ Atualizando kubeconfig..."
aws eks update-kubeconfig --name "$CLUSTER_NAME" --region "$REGION"

# 2. Helm repos
echo "→ Adicionando repos Helm..."
helm repo add aws-load-balancer-controller https://aws.github.io/eks-charts
helm repo add jetstack https://charts.jetstack.io
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo add grafana https://grafana.github.io/helm-charts
helm repo add wazuh https://wazuh.github.io/wazuh-kubernetes
helm repo add falcosecurity https://falcosecurity.github.io/charts
helm repo add argo https://argoproj.github.io/argo-helm
helm repo update

# 3. Namespaces
echo "→ Criando namespaces..."
kubectl apply -f kubernetes/base/namespaces.yaml

# 4. AWS Load Balancer Controller
echo "→ Instalando AWS LB Controller..."
helm upgrade --install aws-lbc aws-load-balancer-controller/aws-load-balancer-controller \
  -n kube-system \
  --set clusterName="$CLUSTER_NAME" \
  --set serviceAccount.create=false \
  --set serviceAccount.name=aws-load-balancer-controller

# 5. cert-manager
echo "→ Instalando cert-manager..."
helm upgrade --install cert-manager jetstack/cert-manager \
  -n cert-manager --create-namespace \
  --set installCRDs=true

# 6. ArgoCD
echo "→ Instalando ArgoCD..."
helm upgrade --install argocd argo/argo-cd \
  -n argocd \
  --set server.service.type=ClusterIP

# 7. Wait ArgoCD
echo "→ Aguardando ArgoCD..."
kubectl wait --for=condition=available --timeout=600s deployment/argocd-server -n argocd

# 8. Apply ApplicationSet
echo "→ Configurando GitOps..."
kubectl apply -f kubernetes/apps/argocd/applicationset.yaml

# 9. Senha inicial ArgoCD
echo "=== Senha inicial ArgoCD ==="
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
echo ""

echo "=== Bootstrap concluído ==="
echo ""
echo "Próximos passos:"
echo "  1. Configure secrets via External Secrets Operator"
echo "  2. Rode: ./scripts/seed-database.sh"
echo "  3. Acesse ArgoCD: kubectl port-forward svc/argocd-server -n argocd 8080:80"
