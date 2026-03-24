# Validation of ClinVar ingestion Lambda resources

provider "aws" {
  access_key                  = "test"
  secret_key                  = "test"
  region                      = "eu-central-1"
  skip_credentials_validation = true
  skip_requesting_account_id  = true
  skip_region_validation      = true
  skip_metadata_api_check     = true
  s3_use_path_style           = true

  endpoints {
    s3             = "http://localhost:4566"
    iam            = "http://localhost:4566"
    kms            = "http://localhost:4566"
    lambda         = "http://localhost:4566"
    cloudwatchlogs = "http://localhost:4566"
    scheduler      = "http://localhost:4566"
    sts            = "http://localhost:4566"
    sqs            = "http://localhost:4566"
  }
}

variables {
  environment   = "development"
  target_bucket = "development-clinvar-raw"
  ftp_host      = "ftp.ncbi.nlm.nih.gov"
  ftp_path      = "/pub/clinvar/xml/"
}


run "valid_lambda_iam_role_name" {
  command = plan

  assert {
    condition     = aws_iam_role.lambda_execution_role.name == "ingestion-service"
    error_message = "Lambda IAM role name does not match expected"
  }

  assert {
    condition     = jsondecode(aws_iam_role.lambda_execution_role.assume_role_policy).Statement[0].Principal.Service == "lambda.amazonaws.com"
    error_message = "Lambda IAM role must trust lambda.amazonaws.com"
  }
}

run "valid_lambda_basic_execution_policy" {
  command = plan

  assert {
    condition     = aws_iam_role_policy_attachment.lambda_policy.policy_arn == "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
    error_message = "AWSLambdaBasicExecutionRole managed policy must be attached to the Lambda role"
  }
}

run "valid_lambda_s3_policy" {
  command = plan

  assert {
    condition     = strcontains(aws_iam_role_policy.lambda_to_s3.policy, "s3:GetObject")
    error_message = "Lambda IAM policy must grant s3:GetObject (required for HeadObject)"
  }

  assert {
    condition     = strcontains(aws_iam_role_policy.lambda_to_s3.policy, "s3:PutObject")
    error_message = "Lambda IAM policy must grant s3:PutObject"
  }

  assert {
    condition     = strcontains(aws_iam_role_policy.lambda_to_s3.policy, "${var.environment}-clinvar-raw")
    error_message = "Lambda IAM policy must scope s3:PutObject to the target bucket"
  }
}

run "valid_kms_key_for_log_group" {
  command = plan

  assert {
    condition     = aws_kms_key.log_group.enable_key_rotation == true
    error_message = "KMS key for log group must have key rotation enabled"
  }

  assert {
    condition     = aws_kms_key.log_group.deletion_window_in_days == 7
    error_message = "KMS key deletion window must be 7 days"
  }

  assert {
    condition     = strcontains(aws_kms_key.log_group.policy, "logs.")
    error_message = "KMS key policy must grant access to the CloudWatch Logs service principal"
  }

  assert {
    condition     = strcontains(aws_kms_key.log_group.policy, "kms:GenerateDataKey*")
    error_message = "KMS key policy must allow kms:GenerateDataKey* for CloudWatch Logs"
  }

  assert {
    condition     = strcontains(aws_kms_key.log_group.policy, "kms:EncryptionContext:aws:logs:arn")
    error_message = "KMS key policy must scope CloudWatch Logs access via EncryptionContext condition"
  }
}

run "valid_cloudwatch_log_group" {
  command = apply

  override_resource {
    target = aws_iam_role.lambda_execution_role
    values = {
      id   = "ingestion-service"
      arn  = "arn:aws:iam::000000000000:role/ingestion-service"
      name = "ingestion-service"
    }
  }

  override_resource {
    target = aws_iam_role_policy_attachment.lambda_policy
    values = {}
  }

  override_resource {
    target = aws_iam_role_policy.lambda_to_s3
    values = {
      id = "ingestion-service:lambda_to_s3"
    }
  }

  override_resource {
    target = aws_iam_role_policy.lambda_to_dlq
    values = {
      id = "ingestion-service:lambda_to_dlq"
    }
  }

  override_resource {
    target = aws_sqs_queue.dlq
    values = {
      arn = "arn:aws:sqs:eu-central-1:000000000000:development-ingestion-service-dlq"
    }
  }

  override_resource {
    target = aws_lambda_function.this
    values = {
      arn = "arn:aws:lambda:eu-central-1:000000000000:function:development-ingestion-service"
    }
  }

  override_resource {
    target = aws_iam_role.scheduler_execution_role
    values = {
      id   = "ingestion-service-scheduler"
      arn  = "arn:aws:iam::000000000000:role/ingestion-service-scheduler"
      name = "ingestion-service-scheduler"
    }
  }

  override_resource {
    target = aws_iam_role_policy.scheduler_to_lambda
    values = {
      id = "ingestion-service-scheduler:scheduler_to_lambda"
    }
  }

  override_resource {
    target = aws_scheduler_schedule.this
    values = {
      id = "default/ingestion-service"
    }
  }

  assert {
    condition     = aws_cloudwatch_log_group.this.name == "/aws/lambda/development-ingestion-service"
    error_message = "Log group name must follow /aws/lambda/{environment}-ingestion-service convention"
  }

  assert {
    condition     = aws_cloudwatch_log_group.this.retention_in_days == 365
    error_message = "Log group retention must be 365 days"
  }

  assert {
    condition     = aws_cloudwatch_log_group.this.kms_key_id == aws_kms_key.log_group.arn
    error_message = "Log group must be encrypted with the ingestion KMS key"
  }
}


