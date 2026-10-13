# Artisan Video-Commerce Platform

A cross-platform marketplace where independent artisans showcase craftsmanship through Behind-the-Scenes process videos linked directly to handmade products.

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                        Flutter App                          │
│          (Android Phone · Android Tablet · Web/Chrome)      │
└────────┬───────────────────────────┬────────────────────────┘
         │ REST API                  │ Direct upload (signed URL)
         ▼                           ▼
┌─────────────────┐         ┌─────────────────────┐
│  FastAPI Backend│         │  Google Cloud Storage│
│  (Cloud Run)    │──jobs──▶│  (Raw video upload) │
└────────┬────────┘         └──────────┬──────────┘
         │                             │ triggers
         ▼                             ▼
┌─────────────────┐         ┌─────────────────────┐
│   Firestore     │◀─update─│  GCP Transcoder API  │
│  (products +    │         │  HLS 4-tier output:  │
│   orders)       │         │  144p·240p·360p·720p │
└─────────────────┘         └──────────┬──────────┘
                                        │ HLS segments
                                        ▼
                             ┌─────────────────────┐
                             │  GCS Output Bucket  │
                             │  (public, CDN-ready)│
                             └─────────────────────┘
```

## Ultra-Low Bandwidth Video (< 50 kbps)

The GCP Transcoder API produces an HLS adaptive bitrate manifest with 4 quality tiers:

| Tier       | Resolution | Video     | Audio    | Total    |
|------------|------------|-----------|----------|----------|
| Ultra-low  | 256×144    | 30 kbps   | 16 kbps  | ~46 kbps |
| Low        | 426×240    | 150 kbps  | 48 kbps  | ~200 kbps|
| Medium     | 640×360    | 500 kbps  | 96 kbps  | ~600 kbps|
| High       | 1280×720   | 2000 kbps | 128 kbps | ~2.1 Mbps|

`better_player` (Android: ExoPlayer, Web: hls.js) automatically selects the appropriate tier based on measured bandwidth. Under 50 kbps, the player locks to the ultra-low tier and buffers aggressively (15s min / 60s max buffer) for uninterrupted playback.

## Platform Compatibility

| Platform        | Implementation              | Video Player         |
|-----------------|-----------------------------|----------------------|
| Android Phone   | Flutter native ARM build    | ExoPlayer (HLS ABR)  |
| Android Tablet  | Flutter native ARM build    | ExoPlayer (HLS ABR)  |
| Google Chrome   | Flutter Web (WASM/JS)       | hls.js (HLS ABR)     |

> **On "Native":** Flutter compiles to native ARM code on Android (not interpreted, not WebView). It uses platform channels for camera/file access and ExoPlayer for video — the same engine YouTube Android uses. The tablet layout uses a responsive side-rail + master-detail pattern, not a phone layout scaled up.

## Project Structure

```
artisan-video-commerce-platform/
├── backend/                    # FastAPI on Google Cloud Run
│   ├── app/
│   │   ├── main.py             # FastAPI app + CORS
│   │   ├── config.py           # Environment config
│   │   ├── models/             # Pydantic request/response models
│   │   ├── routers/            # products, orders, videos endpoints
│   │   └── services/           # GCS, Transcoder, Firestore clients
│   ├── Dockerfile
│   ├── requirements.txt
│   └── cloudbuild.yaml         # Cloud Build → Cloud Run deployment
├── frontend/                   # Flutter (Android + Web)
│   ├── lib/
│   │   ├── main.dart           # App entry + Material3 theme
│   │   ├── config/             # API base URL
│   │   ├── models/             # Product, Order data classes
│   │   ├── providers/          # ProductsProvider, UploadProvider
│   │   ├── screens/            # Home, Upload, ProductDetail, OrderConfirmation
│   │   ├── services/           # ApiService (Dio HTTP client)
│   │   └── widgets/            # ProductCard, VideoPlayerWidget
│   ├── android/                # Android manifest (permissions)
│   ├── web/index.html          # hls.js injected for Chrome HLS support
│   └── pubspec.yaml
├── infrastructure/
│   ├── cors.json               # GCS CORS policy (allows PUT from web)
│   └── deploy.sh               # One-shot GCP provisioning script
└── README.md
```

## Setup & Deployment

### Prerequisites
- Google Cloud SDK (`gcloud`)
- Flutter SDK ≥ 3.16 with Android SDK
- A GCP project with billing enabled

### 1. Deploy Backend to GCP

```bash
chmod +x infrastructure/deploy.sh
./infrastructure/deploy.sh YOUR_GCP_PROJECT_ID
```

This script:
1. Enables all required GCP APIs
2. Creates GCS buckets (upload + output)
3. Applies CORS policy to upload bucket
4. Makes output bucket publicly readable
5. Grants Transcoder service account `objectAdmin` on both buckets
6. Initializes Firestore in Native mode
7. Builds Docker image and deploys to Cloud Run

### 2. Build Flutter App

```bash
cd frontend
flutter pub get

