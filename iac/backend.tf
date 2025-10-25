terraform {
  backend "s3" {
    bucket  = "tf-state-placeholder"
    key     = "infra/terraform.tfstate"
    region  = "us-east-1"
    encrypt = true
  }
}
