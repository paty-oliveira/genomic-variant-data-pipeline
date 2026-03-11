# Ingestion Module

Terraform module that provisions the infrastructure for the ClinVar ingestion service — a scheduled Lambda function that fetches monthly ClinVar snapshots from the NCBI FTP server and uploads them to S3.

## Architecture

```
EventBridge Scheduler  (cron: second Friday of every month)
        │
        ▼
AWS Lambda: ingestion-service
  │  runtime: python3.12  |  timeout: 15 min  |  tracing: X-Ray Active
  │
  ├── HeadObject → S3 Raw
  │        file already exists?  →  EXIT
  │
  ├── FTP download → ClinVarVCVRelease_YYYY-MM.xml.gz
  │
  ├── PutObject → S3 Raw
  │        ClinVarVCVRelease_YYYY-MM.xml.gz
  │
  └── on failure → SQS DLQ
```

Idempotency is handled at the S3 level. Before downloading, the Lambda performs a `HeadObject` check against the expected S3 key. If the file already exists, the function exits early with no re-download.

## Resources

| Resource | Name | Description |
|---|---|---|
| `aws_iam_role` | `ingestion-service` | Lambda execution role |
| `aws_iam_role_policy_attachment` | — | Attaches `AWSLambdaBasicExecutionRole` managed policy |
| `aws_iam_role_policy` | `lambda_to_s3` | Inline policy granting `s3:GetObject` and `s3:PutObject` to the target bucket |
| `aws_iam_role_policy` | `lambda_to_dlq` | Inline policy granting `sqs:SendMessage` to the DLQ |
| `aws_sqs_queue` | `{env}-ingestion-service-dlq` | Dead-letter queue for Lambda failures (14-day retention, SSE enabled) |
| `aws_kms_key` | `log_group` | KMS key for CloudWatch log group encryption |
| `aws_cloudwatch_log_group` | `/aws/lambda/{env}-ingestion-service` | Lambda log group (365-day retention, KMS-encrypted) |
| `aws_lambda_function` | `{env}-ingestion-service` | Lambda function with X-Ray tracing and DLQ configured |
| `aws_iam_role` | `ingestion-service-scheduler` | EventBridge Scheduler execution role |
| `aws_iam_role_policy` | `scheduler_to_lambda` | Inline policy granting `lambda:InvokeFunction` scoped to the ingestion Lambda |
| `aws_scheduler_schedule` | — | EventBridge Scheduler rule firing on the second Friday of every month |

## Inputs

| Name | Type | Description |
|---|---|---|
| `environment` | `string` | Deployment environment (e.g. `development`, `production`) |
| `target_bucket` | `string` | Name of the S3 bucket where downloaded files will be stored |
| `ftp_host` | `string` | FTP host domain (e.g. `ftp.ncbi.nlm.nih.gov`) |
| `ftp_path` | `string` | FTP folder path (e.g. `/pub/clinvar/xml/`) |

## Usage

```hcl
module "ingestion" {
  source = "../../modules/ingestion"

  environment   = "production"
  target_bucket = "production-clinvar-raw"
  ftp_host      = "ftp.ncbi.nlm.nih.gov"
  ftp_path      = "/pub/clinvar/xml/"
}
```

## Tests

Unit tests are written using the [Terraform native testing framework](https://developer.hashicorp.com/terraform/language/tests) and run against a mock provider — no AWS credentials required.

```bash
terraform test
```

| Test | Command | What it validates |
|---|---|---|
| `valid_lambda_iam_role_name` | plan | Role name and trust policy principal |
| `valid_lambda_basic_execution_policy` | plan | `AWSLambdaBasicExecutionRole` is attached |
| `valid_lambda_s3_policy` | plan | `s3:GetObject` and `s3:PutObject` are granted and scoped to the target bucket |
| `valid_kms_key_for_log_group` | plan | Key rotation, deletion window, and policy conditions |
| `valid_cloudwatch_log_group` | apply | Log group name, retention, and KMS key association |
| `valid_lambda_function` | plan | Function name, runtime, timeout, and environment variables |
| `valid_scheduler_expression` | plan | Cron expression and flexible time window mode |
| `valid_scheduler_target` | apply | Scheduler target ARN and role ARN |
| `valid_scheduler_role` | plan | Scheduler role trust policy and `lambda:InvokeFunction` permission |

## Security

- The KMS key policy grants CloudWatch Logs access only via an `ArnLike` condition on `kms:EncryptionContext:aws:logs:arn`, preventing cross-account log group usage of the key.
- The S3 policy is scoped to `arn:aws:s3:::${target_bucket}/*` — no wildcard bucket access.
- The scheduler policy is scoped to the specific ingestion Lambda ARN — no wildcard function access.
- Key rotation is enabled with a 7-day deletion window.
- Lambda failures are routed to an SQS dead-letter queue for observability.
- X-Ray Active Tracing is enabled on the Lambda function.
