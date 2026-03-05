# Validation of ClinVar ingestion Lambda resources

mock_provider "aws" {}

variables {
  environment   = "development"
  target_bucket = "development-clinvar-raw"
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
    condition     = strcontains(aws_iam_role_policy.lambda_to_s3.policy, "s3:PutObject")
    error_message = "Lambda IAM policy must grant s3:PutObject"
  }

  assert {
    condition     = strcontains(aws_iam_role_policy.lambda_to_s3.policy, "development-clinvar-raw")
    error_message = "Lambda IAM policy must scope s3:PutObject to the target bucket"
  }
}


# run "valid_lambda_function" {
#   command = plan

#   assert {
#     condition     = aws_lambda_function.this.function_name == "development-ingestion-service"
#     error_message = "Lambda function name must follow {environment}-ingestion-service convention"
#   }

#   assert {
#     condition     = aws_lambda_function.this.runtime == "python3.12"
#     error_message = "Lambda runtime must be python3.12"
#   }

#   assert {
#     condition     = aws_lambda_function.this.timeout == 900
#     error_message = "Lambda timeout must be 900 seconds (15 minutes max)"
#   }

#   assert {
#     condition     = aws_lambda_function.this.environment[0].variables["TARGET_BUCKET"] == "development-clinvar-raw"
#     error_message = "Lambda must receive TARGET_BUCKET environment variable"
#   }
# }

# run "valid_schedule_expression" {
#   command = plan

#   assert {
#     condition     = aws_cloudwatch_event_rule.this.schedule_expression == "rate(7 days)"
#     error_message = "EventBridge schedule expression does not match expected"
#   }
# }

# run "valid_lambda_permission_principal" {
#   command = plan

#   assert {
#     condition     = aws_lambda_permission.eventbridge.principal == "events.amazonaws.com"
#     error_message = "Lambda permission must allow EventBridge (events.amazonaws.com) to invoke the function"
#   }
# }
