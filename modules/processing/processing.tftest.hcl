# Validation of ClinVar processing EventBridge rule resources

mock_provider "aws" {}

variables {
  environment         = "development"
  raw_bucket          = "development-clinvar-raw"
  glue_scripts_bucket = "development-clinvar-glue-scripts"
  transformed_bucket  = "development-clinvar-transformed"
  glue_database_name  = "genomics"
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
      arn  = "arn:aws:glue:eu-central-1:000000000000:job/development-processing-service-job"
      name = "development-processing-service-job"
    }
  }

  override_resource {
    target          = aws_glue_workflow.this
    override_during = plan
    values = {
      arn  = "arn:aws:glue:eu-central-1:000000000000:workflow/development-processing-service-workflow"
      name = "development-processing-service-workflow"
    }
  }

  override_resource {
    target          = aws_glue_trigger.this
    override_during = plan
    values = {
      arn  = "arn:aws:glue:eu-central-1:000000000000:trigger/development-processing-service-trigger"
      name = "development-processing-service-trigger"
    }
  }

  override_resource {
    target          = aws_iam_role.glue_execution_role
    override_during = plan
    values = {
      id   = "processing-service-eventbridge"
      arn  = "arn:aws:iam::000000000000:role/processing-service-eventbridge"
      name = "processing-service-eventbridge"
    }
  }

  override_resource {
    target          = aws_iam_role_policy.glue_eventbridge_access
    override_during = plan
    values = {
      id = "processing-service-eventbridge:glue_eventbridge_access"
    }
  }

  assert {
    condition     = aws_cloudwatch_event_target.this.rule == aws_cloudwatch_event_rule.this.name
    error_message = "EventBridge target must be attached to the S3 object created rule"
  }

  assert {
    condition     = aws_cloudwatch_event_target.this.arn == "arn:aws:glue:eu-central-1:000000000000:workflow/development-processing-service-workflow"
    error_message = "EventBridge target ARN must point to the Glue workflow, not the job directly"
  }

  assert {
    condition     = aws_cloudwatch_event_target.this.role_arn == "arn:aws:iam::000000000000:role/processing-service-eventbridge"
    error_message = "EventBridge target must use the eventbridge execution role"
  }
}

run "valid_glue_workflow" {
  command = plan

  assert {
    condition     = aws_glue_workflow.this.name == "${var.environment}-processing-service-workflow"
    error_message = "Glue workflow name must follow {environment}-processing-service-workflow convention"
  }
}

run "valid_glue_trigger" {
  command = plan

  override_resource {
    target          = aws_glue_job.this
    override_during = plan
    values = {
      arn  = "arn:aws:glue:eu-central-1:000000000000:job/development-processing-service-job"
      name = "development-processing-service-job"
    }
  }

  assert {
    condition     = aws_glue_trigger.this.name == "${var.environment}-processing-service-trigger"
    error_message = "Glue trigger name must follow {environment}-processing-service-trigger convention"
  }

  assert {
    condition     = aws_glue_trigger.this.type == "EVENT"
    error_message = "Glue trigger must be ON_DEMAND so EventBridge controls execution timing"
  }

  assert {
    condition     = aws_glue_trigger.this.workflow_name == aws_glue_workflow.this.name
    error_message = "Glue trigger must belong to the processing workflow"
  }

  assert {
    condition     = aws_glue_trigger.this.actions[0].job_name == aws_glue_job.this.name
    error_message = "Glue trigger must invoke the processing Glue job"
  }
}

run "valid_eventbridge_role" {
  command = plan

  assert {
    condition     = jsondecode(aws_iam_role.glue_execution_role.assume_role_policy).Statement[0].Principal.Service == "events.amazonaws.com"
    error_message = "EventBridge IAM role must trust events.amazonaws.com"
  }
}

