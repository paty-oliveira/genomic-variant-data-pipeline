# Validation of Athena analytics module resources

mock_provider "aws" {}

variables {
  environment           = "development"
  athena_results_bucket = "development-clinvar-athena-results"
  transformed_bucket    = "development-clinvar-transformed"
  glue_database_name    = "genomics"
}

run "valid_athena_workgroup_name" {
  command = plan

  assert {
    condition     = aws_athena_workgroup.this.name == "${var.environment}-data-lake-service"
    error_message = "Athena workgroup name must follow {environment}-data-lake-service convention"
  }
}

run "valid_athena_workgroup_engine_version" {
  command = plan

  assert {
    condition     = aws_athena_workgroup.this.configuration[0].engine_version[0].selected_engine_version == "Athena engine version 3"
    error_message = "Athena workgroup must use engine version 3"
  }
}

run "valid_athena_workgroup_output_location" {
  command = plan

  assert {
    condition     = aws_athena_workgroup.this.configuration[0].result_configuration[0].output_location == "s3://${var.athena_results_bucket}/query-results/"
    error_message = "Athena workgroup output location must point to the athena results bucket"
  }
}

run "valid_athena_execution_role_trust_policy" {
  command = plan

  assert {
    condition     = jsondecode(aws_iam_role.athena_execution_role.assume_role_policy).Statement[0].Principal.Service == "athena.amazonaws.com"
    error_message = "Athena IAM role must trust athena.amazonaws.com"
  }
}

run "valid_athena_s3_policy_transformed_bucket" {
  command = plan

  assert {
    condition     = strcontains(aws_iam_role_policy.athena_s3_access.policy, "s3:GetObject")
    error_message = "Athena S3 policy must grant s3:GetObject"
  }

  assert {
    condition     = strcontains(aws_iam_role_policy.athena_s3_access.policy, "s3:ListBucket")
    error_message = "Athena S3 policy must grant s3:ListBucket"
  }

  assert {
    condition     = strcontains(aws_iam_role_policy.athena_s3_access.policy, var.transformed_bucket)
    error_message = "Athena S3 policy must be scoped to the transformed bucket"
  }
}

run "valid_athena_s3_policy_results_bucket" {
  command = plan

  assert {
    condition     = strcontains(aws_iam_role_policy.athena_s3_access.policy, "s3:PutObject")
    error_message = "Athena S3 policy must grant s3:PutObject on the results bucket"
  }

  assert {
    condition     = strcontains(aws_iam_role_policy.athena_s3_access.policy, var.athena_results_bucket)
    error_message = "Athena S3 policy must be scoped to the athena results bucket"
  }
}

run "valid_athena_glue_access_policy" {
  command = plan

  assert {
    condition     = strcontains(aws_iam_role_policy.athena_glue_access.policy, "glue:GetDatabase")
    error_message = "Athena Glue policy must grant glue:GetDatabase"
  }

  assert {
    condition     = strcontains(aws_iam_role_policy.athena_glue_access.policy, "glue:GetTable")
    error_message = "Athena Glue policy must grant glue:GetTable"
  }

  assert {
    condition     = strcontains(aws_iam_role_policy.athena_glue_access.policy, "glue:GetPartitions")
    error_message = "Athena Glue policy must grant glue:GetPartitions"
  }

  assert {
    condition     = strcontains(aws_iam_role_policy.athena_glue_access.policy, var.glue_database_name)
    error_message = "Athena Glue policy must be scoped to the configured database"
  }
}