run "valid_lambda_function" {
  command = plan

  assert {
    condition     = aws_lambda_function.this.function_name == "${var.environment}-ingestion-service"
    error_message = "Lambda function name must follow {environment}-ingestion-service convention"
  }

  assert {
    condition     = aws_lambda_function.this.runtime == "python3.12"
    error_message = "Lambda runtime must be python3.12"
  }

  assert {
    condition     = aws_lambda_function.this.timeout == 900
    error_message = "Lambda timeout must be 900 seconds (15 minutes max)"
  }

  assert {
    condition     = aws_lambda_function.this.environment[0].variables["TARGET_BUCKET"] == "${var.environment}-clinvar-raw"
    error_message = "Lambda must receive TARGET_BUCKET environment variable"
  }

  assert {
    condition     = aws_lambda_function.this.environment[0].variables["FTP_HOST"] == "${var.ftp_host}"
    error_message = "Lambda must receive FTP_HOST environment variable"
  }

  assert {
    condition     = aws_lambda_function.this.environment[0].variables["FTP_PATH"] == "${var.ftp_path}"
    error_message = "Lambda must receive FTP_PATH environment variable"
  }

  assert {
    condition     = aws_lambda_function.this.source_code_hash != ""
    error_message = "Lambda source_code_hash must be set so Terraform detects code changes"
  }
}

run "valid_scheduler_expression" {
  command = plan

  assert {
    condition     = aws_scheduler_schedule.this.schedule_expression == "cron(0 0 ? * 5#2 *)"
    error_message = "Schedule expression must be cron(0 0 ? * 5#2 *) to trigger on the second Thursday of every month"
  }

  assert {
    condition     = aws_scheduler_schedule.this.flexible_time_window[0].mode == "OFF"
    error_message = "Flexible time window must be OFF to ensure the schedule fires at the exact cron time"
  }
}

run "valid_scheduler_target" {
  command = apply

  override_resource {
    target = aws_iam_role.lambda_execution_role
    values = {
      id   = "ingestion-service"
      arn  = "arn:aws:iam::000000000000:role/ingestion-service"
      name = "ingestion-service"
    }
  }

  override_resource {
    target = aws_iam_role_policy_attachment.lambda_policy
    values = {}
  }

  override_resource {
    target = aws_iam_role_policy.lambda_to_s3
    values = {
      id = "ingestion-service:lambda_to_s3"
    }
  }

  override_resource {
    target = aws_iam_role_policy.lambda_to_dlq
    values = {
      id = "ingestion-service:lambda_to_dlq"
    }
  }

  override_resource {
    target = aws_sqs_queue.dlq
    values = {
      arn = "arn:aws:sqs:eu-central-1:000000000000:development-ingestion-service-dlq"
    }
  }

  override_resource {
    target = aws_kms_key.log_group
    values = {
      id  = "00000000-0000-0000-0000-000000000000"
      arn = "arn:aws:kms:eu-central-1:000000000000:key/00000000-0000-0000-0000-000000000000"
    }
  }

  override_resource {
    target = aws_cloudwatch_log_group.this
    values = {}
  }

  override_resource {
    target = aws_lambda_function.this
    values = {
      arn = "arn:aws:lambda:eu-central-1:000000000000:function:development-ingestion-service"
    }
  }

  override_resource {
    target = aws_iam_role.scheduler_execution_role
    values = {
      id   = "ingestion-service-scheduler"
      arn  = "arn:aws:iam::000000000000:role/ingestion-service-scheduler"
      name = "ingestion-service-scheduler"
    }
  }

  override_resource {
    target = aws_iam_role_policy.scheduler_to_lambda
    values = {
      id = "ingestion-service-scheduler:scheduler_to_lambda"
    }
  }

  assert {
    condition     = aws_scheduler_schedule.this.target[0].arn == "arn:aws:lambda:eu-central-1:000000000000:function:development-ingestion-service"
    error_message = "EventBridge Scheduler target must be the ingestion Lambda function"
  }

  assert {
    condition     = aws_scheduler_schedule.this.target[0].role_arn == "arn:aws:iam::000000000000:role/ingestion-service-scheduler"
    error_message = "EventBridge Scheduler target must use the scheduler execution role"
  }
}

run "valid_scheduler_role" {
  command = plan

  override_resource {
    target = aws_lambda_function.this
    values = {
      arn = "arn:aws:lambda:eu-central-1:000000000000:function:development-ingestion-service"
    }
  }

  assert {
    condition     = jsondecode(aws_iam_role.scheduler_execution_role.assume_role_policy).Statement[0].Principal.Service == "scheduler.amazonaws.com"
    error_message = "Scheduler IAM role must trust scheduler.amazonaws.com"
  }

  assert {
    condition     = strcontains(aws_iam_role_policy.scheduler_to_lambda.policy, "lambda:InvokeFunction")
    error_message = "Scheduler IAM policy must grant lambda:InvokeFunction"
  }

  assert {
    condition     = strcontains(aws_iam_role_policy.scheduler_to_lambda.policy, "${var.environment}-ingestion-service")
    error_message = "Scheduler IAM policy must scope lambda:InvokeFunction to the ingestion Lambda function"
  }
}
