#!/usr/bin/env bash
# deploy.sh — One-shot GCP provisioning + backend deployment
# Usage: ./infrastructure/deploy.sh <GCP_PROJECT_ID>
set -euo pipefail

PROJECT_ID="${1:-}"
if [[ -z "$PROJECT_ID" ]]; then
  echo "Usage: $0 <GCP_PROJECT_ID>"
  exit 1
fi

REGION="asia-south1"
UPLOAD_BUCKET="artisan-uploads-${PROJECT_ID}"
OUTPUT_BUCKET="artisan-output-${PROJECT_ID}"

echo "==> Setting project: $PROJECT_ID"
gcloud config set project "$PROJECT_ID"

echo "==> Enabling required APIs..."
gcloud services enable \
  run.googleapis.com \
  cloudbuild.googleapis.com \
  storage.googleapis.com \
  firestore.googleapis.com \
  transcoder.googleapis.com \
  containerregistry.googleapis.com \
  --project="$PROJECT_ID"

echo "==> Creating GCS buckets..."
gsutil mb -p "$PROJECT_ID" -l "$REGION" "gs://${UPLOAD_BUCKET}" 2>/dev/null || true
gsutil mb -p "$PROJECT_ID" -l "$REGION" "gs://${OUTPUT_BUCKET}" 2>/dev/null || true

echo "==> Applying CORS policy to upload bucket..."
gsutil cors set infrastructure/cors.json "gs://${UPLOAD_BUCKET}"

echo "==> Making output bucket publicly readable (for HLS + thumbnails)..."
gsutil iam ch allUsers:objectViewer "gs://${OUTPUT_BUCKET}"

echo "==> Granting Transcoder service account access to buckets (if SA exists)..."
PROJECT_NUMBER=$(gcloud projects describe "$PROJECT_ID" --format="value(projectNumber)")
TRANSCODER_SA="service-${PROJECT_NUMBER}@gcp-sa-mediatranscoder.iam.gserviceaccount.com"
if gcloud iam service-accounts describe "$TRANSCODER_SA" --project="$PROJECT_ID" &>/dev/null; then
  gsutil iam ch "serviceAccount:${TRANSCODER_SA}:objectAdmin" "gs://${UPLOAD_BUCKET}"
  gsutil iam ch "serviceAccount:${TRANSCODER_SA}:objectAdmin" "gs://${OUTPUT_BUCKET}"
  echo "    Transcoder SA granted."
else
  echo "    Transcoder SA not yet created (will be auto-created on first job). Skipping."
  echo "    Re-run: gsutil iam ch serviceAccount:${TRANSCODER_SA}:objectAdmin gs://${UPLOAD_BUCKET}"
  echo "    Re-run: gsutil iam ch serviceAccount:${TRANSCODER_SA}:objectAdmin gs://${OUTPUT_BUCKET}"
fi

echo "==> Initializing Firestore (Native mode)..."
gcloud firestore databases create --region="$REGION" --project="$PROJECT_ID" 2>/dev/null || true

echo "==> Creating Firestore indexes..."
gcloud firestore indexes composite create \
  --collection-group=products \
  --field-config field-path=status,order=ASCENDING \
  --field-config field-path=created_at,order=DESCENDING \
  --project="$PROJECT_ID" 2>/dev/null || true

echo "==> Building and deploying backend to Cloud Run..."
gcloud builds submit backend/ \
  --config=backend/cloudbuild.yaml \
  --project="$PROJECT_ID"

BACKEND_URL=$(gcloud run services describe artisan-backend \
  --region="$REGION" \
  --project="$PROJECT_ID" \
  --format="value(status.url)")

echo ""
echo "=========================================="
echo "Deployment complete!"
echo "Backend URL: $BACKEND_URL"
echo ""
echo "Next: Build Flutter app with:"
echo "  cd frontend"
echo "  flutter build apk --dart-define=API_BASE_URL=${BACKEND_URL}"
echo "  flutter build web --dart-define=API_BASE_URL=${BACKEND_URL}"
echo "=========================================="
