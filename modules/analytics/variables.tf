variable "environment" {
  description = "Environment name."
  type        = string
}

variable "athena_results_bucket" {
  description = "Name of the S3 bucket for Athena query results"
  type        = string
}

variable "transformed_bucket" {
  description = "Name of the S3 bucket for Iceberg table storage"
  type        = string
}

variable "glue_database_name" {
  description = "Name of the Glue database with Iceberg tables"
  type        = string
}
