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

resource "aws_iam_role" "lambda_execution_role" {
  name = local.service_name

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Sid    = ""
      Principal = {
        Service = "lambda.amazonaws.com"
      }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_policy" {
  role       = aws_iam_role.lambda_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy" "lambda_to_s3" {
  role = aws_iam_role.lambda_execution_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["s3:GetObject", "s3:PutObject"]
      Resource = "arn:aws:s3:::${var.target_bucket}/*"
    }]
  })
}

resource "aws_cloudwatch_log_group" "this" {
  # checkov:skip=CKV_AWS_158: KMS encryption for CloudWatch Log Groups is not required for this workload
  name              = "/aws/lambda/${var.environment}-${local.service_name}"
  retention_in_days = 365
}

resource "aws_sqs_queue" "dlq" {
  name                      = "${var.environment}-${local.service_name}-dlq"
  message_retention_seconds = 1209600
  sqs_managed_sse_enabled   = true
}

resource "aws_iam_role_policy" "lambda_to_dlq" {
  role = aws_iam_role.lambda_execution_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["sqs:SendMessage"]
      Resource = aws_sqs_queue.dlq.arn
    }]
  })
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

resource "aws_iam_role" "scheduler_execution_role" {
  name = "${local.service_name}-scheduler"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Sid    = ""
      Principal = {
        Service = "scheduler.amazonaws.com"
      }
      }
    ]
  })
}

resource "aws_iam_role_policy" "scheduler_to_lambda" {
  role = aws_iam_role.scheduler_execution_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["lambda:InvokeFunction"]
      Resource = aws_lambda_function.this.arn
    }]
  })
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
