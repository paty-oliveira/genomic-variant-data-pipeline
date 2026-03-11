terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.0"
    }
  }
}

resource "aws_s3_bucket" "this" {
  for_each = var.bucket_names

  bucket = "${var.environment}-${each.key}"
}

resource "aws_s3_bucket_versioning" "this" {
  for_each = var.buckets_versioned

  bucket = aws_s3_bucket.this[each.key].id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_public_access_block" "this" {
  for_each = var.bucket_names

  bucket = aws_s3_bucket.this[each.key].id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_notification" "eventbridge" {
  for_each = var.buckets_eventbridge_enabled

  bucket      = aws_s3_bucket.this[each.key].id
  eventbridge = true
}
