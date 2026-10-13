#!/bin/bash
GCLOUD=/opt/homebrew/share/google-cloud-sdk/bin/gcloud
CORS=/Users/radhikaandhavarapu/Code/artisan-video-commerce-platform/infrastructure/cors.json

$GCLOUD storage buckets update gs://artisan-uploads-artisan-video-commerce --cors-file=$CORS
$GCLOUD storage buckets update gs://artisan-output-artisan-video-commerce --cors-file=$CORS
