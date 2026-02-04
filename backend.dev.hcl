bucket   = "dev-terraform-state"
key      = "terraform.tfstate"
region   = "eu-central-1"

access_key = "test"
secret_key = "test"

skip_credentials_validation = true
skip_metadata_api_check     = true
skip_requesting_account_id  = true

endpoints = {
  s3 = "http://s3.localhost.localstack.cloud:4566"
}