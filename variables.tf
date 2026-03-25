variable "aws_access_key" {
  description = "AWS access key"
  type        = string
}

variable "aws_secret_key" {
  description = "AWS secret key"
  type        = string
}

variable "aws_region" {
  description = "AWS region"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "aws_endpoint_url" {
  description = "AWS service endpoint"
  type        = string
}

variable "aws_skip_validation" {
  description = "Flag about skiping AWS validation"
  type        = bool
  default     = true
}

variable "enable_processing" {
  description = "Whether to deploy the Glue processing infrastructure. Disabled in dev (not supported by LocalStack free tier)."
  type        = bool
  default     = false
}

variable "enable_analytics" {
  description = "Whether to deploy the Athena analytics infrastructure. Disabled in dev (not supported by LocalStack free tier)."
  type        = bool
  default     = false
}