# Android APK
flutter build apk --dart-define=API_BASE_URL=https://YOUR_CLOUD_RUN_URL

# Android App Bundle (Play Store)
flutter build appbundle --dart-define=API_BASE_URL=https://YOUR_CLOUD_RUN_URL

# Web (Chrome)
flutter build web --dart-define=API_BASE_URL=https://YOUR_CLOUD_RUN_URL
# Serve: cd build/web && python3 -m http.server 8000
```

### 3. Backend Environment Variables

Set in Cloud Run (handled by `cloudbuild.yaml`) or `.env` for local dev:

```env
GCP_PROJECT_ID=your-project-id
GCS_UPLOAD_BUCKET=artisan-uploads-your-project-id
GCS_OUTPUT_BUCKET=artisan-output-your-project-id
TRANSCODER_LOCATION=us-central1
CORS_ORIGINS=*
```

### 4. Local Backend Development

```bash
cd backend
pip install -r requirements.txt
cp .env.example .env  # fill in your values
gcloud auth application-default login
uvicorn app.main:app --reload --port 8080
```

API docs: http://localhost:8080/docs

## API Endpoints

| Method | Endpoint                        | Description                              |
|--------|---------------------------------|------------------------------------------|
| POST   | `/api/videos/upload-url`        | Get signed GCS URL for direct upload     |
| POST   | `/api/videos/notify`            | Trigger HLS transcoding after upload     |
| GET    | `/api/videos/{id}/status`       | Poll transcoding job status              |
| POST   | `/api/products`                 | Create product listing                   |
| GET    | `/api/products?q=&tags=`        | Search/filter products                   |
| GET    | `/api/products/{id}`            | Get single product                       |
| POST   | `/api/orders`                   | Place order                              |
| GET    | `/api/orders/{id}`              | Get order confirmation                   |

## User Flows

### Artisan Flow
1. Open app → tap **Sell** tab
2. Tap video area → pick process video file (any size, up to 15 min)
3. Fill product details (name, title, description, price, tags)
4. Tap **Upload & List Product**
5. App uploads video directly to GCS, then triggers HLS transcoding
6. Wait for transcoding (typically 2–5× video duration)
7. Product is live and discoverable

### Buyer Flow
1. Open app → **Browse** tab shows product grid
2. Search by keyword or filter by tag chips
3. Tap a product card → watch the artisan's process video
4. Fill order form (name, email, address, quantity)
5. Tap **Place Order** → order confirmation screen

## Required GCP IAM Roles

| Service Account                              | Role                     | Scope          |
|----------------------------------------------|--------------------------|----------------|
| Cloud Run service account                    | `roles/datastore.user`   | Project        |
| Cloud Run service account                    | `roles/storage.objectAdmin` | Both buckets|
| `service-{N}@gcp-sa-mediatranscoder.iam...`  | `roles/storage.objectAdmin` | Both buckets|
| All Users                                    | `roles/storage.objectViewer` | Output bucket|
