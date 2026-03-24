variable "environment" {
  description = "Deployment environment (e.g. development, production)"
  type        = string
}


variable "target_bucket" {
  description = "Name of the S3 bucket where downloaded files will be stored"
  type        = string
}

variable "ftp_host" {
  description = "FTP host domain"
  type        = string
}

variable "ftp_path" {
  description = "FTP folder path"
  type        = string
}
