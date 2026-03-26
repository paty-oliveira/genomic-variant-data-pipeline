resource "aws_iam_role" "glue_execution_role" {
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


resource "aws_iam_role_policy" "glue_eventbridge_access" {
  role = aws_iam_role.glue_execution_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["glue:notifyEvent"]
      Resource = aws_glue_workflow.this.arn
    }]
  })
}

resource "aws_iam_role_policy" "glue_catalog_access" {
  role = aws_iam_role.glue_execution_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "glue:GetDatabase",
        "glue:GetTable",
        "glue:CreateTable",
        "glue:UpdateTable",
        "glue:DeleteTable",
        "glue:GetPartitions",
        "glue:BatchCreatePartition",
      ]
      Resource = [
        "arn:aws:glue:*:*:catalog",
        "arn:aws:glue:*:*:database/${aws_glue_catalog_database.this.name}",
        "arn:aws:glue:*:*:table/${aws_glue_catalog_database.this.name}/*",
      ]
    }]
  })
}

resource "aws_iam_role_policy" "glue_s3_access" {
  role = aws_iam_role.glue_execution_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = ["s3:GetObject", "s3:ListBucket"]
        Resource = [
          "arn:aws:s3:::${var.raw_bucket}",
          "arn:aws:s3:::${var.raw_bucket}/*",
        ]
      },
      {
        Effect = "Allow"
        Action = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject", "s3:ListBucket"]
        Resource = [
          "arn:aws:s3:::${var.transformed_bucket}",
          "arn:aws:s3:::${var.transformed_bucket}/*",
        ]
      }
    ]
  })
}
