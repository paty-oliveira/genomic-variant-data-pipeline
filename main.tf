module "storage" {
  source            = "./modules/storage"
  environment       = var.environment
  bucket_names      = toset(["clinvar-raw", "clinvar-transformed", "clinvar-athena-results", "clinvar-glue-scripts"])
  buckets_versioned = toset(["clinvar-raw"])
}
