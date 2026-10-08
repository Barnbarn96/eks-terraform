data "aws_caller_identity" "current" {}

# The IAM role behind your IAM Identity Center "AdministratorAccess" permission
# set. Looked up rather than hard-coded because the suffix is random.
data "aws_iam_roles" "sso_admin" {
  name_regex  = "AWSReservedSSO_AdministratorAccess_.*"
  path_prefix = "/aws-reserved/sso.amazonaws.com/"
}

module "network" {
  source = "../../modules/network"

  name         = var.cluster_name
  cluster_name = var.cluster_name
  azs          = var.azs
}

module "cluster" {
  source = "../../modules/cluster"

  cluster_name       = var.cluster_name
  kubernetes_version = var.kubernetes_version

  vpc_id             = module.network.vpc_id
  private_subnet_ids = module.network.private_subnet_ids

  endpoint_public_access_cidrs = var.endpoint_public_access_cidrs

  admin_principal_arns = {
    sso_admin = one(data.aws_iam_roles.sso_admin.arns)
  }
}
