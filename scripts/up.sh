#!/usr/bin/env bash
# Spin up the lab: terraform apply, then point kubectl at the cluster.
# Usage: ./scripts/up.sh   (run from Git Bash; needs `aws sso login` first)
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ENV_DIR="$ROOT/envs/lab"
export AWS_PROFILE="${AWS_PROFILE:-eks-lab}"

start=$(date +%s)
echo "==> $(date '+%H:%M:%S') session start (profile: $AWS_PROFILE)"

# Fail fast if the SSO session has expired
aws sts get-caller-identity --query Arn --output text

terraform -chdir="$ENV_DIR" init -input=false
terraform -chdir="$ENV_DIR" apply -input=false -auto-approve

REGION=$(terraform -chdir="$ENV_DIR" output -raw region)
CLUSTER=$(terraform -chdir="$ENV_DIR" output -raw cluster_name)

aws eks update-kubeconfig --region "$REGION" --name "$CLUSTER" --alias "$CLUSTER"

echo "==> Waiting for nodes to be Ready"
kubectl wait --for=condition=Ready nodes --all --timeout=10m
kubectl get nodes -o wide

echo "==> ArgoCD applications (add-ons keep syncing for a few more minutes)"
kubectl -n argocd get applications 2>/dev/null || true
cat <<'EOF'
    Watch:    kubectl -n argocd get applications -w
    UI:       kubectl -n argocd port-forward svc/argocd-server 8080:80   -> http://localhost:8080
    Password: kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d; echo
EOF

echo "==> Up in $(( ($(date +%s) - start) / 60 )) min. Remember: ./scripts/down.sh before you stop."
