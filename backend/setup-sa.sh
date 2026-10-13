#!/bin/bash
GCLOUD=/opt/homebrew/share/google-cloud-sdk/bin/gcloud
PROJECT=artisan-video-commerce
SA=artisan-backend@artisan-video-commerce.iam.gserviceaccount.com

$GCLOUD projects add-iam-policy-binding $PROJECT --member="serviceAccount:$SA" --role="roles/storage.admin"
$GCLOUD projects add-iam-policy-binding $PROJECT --member="serviceAccount:$SA" --role="roles/datastore.user"
$GCLOUD projects add-iam-policy-binding $PROJECT --member="serviceAccount:$SA" --role="roles/transcoder.admin"
$GCLOUD iam service-accounts keys create "$(dirname "$0")/service-account.json" --iam-account=$SA
