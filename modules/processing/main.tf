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

resource "aws_glue_job" "this" {
  #checkov:skip=CKV_AWS_195: Temporary skiping the rule until the processing module is totally implemented TODO: REMOVE IT
  name     = "${var.environment}-${local.service_name}-job"
  role_arn = aws_iam_role.eventbridge_execution_role.arn

  command {
    script_location = "s3://${var.glue_scripts_bucket}/transform.py"
  }
}

resource "aws_iam_role" "eventbridge_execution_role" {
  name = "${local.service_name}-eventbridge"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "events.amazonaws.com" }
    }]
  })
}

resource "aws_glue_workflow" "this" {
  name = "${var.environment}-${local.service_name}-workflow"
}

resource "aws_glue_trigger" "this" {
  name          = "${var.environment}-${local.service_name}-trigger"
  type          = "ON_DEMAND"
  workflow_name = aws_glue_workflow.this.name

  actions {
    job_name = aws_glue_job.this.name
  }
}

resource "aws_iam_role_policy" "eventbridge_to_glue" {
  role = aws_iam_role.eventbridge_execution_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["glue:notifyEvent"]
      Resource = aws_glue_workflow.this.arn
    }]
  })
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
  role_arn = aws_iam_role.eventbridge_execution_role.arn
}
