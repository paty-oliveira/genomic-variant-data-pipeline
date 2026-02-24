terraform {
  source = "${get_repo_root()}//"
}

generate "cloud" {
  path      = "cloud.tf"
  if_exists = "overwrite"
  contents  = <<EOF
terraform {
  cloud {
    organization = "paty-training"
    workspaces {
      name = "genomic-variant-production"
    }
  }
}
EOF
}

inputs = {
  environment         = "prod"
  aws_skip_validation = false
}
