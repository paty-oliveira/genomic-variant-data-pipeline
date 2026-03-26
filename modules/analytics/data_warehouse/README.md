# data_warehouse

## Usage with dbt

Configure `dbt-athena-community` to use the workgroup provisioned by the `data_lake` submodule:

```yaml
# profiles.yml
genomic_pipeline:
  target: dev
  outputs:
    dev:
      type: athena
      region_name: <aws_region>
      s3_staging_dir: s3://<athena_results_bucket>/query-results/
      s3_data_dir: s3://<transformed_bucket>/dbt/
      database: <glue_database_name>
      schema: genomic_variants
      work_group: <environment>-analytics-service
      table_type: iceberg
      threads: 4
```
