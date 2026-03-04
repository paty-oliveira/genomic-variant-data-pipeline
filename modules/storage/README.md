# Storage Module

Terraform module that provisions S3 buckets for the genomic variant data pipeline.

## Resources

| Name | Type |
|------|------|
| `aws_s3_bucket` | resource |
| `aws_s3_bucket_versioning` | resource |
| `aws_s3_bucket_public_access_block` | resource |

All buckets are created with public access fully blocked. Versioning can be selectively enabled per bucket.

Bucket names follow the pattern: `{environment}-{name}`.

## Variables

| Name | Type | Description |
|------|------|-------------|
| `environment` | `string` | Environment name prefix (e.g. `dev`, `prod`) |
| `bucket_names` | `set(string)` | Set of bucket names to create |
| `buckets_versioned` | `set(string)` | Subset of bucket names to enable versioning on |

## Usage

```hcl
module "storage" {
  source = "./modules/storage"

  environment       = "dev"
  bucket_names      = ["raw", "processed"]
  buckets_versioned = ["raw"]
}
```

## Requirements

| Name | Version |
|------|---------|
| Terraform | >= 1.0 |
| AWS provider | >= 6.0 |
