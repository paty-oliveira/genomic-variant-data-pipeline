# Validation of S3 bucket creation

mock_provider "aws" {}

variables {
  environment                 = "development"
  bucket_names                = toset(["clinvar-raw", "clinvar-transformed", "athena-results", "glue-scripts"])
  buckets_versioned           = toset(["clinvar-raw"])
  buckets_eventbridge_enabled = toset(["clinvar-raw"])
}

run "valid_s3_bucket_names" {
  command = plan

  assert {
    condition     = aws_s3_bucket.this["clinvar-raw"].bucket == "${var.environment}-clinvar-raw"
    error_message = "S3 bucket name does not match the expected"
  }

  assert {
    condition     = aws_s3_bucket.this["clinvar-transformed"].bucket == "${var.environment}-clinvar-transformed"
    error_message = "S3 bucket name does not match the expected"
  }

  assert {
    condition     = aws_s3_bucket.this["athena-results"].bucket == "${var.environment}-athena-results"
    error_message = "S3 bucket name does not match the expected"
  }

  assert {
    condition     = aws_s3_bucket.this["glue-scripts"].bucket == "${var.environment}-glue-scripts"
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

run "enable_eventbridge_notifications_raw_bucket" {
  command = apply

  assert {
    condition     = aws_s3_bucket_notification.eventbridge["clinvar-raw"].eventbridge == true
    error_message = "EventBridge notifications must be enabled on the clinvar-raw bucket"
  }

  assert {
    condition     = aws_s3_bucket_notification.eventbridge["clinvar-raw"].bucket == aws_s3_bucket.this["clinvar-raw"].id
    error_message = "EventBridge notification must be attached to the clinvar-raw bucket"
  }
}
