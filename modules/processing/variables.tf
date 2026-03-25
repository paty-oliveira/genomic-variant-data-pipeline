variable "environment" {
  description = "Environment name."
  type        = string
}

variable "raw_bucket" {
  description = "Name of the raw S3 bucket"
  type        = string
}


variable "glue_scripts_bucket" {
  description = "Name of the S3 bucket of Glue scripts"
  type        = string
}

variable "transformed_bucket" {
  description = "Name of the S3 bucket for Iceberg table storage"
  type        = string
}

variable "glue_database_name" {
  description = "Name of the Glue database to store Iceberg table"
  type        = string
}
