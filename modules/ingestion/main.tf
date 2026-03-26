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
  name              = "/aws/lambda/${var.environment}-${local.service_name}"
  retention_in_days = 365
  kms_key_id        = aws_kms_key.log_group.arn
}

resource "aws_sqs_queue" "dlq" {
  name                      = "${var.environment}-${local.service_name}-dlq"
  message_retention_seconds = 1209600
  sqs_managed_sse_enabled   = true
}

resource "aws_lambda_function" "this" {
  #checkov:skip=CKV_AWS_173:Env vars are encrypted with AWS-managed key; CMK not required
  #checkov:skip=CKV_AWS_117:Lambda runs outside VPC by design for public FTP access
  #checkov:skip=CKV_AWS_272:AWS Signer is not supported in LocalStack; code integrity is enforced via CI/CD pipeline
  #checkov:skip=CKV_AWS_115:Concurrency limit not required for a scheduled monthly ingestion function
  function_name    = "${var.environment}-${local.service_name}"
  filename         = data.archive_file.this.output_path
  source_code_hash = data.archive_file.this.output_base64sha256
  role             = aws_iam_role.lambda_execution_role.arn
  handler          = "handler.lambda_handler"

  runtime = "python3.12"
  timeout = 900

  tracing_config {
    mode = "Active"
  }

  dead_letter_config {
    target_arn = aws_sqs_queue.dlq.arn
  }

  environment {
    variables = {
      TARGET_BUCKET = var.target_bucket
      FTP_HOST      = var.ftp_host
      FTP_PATH      = var.ftp_path
    }
  }

  tags = {
    Environment = var.environment
  }

  depends_on = [aws_cloudwatch_log_group.this]
}

resource "aws_scheduler_schedule" "this" {
  #checkov:skip=CKV_AWS_297:Not required for this kind of experimentation
  schedule_expression = "cron(0 0 ? * 5#2 *)"
  flexible_time_window {
    mode = "OFF"
  }

  target {
    arn      = aws_lambda_function.this.arn
    role_arn = aws_iam_role.scheduler_execution_role.arn
  }
}