run "valid_eventbridge_policy" {
  command = plan

  override_resource {
    target          = aws_glue_job.this
    override_during = plan
    values = {
      arn  = "arn:aws:glue:eu-central-1:000000000000:job/development-processing-service-job"
      name = "development-processing-service-job"
    }
  }

  override_resource {
    target          = aws_glue_workflow.this
    override_during = plan
    values = {
      arn  = "arn:aws:glue:eu-central-1:000000000000:workflow/development-processing-service-workflow"
      name = "development-processing-service-workflow"
    }
  }

  override_resource {
    target          = aws_glue_trigger.this
    override_during = plan
    values = {
      arn  = "arn:aws:glue:eu-central-1:000000000000:trigger/development-processing-service-trigger"
      name = "development-processing-service-trigger"
    }
  }

  assert {
    condition     = strcontains(aws_iam_role_policy.glue_eventbridge_access.policy, "glue:notifyEvent")
    error_message = "EventBridge IAM policy must grant glue:notifyEvent to trigger the Glue workflow"
  }

  assert {
    condition     = strcontains(aws_iam_role_policy.glue_eventbridge_access.policy, "${var.environment}-processing-service-workflow")
    error_message = "EventBridge IAM policy must scope glue:notifyEvent to the processing Glue workflow"
  }
}


run "valid_glue_s3_policy" {
  command = plan

  assert {
    condition     = strcontains(aws_iam_role_policy.glue_s3_access.policy, "s3:GetObject")
    error_message = "Glue S3 policy must grant s3:GetObject"
  }

  assert {
    condition     = strcontains(aws_iam_role_policy.glue_s3_access.policy, "s3:PutObject")
    error_message = "Glue S3 policy must grant s3:PutObject"
  }

  assert {
    condition     = strcontains(aws_iam_role_policy.glue_s3_access.policy, "s3:ListBucket")
    error_message = "Glue S3 policy must grant s3:ListBucket"
  }

  assert {
    condition     = strcontains(aws_iam_role_policy.glue_s3_access.policy, var.raw_bucket)
    error_message = "Glue S3 policy must be scoped to the raw bucket"
  }

  assert {
    condition     = strcontains(aws_iam_role_policy.glue_s3_access.policy, var.transformed_bucket)
    error_message = "Glue S3 policy must be scoped to the transformed bucket"
  }

  assert {
    condition     = strcontains(aws_iam_role_policy.glue_s3_access.policy, "s3:DeleteObject")
    error_message = "Glue S3 policy must grant s3:DeleteObject on the transformed bucket for Iceberg compaction"
  }

}

run "valid_eventbridge_target_input_transformer" {
  command = plan

  override_resource {
    target = aws_glue_workflow.this
    values = {
      arn  = "arn:aws:glue:eu-central-1:000000000000:workflow/development-processing-service-workflow"
      name = "development-processing-service-workflow"
    }
  }

  override_resource {
    target = aws_iam_role.glue_execution_role
    values = {
      id   = "processing-service-eventbridge"
      arn  = "arn:aws:iam::000000000000:role/processing-service-eventbridge"
      name = "processing-service-eventbridge"
    }
  }

  assert {
    condition     = aws_cloudwatch_event_target.this.input_transformer[0].input_paths["bucket_name"] == "$.detail.bucket.name"
    error_message = "Input transformer must extract bucket name from the S3 event detail"
  }

  assert {
    condition     = aws_cloudwatch_event_target.this.input_transformer[0].input_paths["object_key"] == "$.detail.object.key"
    error_message = "Input transformer must extract object key from the S3 event detail"
  }

  assert {
    condition     = aws_cloudwatch_event_target.this.input_transformer[0].input_paths["event_time"] == "$.time"
    error_message = "Input transformer must extract event time from the EventBridge envelope"
  }

  assert {
    condition     = strcontains(aws_cloudwatch_event_target.this.input_transformer[0].input_template, "--bucket_name")
    error_message = "Input transformer template must map bucket_name as a Glue job argument"
  }

  assert {
    condition     = strcontains(aws_cloudwatch_event_target.this.input_transformer[0].input_template, "--object_key")
    error_message = "Input transformer template must map object_key as a Glue job argument"
  }

  assert {
    condition     = strcontains(aws_cloudwatch_event_target.this.input_transformer[0].input_template, "--event_time")
    error_message = "Input transformer template must map event_time as a Glue job argument"
  }
}

