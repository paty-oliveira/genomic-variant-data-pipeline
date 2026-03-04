# Validation of S3 bucket creation

mock_provider "aws" {}

variables {
  environment       = "development"
  bucket_names      = toset(["clinvar-raw", "clinvar-transformed", "athena-results", "glue-scripts"])
  buckets_versioned = toset(["clinvar-raw"])
}

run "valid_s3_bucket_names" {
  command = plan

  assert {
    condition     = aws_s3_bucket.this["clinvar-raw"].bucket == "development-clinvar-raw"
    error_message = "S3 bucket name does not match the expected"
  }

  assert {
    condition     = aws_s3_bucket.this["clinvar-transformed"].bucket == "development-clinvar-transformed"
    error_message = "S3 bucket name does not match the expected"
  }

  assert {
    condition     = aws_s3_bucket.this["athena-results"].bucket == "development-athena-results"
    error_message = "S3 bucket name does not match the expected"
  }

  assert {
    condition     = aws_s3_bucket.this["glue-scripts"].bucket == "development-glue-scripts"
    error_message = "S3 bucket name does not match the expected"
  }
}

run "enable_s3_bucket_versioning_raw_bucket" {
  command = plan

  assert {
    condition     = aws_s3_bucket_versioning.this["clinvar-raw"].versioning_configuration[0].status == "Enabled"
    error_message = "S3 bucket versioning is not enabled"
  }
}

run "block_s3_bucket_public_access" {
  command = plan

  assert {
    condition     = aws_s3_bucket_public_access_block.this["clinvar-raw"].block_public_acls == true
    error_message = "S3 bucket does not block public access"
  }
}
