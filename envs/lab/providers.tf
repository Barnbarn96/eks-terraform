provider "aws" {
  region = var.region

  # Every resource gets tagged, so leak-check.sh and Cost Explorer can find it
  default_tags {
    tags = {
      project    = "eks-lab"
      managed-by = "terraform"
      env        = "lab"
    }
  }
}

# Talks to the cluster created in this same apply. Auth uses a short-lived
# token from `aws eks get-token` (your SSO session), not a stored kubeconfig.
provider "helm" {
  kubernetes = {
    host                   = module.cluster.cluster_endpoint
    cluster_ca_certificate = base64decode(module.cluster.cluster_certificate_authority_data)

    exec = {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args        = ["eks", "get-token", "--cluster-name", module.cluster.cluster_name, "--region", var.region]
    }
  }
}
