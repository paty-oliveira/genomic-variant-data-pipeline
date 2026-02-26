terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "6.28.0"
    }
  }
}

provider "aws" {
  access_key = var.aws_access_key
  secret_key = var.aws_secret_key
  region     = var.aws_region

  skip_credentials_validation = var.aws_skip_validation
  skip_requesting_account_id  = var.aws_skip_validation
  skip_region_validation      = var.aws_skip_validation
  skip_metadata_api_check     = var.aws_skip_validation
  s3_use_path_style           = var.aws_skip_validation

  endpoints {
    s3 = var.aws_endpoint_url
  }
}
