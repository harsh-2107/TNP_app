#Abhi iss module ko kuch nahi pata bas saare credentials env variables se aayenge -ahrsh jaiswal!


import boto3
from botocore.config import Config as BotoConfig
from botocore.exceptions import ClientError

from app.core.config import Settings
from app.core.exceptions import R2OperationFailed
from app.core.logging import get_logger

logger = get_logger(__name__)


class R2Client:
    #S3 compatibel client hai yahaan

    

    def __init__(self, settings: Settings) -> None:
        self._bucket = settings.R2_BUCKET_NAME
        self._client = boto3.client(
            "s3",
            endpoint_url=settings.r2_endpoint_url,
            aws_access_key_id=settings.R2_ACCESS_KEY_ID,
            aws_secret_access_key=settings.R2_SECRET_ACCESS_KEY,
            config=BotoConfig(
                signature_version="s3v4",
                s3={"addressing_style": "path"},
            ),
            region_name="auto",
        )

    def generate_presigned_put_url(
        self, object_key: str, content_type: str, expiry: int
    ) -> str:
        #Put url design

       
        try:
            url = self._client.generate_presigned_url(
                ClientMethod="put_object",
                Params={
                    "Bucket": self._bucket,
                    "Key": object_key,
                    "ContentType": content_type,
                },
                ExpiresIn=expiry,
            )
            logger.info(
                "Generated presigned PUT URL for key=%s expiry=%ds",
                object_key,
                expiry,
            )
            return url
        except ClientError as exc:
            logger.error(
                "Failed to generate presigned PUT URL for key=%s: %s",
                object_key,
                exc,
            )
            raise R2OperationFailed(
                detail="Failed to generate upload URL."
            ) from exc

    def generate_presigned_get_url(
        self, object_key: str, expiry: int
    ) -> str:
        #Geturl design
        try:
            url = self._client.generate_presigned_url(
                ClientMethod="get_object",
                Params={
                    "Bucket": self._bucket,
                    "Key": object_key,
                },
                ExpiresIn=expiry,
            )
            logger.info(
                "Generated presigned GET URL for key=%s expiry=%ds",
                object_key,
                expiry,
            )
            return url
        except ClientError as exc:
            logger.error(
                "Failed to generate presigned GET URL for key=%s: %s",
                object_key,
                exc,
            )
            raise R2OperationFailed(
                detail="Failed to generate download URL."
            ) from exc

    def head_object(self, object_key: str) -> dict:
        #metadata leta hai after verification of an object
        try:
            response = self._client.head_object(
                Bucket=self._bucket,
                Key=object_key,
            )
            result = {
                "ContentLength": response["ContentLength"],
                "ContentType": response["ContentType"],
            }
            logger.info(
                "HEAD object key=%s size=%d type=%s",
                object_key,
                result["ContentLength"],
                result["ContentType"],
            )
            return result
        except ClientError as exc:
            error_code = exc.response.get("Error", {}).get("Code", "")
            if error_code in ("404", "NoSuchKey"):
                logger.warning(
                    "HEAD object not found: key=%s", object_key
                )
                raise R2OperationFailed(
                    detail="Uploaded file not found in storage."
                ) from exc
            logger.error(
                "HEAD object failed for key=%s: %s", object_key, exc
            )
            raise R2OperationFailed(
                detail="Failed to verify uploaded file."
            ) from exc

    def delete_object(self, object_key: str) -> None:
        #Object delete from R2

        
        try:
            self._client.delete_object(
                Bucket=self._bucket,
                Key=object_key,
            )
            logger.info("Deleted object key=%s", object_key)
        except ClientError as exc:
            logger.error(
                "Failed to delete object key=%s: %s", object_key, exc
            )
            raise R2OperationFailed(
                detail="Failed to delete file from storage."
            ) from exc

    def copy_object(self, source_key: str, dest_key: str) -> None:
        #Copy an object from same bucket
        try:
            self._client.copy_object(
                Bucket=self._bucket,
                CopySource={'Bucket': self._bucket, 'Key': source_key},
                Key=dest_key,
            )
            logger.info("Copied object key=%s to key=%s", source_key, dest_key)
        except ClientError as exc:
            logger.error(
                "Failed to copy object key=%s to key=%s: %s", source_key, dest_key, exc
            )
            raise R2OperationFailed(
                detail="Failed to finalize file upload."
            ) from exc

    def read_object_bytes(self, object_key: str, length: int) -> bytes:
        #reads the first 'length' bytes of an object
        try:
            response = self._client.get_object(
                Bucket=self._bucket,
                Key=object_key,
                Range=f"bytes=0-{length - 1}",
            )
            return response["Body"].read()
        except ClientError as exc:
            logger.error(
                "Failed to read bytes from object key=%s: %s", object_key, exc
            )
            raise R2OperationFailed(
                detail="Failed to validate file contents."
            ) from exc
