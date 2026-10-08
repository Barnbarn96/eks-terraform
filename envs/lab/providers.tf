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
