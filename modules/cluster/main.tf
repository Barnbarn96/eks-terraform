module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "21.29.0"

  name               = var.cluster_name
  kubernetes_version = var.kubernetes_version

  vpc_id     = var.vpc_id
  subnet_ids = var.private_subnet_ids

  # The module defaults to a private-only endpoint, which would lock out
  # kubectl from a laptop. Public + private: nodes talk to the API over the
  # private endpoint, you reach it over the public one.
  endpoint_public_access       = true
  endpoint_private_access      = true
  endpoint_public_access_cidrs = var.endpoint_public_access_cidrs

  # Ephemeral lab: allow `terraform destroy` to remove the cluster
  deletion_protection = false

  # Skip the per-cluster customer-managed KMS key (~US$1/month, and each
  # teardown would leave one pending deletion). EKS already envelope-encrypts
  # Kubernetes API data with an AWS-owned key by default.
  create_kms_key    = false
  encryption_config = null

  # Control plane logs go to CloudWatch; short retention keeps cost near zero
  enabled_log_types                      = ["api", "audit", "authenticator"]
  cloudwatch_log_group_retention_in_days = var.log_retention_days

  # Access entries (API mode), not the legacy aws-auth ConfigMap.
  # Admins are granted explicitly rather than "whoever ran terraform apply".
  authentication_mode                      = "API"
  enable_cluster_creator_admin_permissions = false

  access_entries = {
    for name, arn in var.admin_principal_arns : name => {
      principal_arn = arn
      policy_associations = {
        cluster_admin = {
          policy_arn   = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
          access_scope = { type = "cluster" }
        }
      }
    }
  }

  # Karpenter (Phase 2) finds the node security group by this tag
  node_security_group_tags = {
    "karpenter.sh/discovery" = var.cluster_name
  }

  addons = {
    # before_compute: these must exist before nodes join, or nodes come up
    # with the wrong networking config / no credential agent
    vpc-cni = {
      before_compute = true
      configuration_values = jsonencode({
        env = {
          # Prefix delegation: each ENI slot gets a /28 instead of one IP.
          # Without it a t4g.medium caps at 17 pods, which the platform
          # add-ons alone would nearly exhaust.
          ENABLE_PREFIX_DELEGATION = "true"
          WARM_PREFIX_TARGET       = "1"
        }
        # Needed for NetworkPolicy enforcement in Phase 3
        enableNetworkPolicy = "true"
      })
    }
    eks-pod-identity-agent = {
      before_compute = true
    }
    kube-proxy = {}
    coredns    = {}
    aws-ebs-csi-driver = {
      pod_identity_association = [{
        role_arn        = aws_iam_role.ebs_csi.arn
        service_account = "ebs-csi-controller-sa"
      }]
    }
  }

  eks_managed_node_groups = {
    system = {
      ami_type       = var.system_ami_type
      instance_types = var.system_instance_types
      capacity_type  = "ON_DEMAND"

      min_size     = 2
      max_size     = 3
      desired_size = 2

      labels = {
        "node-role" = "system"
      }

      # Optional: uncomment to keep app pods off these nodes once Karpenter
      # exists. Every platform add-on then needs a matching toleration.
      # taints = {
      #   critical_addons = {
      #     key    = "CriticalAddonsOnly"
      #     value  = "true"
      #     effect = "NO_SCHEDULE"
      #   }
      # }

      update_config = {
        max_unavailable = 1
      }
    }
  }
}

# -----------------------------------------------------------------------------
# EBS CSI driver identity (Pod Identity)
# Lives here rather than in platform-iam because the driver is an EKS managed
# add-on created with the cluster.
# -----------------------------------------------------------------------------

data "aws_iam_policy_document" "pod_identity_trust" {
  statement {
    actions = ["sts:AssumeRole", "sts:TagSession"]

    principals {
      type        = "Service"
      identifiers = ["pods.eks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "ebs_csi" {
  name               = "${var.cluster_name}-ebs-csi"
  assume_role_policy = data.aws_iam_policy_document.pod_identity_trust.json
}

resource "aws_iam_role_policy_attachment" "ebs_csi" {
  role       = aws_iam_role.ebs_csi.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
}
