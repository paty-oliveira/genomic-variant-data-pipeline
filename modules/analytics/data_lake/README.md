# data_lake

Provisions Amazon Athena resources to query Apache Iceberg tables stored in S3 and registered in the AWS Glue Data Catalog.

## Overview

Athena reads Iceberg tables written by the processing module directly from S3, using the Glue Data Catalog as the metastore. Query results are stored in a dedicated S3 bucket.

```
Iceberg tables (S3 transformed bucket / Glue Data Catalog)
  → Athena workgroup
    → Query results (S3 athena results bucket)
```

## Resources

| Resource | Description |
|----------|-------------|
| `aws_athena_workgroup` | Athena workgroup with engine v3 and enforced result location |
| `aws_iam_role` | Execution role trusted by Athena |
| `aws_iam_role_policy.athena_s3_access` | Read access on transformed bucket; read/write on results bucket |
| `aws_iam_role_policy.athena_glue_access` | Read access on the Glue Data Catalog for the configured database |

## Variables

| Name | Description |
|------|-------------|
| `environment` | Environment name (e.g. `development`, `production`) |
| `athena_results_bucket` | S3 bucket for Athena query results |
| `transformed_bucket` | S3 bucket with Iceberg table data (read-only) |
| `glue_database_name` | Glue database name where Iceberg tables are registered |
