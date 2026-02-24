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

variable "aws_ignore_configured_endpoint_urls" {
  description = "Flag about AWS endopoint urls"
  type        = bool
  default     = true
}

variable "aws_skip_validation" {
  description = "Flag about skiping AWS validation"
  type    = bool
  default = true
}