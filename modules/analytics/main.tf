terraform {
  required_version = ">= 1.7"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.0"
    }
  }
}

resource "aws_iam_role" "athena_execution_role" {
  name = "${local.service_name}-${var.environment}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "athena.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy" "athena_s3_access" {
  role = aws_iam_role.athena_execution_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = ["s3:GetObject", "s3:ListBucket"]
        Resource = [
          "arn:aws:s3:::${var.transformed_bucket}",
          "arn:aws:s3:::${var.transformed_bucket}/*",
        ]
      },
      {
        Effect = "Allow"
        Action = ["s3:GetObject", "s3:PutObject", "s3:ListBucket"]
        Resource = [
          "arn:aws:s3:::${var.athena_results_bucket}",
          "arn:aws:s3:::${var.athena_results_bucket}/*",
        ]
      }
    ]
  })
}

resource "aws_iam_role_policy" "athena_glue_access" {
  role = aws_iam_role.athena_execution_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "glue:GetDatabase",
        "glue:GetTable",
        "glue:GetTables",
        "glue:GetPartitions",
      ]
      Resource = [
        "arn:aws:glue:*:*:catalog",
        "arn:aws:glue:*:*:database/${var.glue_database_name}",
        "arn:aws:glue:*:*:table/${var.glue_database_name}/*",
      ]
    }]
  })
}

resource "aws_athena_workgroup" "this" {
  #checkov:skip=CKV_AWS_159: Encryption at rest not required for query results in this pipeline
  name = "${var.environment}-${local.service_name}"

  configuration {
    result_configuration {
      output_location = "s3://${var.athena_results_bucket}/query-results/"
    }

    engine_version {
      selected_engine_version = "Athena engine version 3"
    }
  }
}
