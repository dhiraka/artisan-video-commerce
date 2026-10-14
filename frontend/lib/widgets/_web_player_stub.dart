import 'package:flutter/material.dart';

class WebVideoPlayer extends StatelessWidget {
  final String hlsUrl;
  final String? dashUrl;
  final String? posterUrl;
  final bool muted;
  final bool autoplay;
  final bool showControls;

  const WebVideoPlayer({
    super.key,
    required this.hlsUrl,
    this.dashUrl,
    this.posterUrl,
    this.muted = false,
    this.autoplay = false,
    this.showControls = true,
  });

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
