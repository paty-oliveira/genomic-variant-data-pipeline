data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

data "archive_file" "this" {
  type        = "zip"
  source_file = "${path.module}/src/handler.py"
  output_path = "${path.module}/src/function.zip"
}
