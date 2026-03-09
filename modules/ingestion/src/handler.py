import ftplib
import logging
import os
from datetime import date
from io import BytesIO

import boto3
from botocore.exceptions import ClientError

logger = logging.getLogger()
logger.setLevel(logging.INFO)

FTP_HOST = os.environ["FTP_HOST"]
FTP_PATH = os.environ["FTP_PATH"]


def lambda_handler(event, context):
    current_date = date.today()
    year = current_date.strftime("%Y")
    month = current_date.strftime("%m")
    current_month_file = f"ClinVarVCVRelease_{year}-{month}.xml.gz"

    s3_client = boto3.client("s3")
    target_bucket = os.environ["TARGET_BUCKET"]
    s3_key = f"{FTP_PATH}{current_month_file}".lstrip("/")

    try:
        s3_client.head_object(Bucket=target_bucket, Key=s3_key)
        logger.info("File already exists in S3: %s, skipping download", s3_key)
        return {"statusCode": 200, "body": s3_key}
    except ClientError as e:
        if e.response["Error"]["Code"] != "404":
            raise

    try:
        with ftplib.FTP(FTP_HOST) as ftp:
            ftp.login()
            files = ftp.nlst(FTP_PATH)
            matched = next((file for file in files if current_month_file in file), None)

            if matched is None:
                logger.info("No file found for %s-%s, skipping", year, month)
                return {"statusCode": 200, "body": None}

            logger.info("Downloading %s", matched)
            buffer = BytesIO()
            ftp.retrbinary("RETR " + matched, buffer.write)
    except ftplib.all_errors as e:
        logger.error("FTP error: %s", e)
        raise

    try:
        buffer.seek(0)
        s3_client.upload_fileobj(buffer, target_bucket, s3_key)
        logger.info("Uploaded %s to %s", current_month_file, s3_key)
    except boto3.exceptions.S3UploadFailedError as e:
        logger.error("S3 upload failed for %s: %s", s3_key, e)
        raise

    return {"statusCode": 200, "body": s3_key}
