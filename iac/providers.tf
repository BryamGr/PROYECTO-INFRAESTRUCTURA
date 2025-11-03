terraform {
  required_version = ">= 1.6.0"
  required_providers {
    aws = { source = "hashicorp/aws", version = "~> 5.55" }
  }
}

provider "aws" {
  region     = var.aws_region
  profile    = var.aws_profile
  access_key = var.aws_access_key_id
  secret_key = var.aws_secret_access_key
  token      = var.aws_session_token

  dynamic "assume_role" {
    for_each = var.assume_role_arn != null ? [var.assume_role_arn] : []
    content {
      role_arn     = assume_role.value
      session_name = "${var.project_name}-terraform"
      external_id  = var.assume_role_external_id
    }
  }
}


provider "aws" {
  alias  = "use1"
  region = "us-east-1"
  profile    = var.aws_profile
  access_key = var.aws_access_key_id
  secret_key = var.aws_secret_access_key
  token      = var.aws_session_token

  dynamic "assume_role" {
    for_each = var.assume_role_arn != null ? [var.assume_role_arn] : []
    content {
      role_arn     = assume_role.value
      session_name = "${var.project_name}-terraform"
      external_id  = var.assume_role_external_id
    }
  }
}
