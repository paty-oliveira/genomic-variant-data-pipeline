import os
from datetime import date
from unittest.mock import MagicMock, patch

import boto3
import pytest
from botocore.exceptions import ClientError
from moto import mock_aws

from modules.ingestion.src.handler import FTP_HOST, FTP_PATH, lambda_handler

CURRENT_MONTH = date(2026, 3, 5)


@pytest.fixture
def aws_credentials():
    os.environ["AWS_ACCESS_KEY_ID"] = "test"
    os.environ["AWS_SECRET_ACCESS_KEY"] = "test"
    os.environ["AWS_DEFAULT_REGION"] = "eu-central-1"
    os.environ["TARGET_BUCKET"] = "test-clinvar-raw"


@pytest.fixture
def s3_bucket(aws_credentials):
    with mock_aws():
        s3 = boto3.client("s3", region_name="eu-central-1")
        s3.create_bucket(
            Bucket="test-clinvar-raw",
            CreateBucketConfiguration={"LocationConstraint": "eu-central-1"},
        )
        yield s3


@pytest.fixture
def frozen_date():
    with patch("modules.ingestion.src.handler.date") as mock_date:
        mock_date.today.return_value = CURRENT_MONTH
        yield mock_date


@pytest.fixture
def ftp_mock():
    with patch("modules.ingestion.src.handler.ftplib.FTP") as mock_ftp_class:
        ftp_instance = MagicMock()
        mock_ftp_class.return_value.__enter__ = MagicMock(return_value=ftp_instance)
        mock_ftp_class.return_value.__exit__ = MagicMock(return_value=False)
        ftp_instance.nlst.return_value = [
            f"{FTP_PATH}ClinVarVCVRelease_2026-01.xml.gz",
            f"{FTP_PATH}ClinVarVCVRelease_2026-02.xml.gz",
            f"{FTP_PATH}ClinVarVCVRelease_2026-03.xml.gz",
        ]
        yield ftp_instance


@pytest.mark.usefixtures("frozen_date", "s3_bucket")
class TestFtpConnection:
    def test_connects_to_ncbi_ftp_host(self, ftp_mock):
        # The handler should open an FTP connection to the NCBI host.
        with patch("modules.ingestion.src.handler.ftplib.FTP") as mock_ftp_class:
            mock_ftp_class.return_value.__enter__ = MagicMock(return_value=ftp_mock)
            mock_ftp_class.return_value.__exit__ = MagicMock(return_value=False)
            ftp_mock.nlst.return_value = []

            lambda_handler({}, {})

            mock_ftp_class.assert_called_with(FTP_HOST)

    def test_logs_in_anonymously(self, ftp_mock):
        # The handler should authenticate with the FTP server using an anonymous login.
        lambda_handler({}, {})

        ftp_mock.login.assert_called_once()

    def test_lists_files_from_monthly_release_path(self, ftp_mock):
        # The handler should list files from the ClinVar monthly VCV release FTP path.
        lambda_handler({}, {})

        ftp_mock.nlst.assert_called_once_with(FTP_PATH)


@pytest.mark.usefixtures("ftp_mock", "frozen_date")
class TestS3Upload:
    def test_uploads_only_one_file(self, s3_bucket):
        # Only the single file matching the current month should be uploaded to S3.
        lambda_handler({}, {})

        objects = s3_bucket.list_objects_v2(Bucket="test-clinvar-raw")
        uploaded_keys = [obj["Key"] for obj in objects.get("Contents", [])]

        assert len(uploaded_keys) == 1

    def test_uploads_file_from_current_month(self, s3_bucket):
        # The uploaded file should be the release matching the current year-month.
        lambda_handler({}, {})

        objects = s3_bucket.list_objects_v2(Bucket="test-clinvar-raw")
        uploaded_keys = [obj["Key"] for obj in objects.get("Contents", [])]

        assert f"{FTP_PATH}ClinVarVCVRelease_2026-03.xml.gz".lstrip("/") in uploaded_keys

    def test_skips_files_from_previous_months(self, s3_bucket):
        # Releases from earlier months should not be uploaded to S3.
        lambda_handler({}, {})

        objects = s3_bucket.list_objects_v2(Bucket="test-clinvar-raw")
        uploaded_keys = [obj["Key"] for obj in objects.get("Contents", [])]

        assert not any("2026-01" in key or "2026-02" in key for key in uploaded_keys)

    def test_uploaded_file_mirrors_ftp_path(self, s3_bucket):
        # S3 keys should mirror the FTP server path structure.
        lambda_handler({}, {})

        objects = s3_bucket.list_objects_v2(Bucket="test-clinvar-raw")
        uploaded_keys = [obj["Key"] for obj in objects.get("Contents", [])]

        assert all(key.startswith(FTP_PATH.lstrip("/")) for key in uploaded_keys)

    def test_no_upload_when_no_file_for_current_month(self, ftp_mock, s3_bucket):
        # If the FTP listing contains no release for the current month, nothing should be uploaded.
        ftp_mock.nlst.return_value = [
            f"{FTP_PATH}ClinVarVCVRelease_2026-01.xml.gz",
            f"{FTP_PATH}ClinVarVCVRelease_2026-02.xml.gz",
        ]

        lambda_handler({}, {})

        objects = s3_bucket.list_objects_v2(Bucket="test-clinvar-raw")

        assert "Contents" not in objects


@pytest.mark.usefixtures("frozen_date")
class TestIdempotency:
    def test_skips_ftp_download_if_file_already_exists_in_s3(self, ftp_mock, s3_bucket):
        # If the S3 key for the current month already exists, the handler must not download
        # from FTP again. S3 is the source of truth for what has already been ingested.
        s3_bucket.put_object(
            Bucket="test-clinvar-raw",
            Key=f"{FTP_PATH}ClinVarVCVRelease_2026-03.xml.gz".lstrip("/"),
            Body=b"existing content",
        )

        lambda_handler({}, {})

        ftp_mock.retrbinary.assert_not_called()

    def test_skips_s3_upload_if_file_already_exists_in_s3(self, ftp_mock, s3_bucket):
        # If the file already exists in S3, no new object should be written —
        # the existing object must remain untouched.
        s3_bucket.put_object(
            Bucket="test-clinvar-raw",
            Key=f"{FTP_PATH}ClinVarVCVRelease_2026-03.xml.gz".lstrip("/"),
            Body=b"existing content",
        )

        lambda_handler({}, {})

        response = s3_bucket.get_object(
            Bucket="test-clinvar-raw",
            Key=f"{FTP_PATH}ClinVarVCVRelease_2026-03.xml.gz".lstrip("/"),
        )
        assert response["Body"].read() == b"existing content"

    def test_proceeds_with_download_if_file_not_in_s3(self, ftp_mock, s3_bucket):
        # If the S3 HeadObject check raises a 404, the handler should proceed
        # with the FTP download and upload the file.
        objects = s3_bucket.list_objects_v2(Bucket="test-clinvar-raw")
        assert "Contents" not in objects  # bucket is empty

        lambda_handler({}, {})

        ftp_mock.retrbinary.assert_called_once()

    def test_does_not_skip_when_a_different_month_file_exists(self, ftp_mock, s3_bucket):
        # A file from a previous month in S3 must not prevent the current month's download.
        s3_bucket.put_object(
            Bucket="test-clinvar-raw",
            Key=f"{FTP_PATH}ClinVarVCVRelease_2026-02.xml.gz".lstrip("/"),
            Body=b"previous month",
        )

        lambda_handler({}, {})

        ftp_mock.retrbinary.assert_called_once()
