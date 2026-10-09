# IAM for platform add-ons that ArgoCD installs.
#
# With Pod Identity the link between a Kubernetes service account and an IAM
# role lives in AWS (cluster + namespace + service account), so the Helm values
# in the gitops repo never need a role ARN. Names below must match the
# namespace / service account each chart is configured with in the gitops repo.

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

locals {
  account_id = data.aws_caller_identity.current.account_id
  region     = data.aws_region.current.region
}

# -----------------------------------------------------------------------------
# Karpenter: controller role (Pod Identity), node role, interruption queue,
# EventBridge rules, and an access entry so Karpenter's nodes can join.
# -----------------------------------------------------------------------------

module "karpenter" {
  source  = "terraform-aws-modules/eks/aws//modules/karpenter"
  version = "21.29.0"

  cluster_name = var.cluster_name

  namespace       = "kube-system"
  service_account = "karpenter"

  # Fixed names so the gitops repo can reference them (values.yaml,
  # EC2NodeClass) without Terraform outputs
  iam_role_use_name_prefix      = false
  iam_role_name                 = "${var.cluster_name}-karpenter-controller"
  node_iam_role_use_name_prefix = false
  node_iam_role_name            = "${var.cluster_name}-karpenter-node"
  queue_name                    = "${var.cluster_name}-karpenter"

  # Lets you `aws ssm start-session` onto a node instead of opening SSH
  node_iam_role_additional_policies = {
    AmazonSSMManagedInstanceCore = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  }
}

# -----------------------------------------------------------------------------
# AWS Load Balancer Controller
# -----------------------------------------------------------------------------

module "aws_lb_controller_pod_identity" {
  source  = "terraform-aws-modules/eks-pod-identity/aws"
  version = "2.9.0"

  name            = "${var.cluster_name}-aws-lb-controller"
  use_name_prefix = false

  attach_aws_lb_controller_policy = true

  associations = {
    this = {
      cluster_name    = var.cluster_name
      namespace       = "kube-system"
      service_account = "aws-load-balancer-controller"
    }
  }
}

# -----------------------------------------------------------------------------
# External Secrets: read-only access to secrets under the lab prefix.
# Secrets use the AWS-managed aws/secretsmanager key, whose key policy already
# allows decrypt via Secrets Manager for principals in this account, so no
# extra KMS statement is needed. A customer-managed key would need one.
# -----------------------------------------------------------------------------

module "external_secrets_pod_identity" {
  source  = "terraform-aws-modules/eks-pod-identity/aws"
  version = "2.9.0"

  name            = "${var.cluster_name}-external-secrets"
  use_name_prefix = false

  attach_external_secrets_policy        = true
  external_secrets_secrets_manager_arns = ["arn:aws:secretsmanager:${local.region}:${local.account_id}:secret:${var.secrets_prefix}"]

  associations = {
    this = {
      cluster_name    = var.cluster_name
      namespace       = "external-secrets"
      service_account = "external-secrets"
    }
  }
}

# cert-manager (Route 53 DNS-01) and ExternalDNS (IRSA) need a hosted zone ARN;
# they're added here once the domain exists.
