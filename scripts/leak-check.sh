#!/usr/bin/env bash
# Look for billable lab resources that survived a teardown.
# Exit code 1 if anything is found.
# Usage: ./scripts/leak-check.sh   (run from Git Bash)
set -uo pipefail

export AWS_PROFILE="${AWS_PROFILE:-eks-lab}"
REGION="${AWS_REGION:-us-east-1}"
CLUSTER="${CLUSTER_NAME:-eks-lab}"
found=0

check() {
  local label="$1" output="$2"
  if [[ -n "$output" && "$output" != "None" ]]; then
    echo "LEAK  $label:"
    echo "$output" | sed 's/^/        /'
    found=1
  else
    echo "ok    $label"
  fi
}

echo "==> Leak check in $REGION"

check "EKS clusters" \
  "$(aws eks list-clusters --region "$REGION" --query 'clusters' --output text)"

check "EC2 instances (running/pending) tagged for the cluster" \
  "$(aws ec2 describe-instances --region "$REGION" \
      --filters "Name=instance-state-name,Values=pending,running,stopping,stopped" \
                "Name=tag-key,Values=kubernetes.io/cluster/$CLUSTER" \
      --query 'Reservations[].Instances[].[InstanceId,InstanceType]' --output text)"

check "Karpenter instances" \
  "$(aws ec2 describe-instances --region "$REGION" \
      --filters "Name=instance-state-name,Values=pending,running,stopping,stopped" \
                "Name=tag-key,Values=karpenter.sh/nodepool" \
      --query 'Reservations[].Instances[].[InstanceId,InstanceType]' --output text)"

check "NAT gateways" \
  "$(aws ec2 describe-nat-gateways --region "$REGION" \
      --filter "Name=state,Values=pending,available" "Name=tag:project,Values=eks-lab" \
      --query 'NatGateways[].NatGatewayId' --output text)"

check "Elastic IPs (unattached)" \
  "$(aws ec2 describe-addresses --region "$REGION" \
      --query 'Addresses[?AssociationId==null].[PublicIp,AllocationId]' --output text)"

check "Load balancers (ALB/NLB) from the LB controller" \
  "$(aws resourcegroupstaggingapi get-resources --region "$REGION" \
      --resource-type-filters elasticloadbalancing:loadbalancer \
      --tag-filters "Key=elbv2.k8s.aws/cluster,Values=$CLUSTER" \
      --query 'ResourceTagMappingList[].ResourceARN' --output text)"

check "EBS volumes (unattached)" \
  "$(aws ec2 describe-volumes --region "$REGION" \
      --filters "Name=status,Values=available" \
      --query 'Volumes[].[VolumeId,Size,CreateTime]' --output text)"

check "Network interfaces (unattached)" \
  "$(aws ec2 describe-network-interfaces --region "$REGION" \
      --filters "Name=status,Values=available" \
      --query 'NetworkInterfaces[].[NetworkInterfaceId,Description]' --output text)"

check "VPCs tagged project=eks-lab" \
  "$(aws ec2 describe-vpcs --region "$REGION" \
      --filters "Name=tag:project,Values=eks-lab" \
      --query 'Vpcs[].VpcId' --output text)"

# EKS can recreate its log group after destroy while logs are still flushing;
# if it does, it comes back with no retention and keeps storing data
check "EKS control plane log groups" \
  "$(aws logs describe-log-groups --region "$REGION" \
      --log-group-name-prefix "/aws/eks/$CLUSTER/" \
      --query 'logGroups[].logGroupName' --output text)"

# Karpenter-created instance profiles are named <cluster>_<hash>
check "Karpenter instance profiles" \
  "$(aws iam list-instance-profiles \
      --query "InstanceProfiles[?starts_with(InstanceProfileName, '${CLUSTER}_')].InstanceProfileName" \
      --output text)"

# Phase 2+: ExternalDNS records. Hosted zone itself is long-lived (bootstrap).
# TODO: list A/AAAA/TXT records owned by ExternalDNS once the domain exists.

if [[ $found -eq 1 ]]; then
  echo "==> LEAKS FOUND. Clean them up before you walk away."
  exit 1
fi
echo "==> Clean."
