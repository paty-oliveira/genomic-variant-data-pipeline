terraform {
  required_version = ">= 1.7"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.0"
    }
  }
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
