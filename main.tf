module "storage" {
  source            = "./modules/storage"
  environment       = var.environment
  bucket_names      = toset(["clinvar-raw", "clinvar-transformed", "clinvar-athena-results", "clinvar-glue-scripts"])
  buckets_versioned = toset(["clinvar-raw"])
}

module "ingestion" {
  source        = "./modules/ingestion"
  environment   = var.environment
  target_bucket = "${var.environment}-clinvar-raw"
  ftp_host      = "ftp.ncbi.nlm.nih.gov"
  ftp_path      = "/pub/clinvar/xml/"
}
