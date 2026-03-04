module "storage" {
  source            = "./modules/storage"
  environment       = var.environment
  bucket_names      = toset(["clinvar-raw", "clinvar-transformed", "athena-results", "glue-scripts"])
  buckets_versioned = toset(["clinvar-raw"])
}
