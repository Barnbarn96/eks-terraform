locals {
  # Private subnets get /19s (8k IPs each): VPC CNI gives every pod a VPC IP,
  # and prefix delegation hands out /28 blocks, so pod subnets need room.
  # Public subnets only hold the NAT gateway and ALBs, so /24s are plenty.
  #   10.0.0.0/19, 10.0.32.0/19   -> private
  #   10.0.96.0/24, 10.0.97.0/24  -> public
  private_subnets = [for i, _ in var.azs : cidrsubnet(var.vpc_cidr, 3, i)]
  public_subnets  = [for i, _ in var.azs : cidrsubnet(var.vpc_cidr, 8, 96 + i)]
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "6.7.3"

  name = var.name
  cidr = var.vpc_cidr
  azs  = var.azs

  private_subnets = local.private_subnets
  public_subnets  = local.public_subnets

  # One NAT gateway for the whole VPC: cheapest option, but an AZ outage
  # takes out egress for both AZs. Production uses one per AZ (see ADR-002).
  enable_nat_gateway     = true
  single_nat_gateway     = true
  one_nat_gateway_per_az = false

  enable_dns_hostnames = true
  enable_dns_support   = true

  # AWS Load Balancer Controller picks subnets by these tags:
  # internet-facing ALBs go in public subnets, internal ones in private.
  public_subnet_tags = {
    "kubernetes.io/role/elb" = "1"
  }

  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" = "1"
    # Karpenter's EC2NodeClass selects subnets with this tag
    "karpenter.sh/discovery" = var.cluster_name
  }
}

data "aws_region" "current" {}

# S3 gateway endpoint: free, and ECR serves image layers from S3, so image
# pulls from the private subnets skip the NAT gateway's per-GB processing fee.
# (Interface endpoints for ECR/STS/EC2 are billed hourly per AZ, so they're
# left out of the lab.)
resource "aws_vpc_endpoint" "s3" {
  vpc_id            = module.vpc.vpc_id
  service_name      = "com.amazonaws.${data.aws_region.current.region}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = module.vpc.private_route_table_ids

  tags = {
    Name = "${var.name}-s3"
  }
}
