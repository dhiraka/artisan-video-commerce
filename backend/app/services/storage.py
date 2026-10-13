import datetime
from google.cloud import storage
from app.config import settings


def get_storage_client() -> storage.Client:
    return storage.Client(project=settings.gcp_project_id)


def generate_upload_signed_url(object_key: str, content_type: str = "video/mp4") -> str:
    """Generate a v4 signed URL for direct client upload to GCS."""
    client = get_storage_client()
    bucket = client.bucket(settings.gcs_upload_bucket)
    blob = bucket.blob(object_key)

    url = blob.generate_signed_url(
        version="v4",
        expiration=datetime.timedelta(hours=2),
        method="PUT",
        content_type=content_type,
    )
    return url


def get_public_url(bucket_name: str, object_key: str) -> str:
    return f"https://storage.googleapis.com/{bucket_name}/{object_key}"


def blob_exists(bucket_name: str, object_key: str) -> bool:
    client = get_storage_client()
    bucket = client.bucket(bucket_name)
    blob = bucket.blob(object_key)
    return blob.exists()
