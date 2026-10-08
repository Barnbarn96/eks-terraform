# Phase 1 wires the modules together here:
#   module "network" { source = "../../modules/network" ... }
#   module "cluster" { source = "../../modules/cluster" ... }

data "aws_caller_identity" "current" {}

output "account_id" {
  description = "Sanity check that remote state + credentials work"
  value       = data.aws_caller_identity.current.account_id
}
