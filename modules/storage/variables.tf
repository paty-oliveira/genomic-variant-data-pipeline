variable "environment" {
  description = "Environment name."
  type        = string
}

variable "bucket_names" {
  description = "List of bucket names to be created."
  type        = set(string)
}

variable "buckets_versioned" {
  description = "List of bucket names to be versioned."
  type        = set(string)
}

variable "buckets_eventbridge_enabled" {
  description = "List of bucket names for which EventBridge notifications should be enabled."
  type        = set(string)
}
