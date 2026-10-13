import 'package:chewie/chewie.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '_web_player_stub.dart' if (dart.library.html) '_web_player_web.dart';

class VideoPlayerWidget extends StatefulWidget {
  final String hlsUrl;
  final String? thumbnailUrl;

  const VideoPlayerWidget({
    super.key,
    required this.hlsUrl,
    this.thumbnailUrl,
  });

  @override
  State<VideoPlayerWidget> createState() => _VideoPlayerWidgetState();
}

class _VideoPlayerWidgetState extends State<VideoPlayerWidget> {
  VideoPlayerController? _videoController;
  ChewieController? _chewieController;

  @override
  void initState() {
    super.initState();
    if (!kIsWeb) _setupNativePlayer();
  }

  Future<void> _setupNativePlayer() async {
    _videoController = VideoPlayerController.networkUrl(
      Uri.parse(widget.hlsUrl),
    );
    await _videoController!.initialize();
    _chewieController = ChewieController(
      videoPlayerController: _videoController!,
      autoPlay: false,
      looping: false,
      aspectRatio: 16 / 9,
      placeholder: widget.thumbnailUrl != null
          ? Image.network(widget.thumbnailUrl!, fit: BoxFit.cover)
          : null,
    );
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _videoController?.dispose();
    _chewieController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: kIsWeb
          ? WebVideoPlayer(hlsUrl: widget.hlsUrl, posterUrl: widget.thumbnailUrl)
          : (_chewieController != null
              ? Chewie(controller: _chewieController!)
              : const Center(child: CircularProgressIndicator())),
    );
  }
}
