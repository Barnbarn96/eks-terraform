#!/usr/bin/env bash
# Tear down the lab in the right order, then check for leaks.
# Usage: ./scripts/down.sh   (run from Git Bash)
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ENV_DIR="$ROOT/envs/lab"
export AWS_PROFILE="${AWS_PROFILE:-eks-lab}"

echo "==> $(date '+%H:%M:%S') teardown start (profile: $AWS_PROFILE)"
aws sts get-caller-identity --query Arn --output text

CLUSTER=$(terraform -chdir="$ENV_DIR" output -raw cluster_name 2>/dev/null || true)

if [[ -n "$CLUSTER" ]] && kubectl --context "$CLUSTER" get nodes >/dev/null 2>&1; then
  # Controllers create AWS resources Terraform doesn't know about. Delete them
  # first, or `terraform destroy` hangs on the VPC (ENIs / security groups).
  KUBECTL="kubectl --context $CLUSTER"

  echo "==> Deleting Ingresses (ALBs) and LoadBalancer Services (NLBs)"
  $KUBECTL delete ingress --all -A --wait=true --timeout=5m || true
  $KUBECTL get svc -A -o jsonpath='{range .items[?(@.spec.type=="LoadBalancer")]}{.metadata.namespace}{" "}{.metadata.name}{"\n"}{end}' |
    while read -r ns name; do
      [[ -n "$ns" ]] && $KUBECTL delete svc -n "$ns" "$name" --wait=true --timeout=5m || true
    done

  # Phase 2+: Karpenter nodes are not in Terraform state
  if $KUBECTL get crd nodepools.karpenter.sh >/dev/null 2>&1; then
    echo "==> Deleting Karpenter NodePools and waiting for their nodes to go"
    $KUBECTL delete nodepools --all --wait=true --timeout=10m || true
    $KUBECTL wait --for=delete nodeclaims --all --timeout=10m || true
  fi

  echo "==> Deleting PVCs (releases EBS volumes)"
  $KUBECTL delete pvc --all -A --wait=true --timeout=5m || true

  # Give the LB controller / ExternalDNS a moment to finish AWS-side cleanup
  sleep 30
else
  echo "==> Cluster not reachable; skipping in-cluster cleanup"
fi

echo "==> terraform destroy"
terraform -chdir="$ENV_DIR" destroy -input=false -auto-approve

"$ROOT/scripts/leak-check.sh"

echo "==> $(date '+%H:%M:%S') teardown done"
