from google.cloud.video import transcoder_v1
from google.cloud.video.transcoder_v1.services.transcoder_service import (
    TranscoderServiceClient,
)
from google.protobuf import duration_pb2
from app.config import settings


def create_hls_job(product_id: str, input_object_key: str) -> str:
    """
    Create a GCP Transcoder job that outputs HLS with 4 quality tiers:
    - ultra-low: 144p @ ~46kbps (for <50kbps networks)
    - low:       240p @ ~200kbps
    - medium:    360p @ ~600kbps
    - high:      720p @ ~2Mbps
    Also generates a thumbnail at t=1s.
    Returns the job name.
    """
    client = TranscoderServiceClient()
    parent = f"projects/{settings.gcp_project_id}/locations/{settings.transcoder_location}"

    input_uri = f"gs://{settings.gcs_upload_bucket}/{input_object_key}"
    output_uri = f"gs://{settings.gcs_output_bucket}/hls/{product_id}/"

    job = transcoder_v1.Job(
        input_uri=input_uri,
        output_uri=output_uri,
        config=transcoder_v1.JobConfig(
            elementary_streams=_elementary_streams(),
            mux_streams=_mux_streams(),
            manifests=[
                transcoder_v1.Manifest(
                    file_name="manifest.m3u8",
                    type_=transcoder_v1.Manifest.ManifestType.HLS,
                    mux_streams=[
                        "hls-ultra-low",
                        "hls-low",
                        "hls-medium",
                        "hls-high",
                    ],
                )
            ],
            sprite_sheets=[
                transcoder_v1.SpriteSheet(
                    file_prefix="thumbnail",
                    start_time_offset=duration_pb2.Duration(seconds=1),
                    end_time_offset=duration_pb2.Duration(seconds=1),
                    column_count=1,
                    row_count=1,
                    sprite_width_pixels=640,
                    sprite_height_pixels=360,
                )
            ],
        ),
    )

    response = client.create_job(parent=parent, job=job)
    return response.name


def get_job_status(job_name: str) -> str:
    """Returns 'processing', 'ready', or 'failed'."""
    client = TranscoderServiceClient()
    job = client.get_job(name=job_name)

    state_map = {
        transcoder_v1.Job.ProcessingState.PROCESSING_STATE_UNSPECIFIED: "processing",
        transcoder_v1.Job.ProcessingState.PENDING: "processing",
        transcoder_v1.Job.ProcessingState.RUNNING: "processing",
        transcoder_v1.Job.ProcessingState.SUCCEEDED: "ready",
        transcoder_v1.Job.ProcessingState.FAILED: "failed",
    }
    return state_map.get(job.state, "processing")


def _elementary_streams() -> list:
    return [
        # ---- Ultra-low: ~30kbps video + 16kbps audio = ~46kbps total ----
        transcoder_v1.ElementaryStream(
            key="video-ultra-low",
            video_stream=transcoder_v1.VideoStream(
                h264=transcoder_v1.VideoStream.H264CodecSettings(
                    height_pixels=144,
                    width_pixels=256,
                    bitrate_bps=30_000,
                    frame_rate=15,
                    pixel_format="yuv420p",
                    rate_control_mode="vbr",
                    vbv_size_bits=60_000,
                    vbv_fullness_bits=30_000,
                    entropy_coder="cabac",
                    profile="baseline",
                )
            ),
        ),
        transcoder_v1.ElementaryStream(
            key="audio-ultra-low",
            audio_stream=transcoder_v1.AudioStream(
                codec="aac",
                bitrate_bps=16_000,
                channel_count=2,
                sample_rate_hertz=22050,
            ),
        ),
        # ---- Low: ~150kbps video + 48kbps audio ----
        transcoder_v1.ElementaryStream(
            key="video-low",
            video_stream=transcoder_v1.VideoStream(
                h264=transcoder_v1.VideoStream.H264CodecSettings(
                    height_pixels=240,
                    width_pixels=426,
                    bitrate_bps=150_000,
                    frame_rate=24,
                    pixel_format="yuv420p",
                    rate_control_mode="vbr",
                    entropy_coder="cabac",
                    profile="baseline",
                )
            ),
        ),
        transcoder_v1.ElementaryStream(
            key="audio-low",
            audio_stream=transcoder_v1.AudioStream(
                codec="aac",
                bitrate_bps=48_000,
                channel_count=2,
                sample_rate_hertz=44100,
            ),
        ),
        # ---- Medium: ~500kbps video + 96kbps audio ----
        transcoder_v1.ElementaryStream(
            key="video-medium",
            video_stream=transcoder_v1.VideoStream(
                h264=transcoder_v1.VideoStream.H264CodecSettings(
                    height_pixels=360,
                    width_pixels=640,
                    bitrate_bps=500_000,
                    frame_rate=30,
                    pixel_format="yuv420p",
                    rate_control_mode="vbr",
                    entropy_coder="cabac",
                    profile="main",
                )
            ),
        ),
        transcoder_v1.ElementaryStream(
            key="audio-medium",
            audio_stream=transcoder_v1.AudioStream(
                codec="aac",
                bitrate_bps=96_000,
                channel_count=2,
                sample_rate_hertz=44100,
            ),
        ),
        # ---- High: ~2Mbps video + 128kbps audio ----
        transcoder_v1.ElementaryStream(
            key="video-high",
            video_stream=transcoder_v1.VideoStream(
                h264=transcoder_v1.VideoStream.H264CodecSettings(
                    height_pixels=720,
                    width_pixels=1280,
                    bitrate_bps=2_000_000,
                    frame_rate=30,
                    pixel_format="yuv420p",
                    rate_control_mode="vbr",
                    entropy_coder="cabac",
                    profile="high",
                )
            ),
        ),
        transcoder_v1.ElementaryStream(
            key="audio-high",
            audio_stream=transcoder_v1.AudioStream(
                codec="aac",
                bitrate_bps=128_000,
                channel_count=2,
                sample_rate_hertz=44100,
            ),
        ),
    ]


def _mux_streams() -> list:
    seg = transcoder_v1.SegmentSettings(
        segment_duration=duration_pb2.Duration(seconds=6)
    )
    return [
        transcoder_v1.MuxStream(
            key="hls-ultra-low",
            container="ts",
            elementary_streams=["video-ultra-low", "audio-ultra-low"],
            segment_settings=seg,
        ),
        transcoder_v1.MuxStream(
            key="hls-low",
            container="ts",
            elementary_streams=["video-low", "audio-low"],
            segment_settings=seg,
        ),
        transcoder_v1.MuxStream(
            key="hls-medium",
            container="ts",
            elementary_streams=["video-medium", "audio-medium"],
            segment_settings=seg,
        ),
        transcoder_v1.MuxStream(
            key="hls-high",
            container="ts",
            elementary_streams=["video-high", "audio-high"],
            segment_settings=seg,
        ),
    ]
