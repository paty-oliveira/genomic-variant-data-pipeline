# Validation of S3 bucket creation

mock_provider "aws" {}

variables {
  environment = "development"
}

run "valid_s3_bucket_name" {
  command = plan

  assert {
    condition     = aws_s3_bucket.raw_bucket.bucket == "development-genomic-raw"
    error_message = "S3 bucket name does not match the expected"
  }
}
