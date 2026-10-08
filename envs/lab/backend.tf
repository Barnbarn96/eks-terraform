terraform {
  backend "s3" {
    # Created by ../../bootstrap (see its state_bucket_name output)
    bucket       = "eks-lab-tfstate-208553215046"
    key          = "envs/lab/terraform.tfstate"
    region       = "us-east-1"
    encrypt      = true
    use_lockfile = true # native S3 locking; no DynamoDB table needed
  }
}