run "valid_glue_catalog_database" {
  command = plan

  assert {
    condition     = aws_glue_catalog_database.this.name == var.glue_database_name
    error_message = "Glue catalog database name must match the glue_database_name variable"
  }
}

run "valid_cloudwatch_log_group" {
  command = plan

  override_resource {
    target          = aws_kms_key.log_group
    override_during = plan
    values = {
      arn = "arn:aws:kms:us-east-1:123456789012:key/test-key-id"
    }
  }

  assert {
    condition     = aws_cloudwatch_log_group.this.name == "/aws/glue/${var.environment}-processing-service"
    error_message = "CloudWatch log group name must follow /aws/glue/{environment}-processing-service convention"
  }

  assert {
    condition     = aws_cloudwatch_log_group.this.retention_in_days == 365
    error_message = "CloudWatch log group retention must be set to 365 days"
  }

  assert {
    condition     = aws_cloudwatch_log_group.this.kms_key_id == aws_kms_key.log_group.arn
    error_message = "CloudWatch log group must be encrypted with the provisioned KMS key"
  }
}

run "valid_cloudwatch_kms_key" {
  command = plan

  assert {
    condition     = aws_kms_key.log_group.enable_key_rotation == true
    error_message = "KMS key for the log group must have key rotation enabled"
  }

  assert {
    condition     = aws_kms_key.log_group.deletion_window_in_days == 7
    error_message = "KMS key deletion window must be set to 7 days"
  }

  assert {
    condition     = can(regex("logs\\..+\\.amazonaws\\.com", aws_kms_key.log_group.policy))
    error_message = "KMS key policy must grant CloudWatch Logs service access to encrypt/decrypt"
  }
}

run "valid_glue_job_arguments" {
  command = plan

  assert {
    condition     = aws_glue_job.this.default_arguments["--datalake-formats"] == "iceberg"
    error_message = "Glue job must enable Iceberg via --datalake-formats"
  }

  assert {
    condition     = aws_glue_job.this.default_arguments["--transformed_bucket"] == var.transformed_bucket
    error_message = "Glue job must pass the transformed bucket as an argument"
  }

  assert {
    condition     = aws_glue_job.this.default_arguments["--enable-continuous-cloudwatch-log"] == "true"
    error_message = "Glue job must enable continuous CloudWatch logging"
  }

  assert {
    condition     = aws_glue_job.this.default_arguments["--enable-continuous-log-filter"] == "true"
    error_message = "Glue job must enable continuous log filter to suppress driver log noise"
  }

  assert {
    condition     = aws_glue_job.this.default_arguments["--continuous-log-logGroup"] == aws_cloudwatch_log_group.this.name
    error_message = "Glue job must send logs to the provisioned CloudWatch log group"
  }
}

run "valid_glue_catalog_access_policy" {
  command = plan

  assert {
    condition     = strcontains(aws_iam_role_policy.glue_catalog_access.policy, "glue:CreateTable")
    error_message = "Glue catalog policy must grant glue:CreateTable"
  }

  assert {
    condition     = strcontains(aws_iam_role_policy.glue_catalog_access.policy, "glue:GetTable")
    error_message = "Glue catalog policy must grant glue:GetTable"
  }

  assert {
    condition     = strcontains(aws_iam_role_policy.glue_catalog_access.policy, var.glue_database_name)
    error_message = "Glue catalog policy must be scoped to the configured database"
  }
}

run "valid_glue_job_script_to_s3" {
  command = plan

  assert {
    condition     = aws_s3_object.transform_script.bucket == var.glue_scripts_bucket
    error_message = "The AWS Glue script must be stored on the correct S3 bucket."
  }

  assert {
    condition     = strcontains(aws_s3_object.transform_script.key, "transform.py")
    error_message = "The S3 bucket must have the Python Glue script."
  }
}
