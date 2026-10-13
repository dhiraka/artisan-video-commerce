import datetime
import json
import os

import google.auth
import google.auth.transport.requests
from google.cloud import storage
from google.oauth2 import service_account

from app.config import settings


def _get_credentials():
    """Return credentials suitable for signing (service account with private key, if available)."""
    key_path = os.getenv("GOOGLE_APPLICATION_CREDENTIALS")
    if key_path and os.path.exists(key_path):
        try:
            with open(key_path) as f:
                info = json.load(f)
            if info.get("type") == "service_account":
                return service_account.Credentials.from_service_account_file(key_path)
        except Exception:
            pass
    return None


def get_storage_client() -> storage.Client:
    creds = _get_credentials()
    if creds:
        return storage.Client(credentials=creds, project=settings.gcp_project_id)
    return storage.Client(project=settings.gcp_project_id)


def generate_upload_signed_url(object_key: str, content_type: str = "video/mp4") -> str:
    """Generate a v4 signed URL for direct client upload to GCS."""
    client = get_storage_client()
    bucket = client.bucket(settings.gcs_upload_bucket)
    blob = bucket.blob(object_key)

    sa_creds = _get_credentials()
    if sa_creds:
        # Service account key available — sign directly
        url = blob.generate_signed_url(
            version="v4",
            expiration=datetime.timedelta(hours=2),
            method="PUT",
            content_type=content_type,
            credentials=sa_creds,
        )
    else:
        # No key file — use IAM signBlob API via the current access token
        if not settings.gcp_service_account_email:
            raise RuntimeError(
                "Set GCP_SERVICE_ACCOUNT_EMAIL in .env (or provide a service account key via "
                "GOOGLE_APPLICATION_CREDENTIALS) to generate signed URLs without a key file."
            )
        credentials, _ = google.auth.default()
        auth_request = google.auth.transport.requests.Request()
        credentials.refresh(auth_request)

        url = blob.generate_signed_url(
            version="v4",
            expiration=datetime.timedelta(hours=2),
            method="PUT",
            content_type=content_type,
            service_account_email=settings.gcp_service_account_email,
            access_token=credentials.token,
        )

    return url


def get_public_url(bucket_name: str, object_key: str) -> str:
    return f"https://storage.googleapis.com/{bucket_name}/{object_key}"


def blob_exists(bucket_name: str, object_key: str) -> bool:
    client = get_storage_client()
    bucket = client.bucket(bucket_name)
    blob = bucket.blob(object_key)
    return blob.exists()
