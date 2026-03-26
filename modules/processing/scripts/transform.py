import sys
from awsglue.transforms import *
from awsglue.utils import getResolvedOptions
from pyspark.context import SparkContext
from awsglue.context import GlueContext

args = getResolvedOptions(sys.argv, ['WORKFLOW_NAME', 'WORKFLOW_RUN_ID', 'bucket_name', 'object_key', 'event_time', 'transformed_bucket'])
bucket_name = args['bucket_name']
object_key = args['object_key']
transformed_bucket = args['transformed_bucket']

spark_context = SparkContext()
glue_context = GlueContext()
spark_session = glue_context.spark_session

s3_file_path = f"s3://{bucket_name}/{object_key}"

def main():
    xml_df = spark_session \
        .read \
        .format('com.databricks.spark.xml') \
        .options(rowTag='VariationArchive', compression='gzip') \
        .load(s3_file_path)

    variants_df = xml_df \
        .filter("_RecordType = 'classified'") \
        .selectExpr(
            "_VariationID AS variation_id",
            "_VariationName AS variation_name",
            "_VariationType AS variation_type",
            "_Accession AS vcv_accession",
            "_Version AS vcv_version",
            "_RecordType AS record_type",
            "_NumberOfSubmissions AS num_submissions",
            "_NumberOfSubmitters AS num_submitters",
            "CAST(_DateCreated AS DATE) AS date_created",
            "CAST(_DateLastUpdated AS DATE) AS date_last_updated",
            "CAST(_MostRecentSubmission AS DATE) AS most_recent_submission",
            "RecordStatus AS record_status",
            "ClassifiedRecord.SimpleAllele._AlleleID AS allele_id",
            "ClassifiedRecord.SimpleAllele.Name AS preferred_name",
            "ClassifiedRecord.SimpleAllele.CanonicalSPDI AS canonical_spdi",
            "ClassifiedRecord.SimpleAllele.ProteinChange AS protein_change",
            "ClassifiedRecord.SimpleAllele.GeneList.Gene[0]._Symbol AS gene_symbol",
            "ClassifiedRecord.SimpleAllele.GeneList.Gene[0]._GeneID AS gene_id",
            "ClassifiedRecord.SimpleAllele.GeneList.Gene[0]._HGNC_ID AS hgnc_id",
            "ClassifiedRecord.SimpleAllele.GeneList.Gene[0]._RelationshipType AS gene_relationship",
            "FILTER(ClassifiedRecord.SimpleAllele.Location.SequenceLocation, x -> x._Assembly = 'GRCh38')[0]._Chr AS chromosome",
            "FILTER(ClassifiedRecord.SimpleAllele.Location.SequenceLocation, x -> x._Assembly = 'GRCh38')[0]._positionVCF AS position_vcf",
            "FILTER(ClassifiedRecord.SimpleAllele.Location.SequenceLocation, x -> x._Assembly = 'GRCh38')[0]._referenceAlleleVCF AS ref_allele",
            "FILTER(ClassifiedRecord.SimpleAllele.Location.SequenceLocation, x -> x._Assembly = 'GRCh38')[0]._alternateAlleleVCF AS alt_allele",
            "FILTER(ClassifiedRecord.SimpleAllele.Location.SequenceLocation, x -> x._Assembly = 'GRCh38')[0]._start AS start_pos",
            "FILTER(ClassifiedRecord.SimpleAllele.Location.SequenceLocation, x -> x._Assembly = 'GRCh38')[0]._stop AS stop_pos",
            "ClassifiedRecord.Classifications.GermlineClassification.Description AS classification",
            "ClassifiedRecord.Classifications.GermlineClassification.ReviewStatus AS review_status",
            "CAST(ClassifiedRecord.Classifications.GermlineClassification._DateLastEvaluated AS DATE) AS classification_date",
            "ClassifiedRecord.RCVList.RCVAccession[0]._Accession AS rcv_accession",
            "ClassifiedRecord.RCVList.RCVAccession[0].ClassifiedConditionList.ClassifiedCondition[0] AS condition_name"
        )

    spark_session.conf.set("spark.sql.catalog.glue_catalog", "org.apache.iceberg.aws.glue.GlueCatalog")
    spark_session.conf.set("spark.sql.catalog.glue_catalog.warehouse", f"s3://{transformed_bucket}/warehouse/")
    spark_session.conf.set("spark.sql.catalog.glue_catalog.io-impl", "org.apache.iceberg.aws.s3.S3FileIO")
    spark_session.conf.set("spark.sql.defaultCatalog", "glue_catalog")

    spark_session.sql("""
        CREATE TABLE IF NOT EXISTS glue_catalog.genomics.clinvar_vcv (
            variation_id            BIGINT,
            variation_name          STRING,
            variation_type          STRING,
            vcv_accession           STRING,
            vcv_version             INT,
            record_type             STRING,
            record_status           STRING,
            num_submissions         INT,
            num_submitters          INT,
            date_created            DATE,
            date_last_updated       DATE,
            most_recent_submission  DATE,
            allele_id               BIGINT,
            preferred_name          STRING,
            canonical_spdi          STRING,
            protein_change          STRING,
            gene_symbol             STRING,
            gene_id                 BIGINT,
            hgnc_id                 STRING,
            gene_relationship       STRING,
            chromosome              STRING,
            position_vcf            BIGINT,
            ref_allele              STRING,
            alt_allele              STRING,
            start_pos               BIGINT,
            stop_pos                BIGINT,
            review_status           STRING,
            classification          STRING,
            classification_date     DATE,
            rcv_accession           STRING,
            condition_name          STRING
        )
        USING iceberg
        PARTITIONED BY (classification)
    """)

    # Creates a virtual table in Spark SQL catalog
    # Spark SQL engine can see it as incoming table
    variants_df.createOrReplace("incoming")
    spark_session.sql("""
        MERGE INTO glue_catalog.genomics.clinvar_vcv AS target
        USING incoming AS source
        ON target.variation_id = source.variation_id
        WHEN MATCHED AND source.date_last_updated > target.date_last_updated
            THEN UPDATE SET *
        WHEN NOT MATCHED
            THEN INSERT *
    """)

main()
