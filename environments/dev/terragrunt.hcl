terraform {
  source = "${get_repo_root()}//"
}

inputs = {
  environment                         = "dev"
  aws_access_key                      = "test"
  aws_secret_key                      = "test"
  aws_region                          = "eu-central-1"
  aws_endpoint_url                    = "http://localhost:4566"
  aws_ignore_configured_endpoint_urls = false
  aws_skip_validation                 = true
}
