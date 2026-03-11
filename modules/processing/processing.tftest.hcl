# Validation of ClinVar processing EventBridge rule resources

mock_provider "aws" {}

variables {
  environment         = "development"
  raw_bucket          = "development-clinvar-raw"
  glue_scripts_bucket = "development-clinvar-glue-scripts"
}


run "valid_eventbridge_rule_name" {
  command = plan

  assert {
    condition     = aws_cloudwatch_event_rule.this.name == "${var.environment}-processing-service-raw-object-created"
    error_message = "EventBridge rule name must follow {environment}-clinvar-raw-object-created convention"
  }

  assert {
    condition     = aws_cloudwatch_event_rule.this.state == "ENABLED"
    error_message = "EventBridge rule must be enabled"
  }
}

run "valid_eventbridge_event_pattern" {
  command = plan

  assert {
    condition     = strcontains(aws_cloudwatch_event_rule.this.event_pattern, "aws.s3")
    error_message = "EventBridge rule event pattern must match source aws.s3"
  }

  assert {
    condition     = strcontains(aws_cloudwatch_event_rule.this.event_pattern, "Object Created")
    error_message = "EventBridge rule event pattern must match detail-type Object Created"
  }

  assert {
    condition     = strcontains(aws_cloudwatch_event_rule.this.event_pattern, var.raw_bucket)
    error_message = "EventBridge rule event pattern must scope to the raw S3 bucket"
  }
}

run "valid_eventbridge_target" {
  command = plan

  override_resource {
    target          = aws_glue_job.this
    override_during = plan
    values = {
      arn  = "arn:aws:glue:eu-central-1:000000000000:job/development-processing-service"
      name = "development-processing-service"
    }
  }

  override_resource {
    target          = aws_iam_role.eventbridge_execution_role
    override_during = plan
    values = {
      id   = "processing-service-eventbridge"
      arn  = "arn:aws:iam::000000000000:role/processing-service-eventbridge"
      name = "processing-service-eventbridge"
    }
  }

  override_resource {
    target          = aws_iam_role_policy.eventbridge_to_glue
    override_during = plan
    values = {
      id = "processing-service-eventbridge:eventbridge_to_glue"
    }
  }

  assert {
    condition     = aws_cloudwatch_event_target.this.rule == aws_cloudwatch_event_rule.this.name
    error_message = "EventBridge target must be attached to the S3 object created rule"
  }

  assert {
    condition     = aws_cloudwatch_event_target.this.arn == "arn:aws:glue:eu-central-1:000000000000:job/development-processing-service"
    error_message = "EventBridge target ARN must point to the Glue job"
  }

  assert {
    condition     = aws_cloudwatch_event_target.this.role_arn == "arn:aws:iam::000000000000:role/processing-service-eventbridge"
    error_message = "EventBridge target must use the eventbridge execution role"
  }
}

run "valid_eventbridge_role" {
  command = plan

  assert {
    condition     = jsondecode(aws_iam_role.eventbridge_execution_role.assume_role_policy).Statement[0].Principal.Service == "events.amazonaws.com"
    error_message = "EventBridge IAM role must trust events.amazonaws.com"
  }
}

run "valid_eventbridge_policy" {
  command = plan

  override_resource {
    target          = aws_glue_job.this
    override_during = plan
    values = {
      arn  = "arn:aws:glue:eu-central-1:000000000000:job/development-processing-service"
      name = "development-processing-service"
    }
  }

  assert {
    condition     = strcontains(aws_iam_role_policy.eventbridge_to_glue.policy, "glue:StartJobRun")
    error_message = "EventBridge IAM policy must grant glue:StartJobRun"
  }

  assert {
    condition     = strcontains(aws_iam_role_policy.eventbridge_to_glue.policy, "${var.environment}-processing-service")
    error_message = "EventBridge IAM policy must scope glue:StartJobRun to the processing Glue job"
  }
}
