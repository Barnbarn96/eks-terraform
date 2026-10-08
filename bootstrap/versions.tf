terraform {
  # use_lockfile (native S3 state locking) needs >= 1.10
  required_version = ">= 1.10"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }

  # Bootstrap keeps LOCAL state on purpose: it creates the bucket that every
  # other config stores its state in. The local terraform.tfstate here is
  # gitignored; back it up somewhere safe (or migrate it into the bucket later).
}
