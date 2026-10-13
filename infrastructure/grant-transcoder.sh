#!/bin/bash
GCLOUD=/opt/homebrew/share/google-cloud-sdk/bin/gcloud
$GCLOUD projects add-iam-policy-binding artisan-video-commerce --member="serviceAccount:service-607374629084@gcp-sa-transcoder.iam.gserviceaccount.com" --role="roles/storage.admin"
