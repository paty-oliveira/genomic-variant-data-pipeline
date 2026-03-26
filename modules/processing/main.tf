terraform {
  required_version = ">= 1.7"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = ">= 2.0"
    }
  }
}

resource "aws_glue_workflow" "this" {
  name = "${var.environment}-${local.service_name}-workflow"
}

resource "aws_glue_trigger" "this" {
  name          = "${var.environment}-${local.service_name}-trigger"
  type          = "EVENT"
  workflow_name = aws_glue_workflow.this.name

  actions {
    job_name = aws_glue_job.this.name
  }
}

resource "aws_glue_catalog_database" "this" {
  name = var.glue_database_name
}

resource "aws_kms_key" "log_group" {
  description             = "KMS key for ${local.service_name} CloudWatch log group"
  deletion_window_in_days = 7
  enable_key_rotation     = true

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "Enable IAM User Permissions"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      },
      {
        Sid    = "Allow CloudWatch Logs"
        Effect = "Allow"
        Principal = {
          Service = "logs.${data.aws_region.current.region}.amazonaws.com"
        }
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:DescribeKey"
        ]
        Resource = "*"
        Condition = {
          ArnLike = {
            "kms:EncryptionContext:aws:logs:arn" = "arn:aws:logs:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:log-group:*"
          }
        }
      }
    ]
  })
}

resource "aws_cloudwatch_log_group" "this" {
  name              = "/aws/glue/${var.environment}-${local.service_name}"
  retention_in_days = 365
  kms_key_id        = aws_kms_key.log_group.arn
}

resource "aws_glue_job" "this" {
  #checkov:skip=CKV_AWS_195: Temporary skiping the rule until the processing module is totally implemented TODO: REMOVE IT
  depends_on = [aws_s3_object.transform_script]

  name     = "${var.environment}-${local.service_name}-job"
  role_arn = aws_iam_role.glue_execution_role.arn

  command {
    name            = "GlueTransform"
    script_location = "s3://${var.glue_scripts_bucket}/transform.py"
    python_version  = "3"
  }

  default_arguments = {
    "--datalake-formats"                 = "iceberg"
    "--transformed_bucket"               = var.transformed_bucket
    "--continuous-log-logGroup"          = aws_cloudwatch_log_group.this.name
    "--enable-continuous-cloudwatch-log" = "true"
    "--enable-continuous-log-filter"     = "true"
    "--enable-metrics"                   = ""
  }

  glue_version      = "5.0"
  max_retries       = 1
  timeout           = 7200
  number_of_workers = 5
  worker_type       = "G.2X"
}

resource "aws_s3_object" "transform_script" {
  bucket = var.glue_scripts_bucket
  key    = "scripts/transform.py"
  source = "${path.module}/scripts/transform.py"
  etag   = filemd5("${path.module}/scripts/transform.py")
}

resource "aws_cloudwatch_event_rule" "this" {
  name  = "${var.environment}-${local.service_name}-raw-object-created"
  state = "ENABLED"

  event_pattern = jsonencode({
    detail-type = ["Object Created"]
    source      = ["aws.s3"]
    detail = {
      bucket = {
        name = [var.raw_bucket]
      }
    }
  })
}

resource "aws_cloudwatch_event_target" "this" {
  rule     = aws_cloudwatch_event_rule.this.name
  arn      = aws_glue_workflow.this.arn
  role_arn = aws_iam_role.glue_execution_role.arn

  input_transformer {
    input_paths = {
      bucket_name = "$.detail.bucket.name"
      object_key  = "$.detail.object.key"
      event_time  = "$.time"
    }
    input_template = "{\"--bucket_name\": \"<bucket_name>\", \"--object_key\": \"<object_key>\", \"--event_time\": \"<event_time>\"}"
  }
}
