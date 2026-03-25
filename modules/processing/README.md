# Processing Module

Transforms raw ClinVar VCV XML files from S3 into an Apache Iceberg table using AWS Glue 5.0 and the AWS Glue Data Catalog.

## Overview

When a new ClinVar XML file lands in the raw S3 bucket, an EventBridge rule detects the `Object Created` event and triggers a Glue workflow. The Glue job reads the compressed XML, extracts variant data, and writes it to an Iceberg table partitioned by germline classification.

```
S3 raw bucket (XML upload)
  → EventBridge rule (Object Created)
    → Glue workflow
      → Glue job (transform.py)
        → Iceberg table (S3 transformed bucket / Glue Data Catalog)
```

## Resources

| Resource | Description |
|----------|-------------|
| `aws_glue_job` | Glue 5.0 job running `transform.py` with Iceberg enabled |
| `aws_glue_workflow` | Orchestrates the Glue job execution |
| `aws_glue_trigger` | EVENT trigger that starts the workflow |
| `aws_glue_catalog_database` | `genomics` database in the Glue Data Catalog |
| `aws_cloudwatch_event_rule` | EventBridge rule watching for S3 Object Created events |
| `aws_cloudwatch_event_target` | Routes S3 events to the Glue workflow |
| `aws_iam_role` | Execution role trusted by EventBridge |
| `aws_iam_role_policy.glue_eventbridge_access` | Allows EventBridge to trigger the Glue workflow |
| `aws_iam_role_policy.glue_catalog_access` | Allows Glue job to create/update tables in the `genomics` database |
| `aws_iam_role_policy.glue_s3_access` | Read access on raw bucket; read/write/delete on transformed bucket |
| `aws_s3_object` | Uploads `transform.py` to the Glue scripts bucket |

## Iceberg Table

The Glue job creates the table on first run if it does not exist:

- **Catalog**: AWS Glue Data Catalog (`glue_catalog`)
- **Database**: `genomics`
- **Table**: `clinvar_vcv`
- **Partition**: `classification` (Pathogenic / Benign / Uncertain significance)
- **Warehouse**: `s3://<transformed_bucket>/warehouse/`

## Variables

| Name | Description |
|------|-------------|
| `environment` | Environment name (e.g. `development`, `production`) |
| `raw_bucket` | S3 bucket where ClinVar XML files are uploaded |
| `transformed_bucket` | S3 bucket for Iceberg table data and metadata |
| `glue_scripts_bucket` | S3 bucket where `transform.py` is stored |

## Transform Script

`scripts/transform.py` runs inside the Glue job and:

1. Reads the compressed XML file from S3 using `spark-xml` (`rowTag=VariationArchive`)
2. Filters out `IncludedRecord` rows (only processes `classified` records)
3. Extracts variant fields — VCV accession, gene info, GRCh38 coordinates, germline classification, and associated RCV/condition
4. Creates the Iceberg table if it does not exist
5. Appends the extracted records to `glue_catalog.genomics.clinvar_vcv`
