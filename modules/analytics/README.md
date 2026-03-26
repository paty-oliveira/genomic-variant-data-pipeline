# Analytics Module

Provisions analytics infrastructure for querying genomic variant data. Organised into abstraction layers, each represented as a submodule.

## Overview

```
modules/analytics/
├── data_lake/        ← Athena + IAM for querying Iceberg tables via Glue Data Catalog
└── data_warehouse/   ← dbt configuration for transforming and modelling genomic variant data
```

## Submodules

| Submodule | Description |
|-----------|-------------|
| [`data_lake`](data_lake/README.md) | Athena workgroup and IAM roles for querying Apache Iceberg tables stored in S3 |
| [`data_warehouse`](data_warehouse/README.md) | dbt configuration for transforming and modelling genomic variant data |
