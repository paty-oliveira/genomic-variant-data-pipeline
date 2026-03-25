# genomic-variant-data-pipeline

A cloud-native, event-driven pipeline on AWS for ingesting, transforming, and querying ClinVar genomic variant data.

## Overview

This pipeline automates the monthly ingestion of [ClinVar VCV release files](https://ftp.ncbi.nlm.nih.gov/pub/clinvar/xml/) from NCBI, transforms the nested XML into a flattened [Apache Iceberg](https://iceberg.apache.org/) table, and makes it queryable via Amazon Athena.

```
NCBI FTP (ClinVar XML)
        │
        ▼ (Lambda — 2nd Friday monthly)
   S3: clinvar-raw
        │
        ▼ (EventBridge → Glue Workflow)
   S3: clinvar-transformed  (Iceberg, partitioned by classification)
        │
        ▼
   Amazon Athena
```

## Architecture

| Component | Service | Purpose |
|-----------|---------|---------|
| Ingestion | AWS Lambda (Python 3.12) | Downloads gzipped ClinVar XML from NCBI FTP and stores in S3 |
| Scheduling | EventBridge Scheduler | Triggers Lambda on the 2nd Friday of each month |
| Processing | AWS Glue (Spark, Glue 5.0) | Parses XML, flattens variant records, writes Iceberg table |
| Orchestration | EventBridge + Glue Workflow | S3 object creation triggers the Glue ETL job |
| Storage | Amazon S3 | Raw XML, transformed Iceberg data, Glue scripts, Athena results |
| Query | Amazon Athena (engine v3) | Ad-hoc SQL over the `genomics.clinvar_vcv` Iceberg table |
| Error handling | SQS Dead Letter Queue | Captures Lambda failures for retry/inspection |

### Iceberg Table: `glue_catalog.genomics.clinvar_vcv`

Fields extracted per variant record:

- **Variation**: ID, name, type, VCV accession + version
- **Alleles**: ID, SPDI notation, protein changes
- **Gene**: symbol, ID, HGNC ID, relationship type
- **Location**: chromosome, GRCh38 position, reference/alternate alleles
- **Classification**: status (Pathogenic / Benign / VUS), review status, date evaluated
- **Conditions**: disease mappings

The table is partitioned by `classification`.

## Infrastructure

Infrastructure is managed with **Terraform** and **Terragrunt**.

| Environment | Target | Notes |
|-------------|--------|-------|
| `dev` | LocalStack 4.3 | Runs locally via Docker Compose |
| `prod` | AWS Cloud | Managed via Terraform Cloud (`paty-training` org) |

### Local development

```bash
# Start LocalStack
docker compose up -d

# Deploy dev infrastructure
cd environments/dev
terragrunt apply
```

## CI/CD

GitHub Actions workflow (`.github/workflows/ci.yml`) runs on every push:

1. **build-and-test-infrastructure** — spins up LocalStack, applies dev Terraform, runs `terraform test` and `pytest`
2. **deploy-infrastructure** — applies prod Terraform via HCP Terraform API (runs only after job 1 passes)

## Python

- **Runtime**: Python 3.12, managed with [Poetry](https://python-poetry.org/)
- **Key dependencies**: `boto3`, `pre-commit`
- **Test dependencies**: `pytest`, `pytest-mock`, `moto[s3]`

```bash
poetry install
poetry run pytest
```

## Modules

```
modules/
├── storage/     # S3 buckets (raw, transformed, Athena results, Glue scripts)
├── ingestion/   # Lambda + EventBridge Scheduler + DLQ
├── processing/  # Glue job, workflow, EventBridge trigger, IAM
└── analytics/   # Athena workgroup + IAM
```
