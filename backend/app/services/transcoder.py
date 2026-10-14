import logging

from google.cloud.video import transcoder_v1
from google.cloud.video.transcoder_v1.services.transcoder_service import (
    TranscoderServiceClient,
)
from google.protobuf import duration_pb2
from app.config import settings

log = logging.getLogger(__name__)


def create_hls_job(product_id: str, input_object_key: str) -> str:
    """
    Outputs:
      HLS  — 4 H.264/AAC tiers (144p–720p) for broad compatibility
      DASH — VP9/Opus ultra-low tier (~28 kbps) for <50 kbps networks
    Also generates a thumbnail at t=1s.
    """
    client = TranscoderServiceClient()
    parent = f"projects/{settings.gcp_project_id}/locations/{settings.transcoder_location}"

    input_uri = f"gs://{settings.gcs_upload_bucket}/{input_object_key}"
    output_uri = f"gs://{settings.gcs_output_bucket}/hls/{product_id}/"

    log.info("Creating transcoder job: product=%s input=%s output=%s", product_id, input_uri, output_uri)

    job = transcoder_v1.Job(
        input_uri=input_uri,
        output_uri=output_uri,
        config=transcoder_v1.JobConfig(
            elementary_streams=_elementary_streams(),
            mux_streams=_mux_streams(),
            manifests=[
                # HLS manifest — all 4 H.264 tiers
                transcoder_v1.Manifest(
                    file_name="manifest.m3u8",
                    type_=transcoder_v1.Manifest.ManifestType.HLS,
                    mux_streams=[
                        "hls-ultra-low",
                        "hls-micro-low",
                        "hls-low",
                        "hls-medium",
                        "hls-high",
                        "hls-ultra-high",
                        "hls-2k",
                        "hls-4k",
                    ],
                ),
                # DASH manifest — VP9+AAC ultra-low (~28 kbps)
                transcoder_v1.Manifest(
                    file_name="manifest.mpd",
                    type_=transcoder_v1.Manifest.ManifestType.DASH,
                    mux_streams=["dash-video-ultra-low", "dash-audio-ultra-low"],
                ),
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
    log.info("Transcoder job created: %s", response.name)
    return response.name


def get_job_status(job_name: str) -> tuple[str, str | None]:
    """Returns (status, error_message) where status is 'processing', 'ready', or 'failed'."""
    client = TranscoderServiceClient()
    job = client.get_job(name=job_name)

    log.info("Transcoder job %s state=%s", job_name, job.state)

    state_map = {
        transcoder_v1.Job.ProcessingState.PROCESSING_STATE_UNSPECIFIED: "processing",
        transcoder_v1.Job.ProcessingState.PENDING: "processing",
        transcoder_v1.Job.ProcessingState.RUNNING: "processing",
        transcoder_v1.Job.ProcessingState.SUCCEEDED: "ready",
        transcoder_v1.Job.ProcessingState.FAILED: "failed",
    }
    status = state_map.get(job.state, "processing")

    error_message = None
    if status == "failed":
        error_message = job.error.message if job.error else "unknown error"
        log.error("Transcoder job %s FAILED: %s", job_name, error_message)

    return status, error_message


def _elementary_streams() -> list:
    return [
        # ── H.264 streams for HLS ────────────────────────────────────────────

        # Ultra-low: 6kbps video + 4kbps audio = ~10kbps total
        # 80% headroom on a 50kbps network after TCP/TLS overhead
        transcoder_v1.ElementaryStream(
            key="video-ultra-low",
            video_stream=transcoder_v1.VideoStream(
                h264=transcoder_v1.VideoStream.H264CodecSettings(
                    height_pixels=144,
                    width_pixels=256,
                    bitrate_bps=6_000,
                    frame_rate=8,
                    gop_duration=duration_pb2.Duration(seconds=2),
                    pixel_format="yuv420p",
                    rate_control_mode="vbr",
                    vbv_size_bits=12_000,
                    vbv_fullness_bits=6_000,
                    entropy_coder="cabac",
                    profile="baseline",
                )
            ),
        ),
        transcoder_v1.ElementaryStream(
            key="audio-ultra-low",
            audio_stream=transcoder_v1.AudioStream(
                codec="aac",
                bitrate_bps=4_000,
                channel_count=1,
                channel_layout=["fc"],
                sample_rate_hertz=16000,
            ),
        ),

        # Micro-low: 22kbps video + 8kbps audio = 30kbps total
        # Fits 50kbps networks with 40% headroom — safe upgrade from ultra-low
        transcoder_v1.ElementaryStream(
            key="video-micro-low",
            video_stream=transcoder_v1.VideoStream(
                h264=transcoder_v1.VideoStream.H264CodecSettings(
                    height_pixels=180,
                    width_pixels=320,
                    bitrate_bps=22_000,
                    frame_rate=15,
                    gop_duration=duration_pb2.Duration(seconds=4),
                    pixel_format="yuv420p",
                    rate_control_mode="vbr",
                    entropy_coder="cabac",
                    profile="baseline",
                )
            ),
        ),
        transcoder_v1.ElementaryStream(
            key="audio-micro-low",
            audio_stream=transcoder_v1.AudioStream(
                codec="aac",
                bitrate_bps=8_000,
                channel_count=1,
                channel_layout=["fc"],
                sample_rate_hertz=22050,
            ),
        ),

        # Low: ~150kbps video + 48kbps audio
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

        # Medium: ~500kbps video + 96kbps audio
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

        # 2K (1440p): ~16Mbps video + 192kbps audio
        transcoder_v1.ElementaryStream(
            key="video-2k",
            video_stream=transcoder_v1.VideoStream(
                h264=transcoder_v1.VideoStream.H264CodecSettings(
                    height_pixels=1440,
                    width_pixels=2560,
                    bitrate_bps=16_000_000,
                    frame_rate=30,
                    pixel_format="yuv420p",
                    rate_control_mode="vbr",
                    entropy_coder="cabac",
                    profile="high",
                )
            ),
        ),
        transcoder_v1.ElementaryStream(
            key="audio-2k",
            audio_stream=transcoder_v1.AudioStream(
                codec="aac",
                bitrate_bps=192_000,
                channel_count=2,
                sample_rate_hertz=48000,
            ),
        ),

        # 4K (2160p): ~35Mbps video + 192kbps audio
        transcoder_v1.ElementaryStream(
            key="video-4k",
            video_stream=transcoder_v1.VideoStream(
                h264=transcoder_v1.VideoStream.H264CodecSettings(
                    height_pixels=2160,
                    width_pixels=3840,
                    bitrate_bps=35_000_000,
                    frame_rate=30,
                    pixel_format="yuv420p",
                    rate_control_mode="vbr",
                    entropy_coder="cabac",
                    profile="high",
                )
            ),
        ),
        transcoder_v1.ElementaryStream(
            key="audio-4k",
            audio_stream=transcoder_v1.AudioStream(
                codec="aac",
                bitrate_bps=192_000,
                channel_count=2,
                sample_rate_hertz=48000,
            ),
        ),

        # Ultra-high: ~8Mbps video + 192kbps audio (1080p)
        transcoder_v1.ElementaryStream(
            key="video-ultra-high",
            video_stream=transcoder_v1.VideoStream(
                h264=transcoder_v1.VideoStream.H264CodecSettings(
                    height_pixels=1080,
                    width_pixels=1920,
                    bitrate_bps=8_000_000,
                    frame_rate=30,
                    pixel_format="yuv420p",
                    rate_control_mode="vbr",
                    entropy_coder="cabac",
                    profile="high",
                )
            ),
        ),
        transcoder_v1.ElementaryStream(
            key="audio-ultra-high",
            audio_stream=transcoder_v1.AudioStream(
                codec="aac",
                bitrate_bps=192_000,
                channel_count=2,
                sample_rate_hertz=48000,
            ),
        ),

        # High: ~2Mbps video + 128kbps audio
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

        # ── VP9 + Opus stream for DASH ───────────────────────────────────────
        # VP9 delivers same quality as H.264 at ~50% the bitrate.
        # Opus at 8kbps mono is intelligible speech — far better than AAC at same bitrate.
        # Total: ~28kbps, identical target to HLS ultra-low but better quality.

        transcoder_v1.ElementaryStream(
            key="video-ultra-low-vp9",
            video_stream=transcoder_v1.VideoStream(
                vp9=transcoder_v1.VideoStream.Vp9CodecSettings(
                    height_pixels=144,
                    width_pixels=256,
                    bitrate_bps=6_000,
                    frame_rate=8,
                    gop_duration=duration_pb2.Duration(seconds=2),
                    pixel_format="yuv420p",
                    rate_control_mode="vbr",
                    profile="profile0",
                )
            ),
        ),
        transcoder_v1.ElementaryStream(
            key="audio-ultra-low-dash",
            audio_stream=transcoder_v1.AudioStream(
                codec="aac",
                bitrate_bps=8_000,
                channel_count=1,
                channel_layout=["fc"],
                sample_rate_hertz=22050,
            ),
        ),
    ]


def _mux_streams() -> list:
    seg = transcoder_v1.SegmentSettings(
        segment_duration=duration_pb2.Duration(seconds=6)
    )
    seg_ultra_low = transcoder_v1.SegmentSettings(
        segment_duration=duration_pb2.Duration(seconds=2)
    )
    return [
        # HLS — MPEG-TS container (H.264 + AAC)
        # Ultra-low uses 2s segments: 2.5KB each, less data at risk per stall
        transcoder_v1.MuxStream(
            key="hls-ultra-low",
            container="ts",
            elementary_streams=["video-ultra-low", "audio-ultra-low"],
            segment_settings=seg_ultra_low,
        ),
        transcoder_v1.MuxStream(
            key="hls-micro-low",
            container="ts",
            elementary_streams=["video-micro-low", "audio-micro-low"],
            segment_settings=transcoder_v1.SegmentSettings(
                segment_duration=duration_pb2.Duration(seconds=4)
            ),
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

        transcoder_v1.MuxStream(
            key="hls-ultra-high",
            container="ts",
            elementary_streams=["video-ultra-high", "audio-ultra-high"],
            segment_settings=seg,
        ),
        transcoder_v1.MuxStream(
            key="hls-2k",
            container="ts",
            elementary_streams=["video-2k", "audio-2k"],
            segment_settings=seg,
        ),
        transcoder_v1.MuxStream(
            key="hls-4k",
            container="ts",
            elementary_streams=["video-4k", "audio-4k"],
            segment_settings=seg,
        ),

        # DASH — fmp4, one elementary stream per mux (VP9 video + AAC audio)
        transcoder_v1.MuxStream(
            key="dash-video-ultra-low",
            container="fmp4",
            elementary_streams=["video-ultra-low-vp9"],
            segment_settings=seg_ultra_low,
        ),
        transcoder_v1.MuxStream(
            key="dash-audio-ultra-low",
            container="fmp4",
            elementary_streams=["audio-ultra-low-dash"],
            segment_settings=seg_ultra_low,
        ),
    ]
