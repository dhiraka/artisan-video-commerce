import logging
import uuid
from fastapi import APIRouter, HTTPException
from pydantic import BaseModel

from app.services.storage import generate_upload_signed_url
from app.services.transcoder import create_hls_job, get_job_status
from app.services.firestore import get_product, update_product
from app.config import settings

log = logging.getLogger(__name__)

router = APIRouter(prefix="/videos", tags=["videos"])


class UploadUrlRequest(BaseModel):
    filename: str
    content_type: str = "video/mp4"


class UploadUrlResponse(BaseModel):
    upload_url: str
    object_key: str


class NotifyUploadRequest(BaseModel):
    product_id: str
    object_key: str


@router.post("/upload-url", response_model=UploadUrlResponse)
def get_upload_url(req: UploadUrlRequest):
    """Generate a signed GCS URL for direct client video upload."""
    ext = req.filename.rsplit(".", 1)[-1] if "." in req.filename else "mp4"
    object_key = f"raw/{uuid.uuid4()}.{ext}"
    url = generate_upload_signed_url(object_key, req.content_type)
    return UploadUrlResponse(upload_url=url, object_key=object_key)


@router.post("/notify")
def notify_upload_complete(req: NotifyUploadRequest):
    """Called by client after direct GCS upload finishes. Triggers transcoding."""
    product = get_product(req.product_id)
    if not product:
        raise HTTPException(status_code=404, detail="Product not found")

    try:
        job_name = create_hls_job(req.product_id, req.object_key)
    except Exception as e:
        log.exception("Failed to create transcoder job for product=%s: %s", req.product_id, e)
        update_product(req.product_id, {"status": "failed", "error": str(e)})
        raise HTTPException(status_code=500, detail=f"Transcoder job creation failed: {e}")

    update_product(req.product_id, {"transcoder_job": job_name, "status": "processing"})
    return {"message": "Transcoding started", "job": job_name}


@router.get("/{product_id}/status")
def get_video_status(product_id: str):
    """Poll transcoding status. Returns status + HLS URL when ready."""
    product = get_product(product_id)
    if not product:
        raise HTTPException(status_code=404, detail="Product not found")

    current_status = product.get("status", "processing")

    if current_status == "ready":
        return {
            "status": "ready",
            "hls_manifest_url": product.get("hls_manifest_url"),
            "thumbnail_url": product.get("thumbnail_url"),
        }

    if current_status == "failed":
        return {"status": "failed", "error": product.get("error")}

    job_name = product.get("transcoder_job")
    if not job_name:
        return {"status": "processing"}

    try:
        job_status, error_message = get_job_status(job_name)
    except Exception as e:
        log.exception("Failed to poll transcoder job %s: %s", job_name, e)
        return {"status": "processing"}

    if job_status == "ready":
        hls_url = (
            f"https://storage.googleapis.com/{settings.gcs_output_bucket}"
            f"/hls/{product_id}/manifest.m3u8"
        )
        thumbnail_url = (
            f"https://storage.googleapis.com/{settings.gcs_output_bucket}"
            f"/hls/{product_id}/thumbnail0000000000.jpeg"
        )
        update_product(
            product_id,
            {
                "status": "ready",
                "hls_manifest_url": hls_url,
                "thumbnail_url": thumbnail_url,
            },
        )
        return {"status": "ready", "hls_manifest_url": hls_url, "thumbnail_url": thumbnail_url}

    if job_status == "failed":
        update_product(product_id, {"status": "failed", "error": error_message})
        return {"status": "failed", "error": error_message}

    return {"status": job_status}
