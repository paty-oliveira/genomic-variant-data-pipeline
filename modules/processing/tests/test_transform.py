import sys
from unittest.mock import MagicMock

import pytest

# Mock Glue and PySpark before importing transform — these are only available in the Glue runtime
_mock_utils = MagicMock()
_mock_utils.getResolvedOptions.return_value = {
    "WORKFLOW_NAME": "test-workflow",
    "WORKFLOW_RUN_ID": "run-001",
    "bucket_name": "test-raw-bucket",
    "object_key": "pub/clinvar/xml/ClinVarVCVRelease_2026-03.xml.gz",
    "event_time": "2026-03-01T00:00:00Z",
    "transformed_bucket": "test-transformed-bucket",
}

sys.modules.setdefault("awsglue", MagicMock())
sys.modules.setdefault("awsglue.transforms", MagicMock())
sys.modules.setdefault("awsglue.utils", _mock_utils)
sys.modules.setdefault("awsglue.context", MagicMock())
sys.modules.setdefault("pyspark", MagicMock())
sys.modules.setdefault("pyspark.context", MagicMock())

import modules.processing.scripts.transform as transform

_ARGS = _mock_utils.getResolvedOptions.return_value


@pytest.fixture
def spark_session():
    return sys.modules["awsglue.context"].GlueContext.return_value.spark_session


@pytest.fixture(autouse=True)
def reset_mocks(spark_session):
    spark_session.reset_mock()
    yield


class TestXMLReading:
    def test_reads_xml_using_spark_xml_format(self, spark_session):
        # The Glue job must use the spark-xml library to parse the ClinVar VCV file.
        transform.main()

        spark_session.read.format.assert_called_once_with("com.databricks.spark.xml")

    def test_reads_xml_with_variation_archive_row_tag(self, spark_session):
        # Each top-level VariationArchive element must be parsed as a single row.
        transform.main()

        options_call = spark_session.read.format.return_value.options.call_args
        assert options_call.kwargs.get("rowTag") == "VariationArchive"

    def test_reads_xml_with_gzip_compression(self, spark_session):
        # The monthly ClinVar release file is gzip-compressed.
        transform.main()

        options_call = spark_session.read.format.return_value.options.call_args
        assert options_call.kwargs.get("compression") == "gzip"

    def test_loads_file_from_correct_s3_path(self, spark_session):
        # The job must load the exact S3 object that triggered the workflow.
        transform.main()

        expected_path = f"s3://{_ARGS['bucket_name']}/{_ARGS['object_key']}"
        spark_session.read.format.return_value.options.return_value.load.assert_called_once_with(
            expected_path
        )


class TestDataFiltering:
    def test_filters_out_included_records(self, spark_session):
        # IncludedRecord rows have no ClassifiedRecord and must be excluded before field extraction.
        transform.main()

        xml_df = spark_session.read.format.return_value.options.return_value.load.return_value
        xml_df.filter.assert_called_once_with("_RecordType = 'classified'")


class TestIcebergConfiguration:
    def test_sets_warehouse_to_transformed_bucket(self, spark_session):
        # Iceberg table data must be stored in the transformed bucket, not the raw bucket.
        transform.main()

        spark_session.conf.set.assert_any_call(
            "spark.sql.catalog.glue_catalog.warehouse",
            f"s3://{_ARGS['transformed_bucket']}/warehouse/",
        )

    def test_sets_glue_catalog_implementation(self, spark_session):
        # The Glue Data Catalog must be registered as the Iceberg catalog.
        transform.main()

        spark_session.conf.set.assert_any_call(
            "spark.sql.catalog.glue_catalog",
            "org.apache.iceberg.aws.glue.GlueCatalog",
        )

    def test_sets_s3_file_io_implementation(self, spark_session):
        # Iceberg must use S3FileIO to read and write table files on S3.
        transform.main()

        spark_session.conf.set.assert_any_call(
            "spark.sql.catalog.glue_catalog.io-impl",
            "org.apache.iceberg.aws.s3.S3FileIO",
        )


class TestIcebergWrite:
    def test_creates_table_if_not_exists(self, spark_session):
        # The job must be idempotent — the table is created on first run and reused on subsequent runs.
        transform.main()

        first_sql_call = spark_session.sql.call_args_list[0][0][0]
        assert "CREATE TABLE IF NOT EXISTS" in first_sql_call

    def test_creates_table_in_correct_catalog_and_database(self, spark_session):
        # The Iceberg table must live in the genomics database of the Glue catalog.
        transform.main()

        first_sql_call = spark_session.sql.call_args_list[0][0][0]
        assert "glue_catalog.genomics.clinvar_vcv" in first_sql_call

    def test_table_is_partitioned_by_classification(self, spark_session):
        # Partitioning by classification enables efficient filtering by Pathogenic/Benign/VUS.
        transform.main()

        first_sql_call = spark_session.sql.call_args_list[0][0][0]
        assert "PARTITIONED BY (classification)" in first_sql_call

    def test_registers_variants_as_incoming_view(self, spark_session):
        # Variants must be registered as a temporary view so the MERGE INTO can reference them.
        transform.main()

        variants_df = (
            spark_session.read.format.return_value
            .options.return_value
            .load.return_value
            .filter.return_value
            .selectExpr.return_value
        )
        variants_df.createOrReplace.assert_called_once_with("incoming")

    def test_upserts_into_iceberg_table(self, spark_session):
        # MERGE INTO ensures each variant is updated if changed and inserted if new, with no duplicates.
        transform.main()

        merge_sql = spark_session.sql.call_args_list[1][0][0]
        assert "MERGE INTO glue_catalog.genomics.clinvar_vcv" in merge_sql

    def test_merges_on_variation_id(self, spark_session):
        # variation_id is the stable primary key used to match source rows against the target table.
        transform.main()

        merge_sql = spark_session.sql.call_args_list[1][0][0]
        assert "target.variation_id = source.variation_id" in merge_sql

    def test_updates_only_when_source_is_newer(self, spark_session):
        # Existing variants are only overwritten when ClinVar has published a more recent update.
        transform.main()

        merge_sql = spark_session.sql.call_args_list[1][0][0]
        assert "source.date_last_updated > target.date_last_updated" in merge_sql
