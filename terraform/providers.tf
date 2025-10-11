terraform {
  required_version = ">= 1.6.0"
  required_providers {
    aws = { source = "hashicorp/aws", version = "~> 5.55" }
  }
}

variable "aws_region" { type = string }
variable "aws_profile" { type = string, default = null }
variable "aws_access_key_id" { type = string, default = null, sensitive = true }
variable "aws_secret_access_key" { type = string, default = null, sensitive = true }
variable "aws_session_token" { type = string, default = null, sensitive = true }
variable "assume_role_arn" { type = string, default = null }
variable "assume_role_external_id" { type = string, default = null }

provider "aws" {
  region     = var.aws_region
  profile    = var.aws_profile
  access_key = var.aws_access_key_id
  secret_key = var.aws_secret_access_key
  token      = var.aws_session_token

  # assume_role {
  #   role_arn     = var.assume_role_arn
  #   session_name = "tf-session"
  #   external_id  = var.assume_role_external_id
  # }
}

# Certificados para CloudFront deben estar en us-east-1
provider "aws" {
  alias  = "use1"
  region = "us-east-1"
}
