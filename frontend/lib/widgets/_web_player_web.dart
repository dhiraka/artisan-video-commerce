import 'dart:html' as html;
import 'dart:js' as js;
// ignore: avoid_web_libraries_in_flutter
import 'dart:ui_web' as ui_web;
import 'package:flutter/material.dart';

class WebVideoPlayer extends StatefulWidget {
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
  State<WebVideoPlayer> createState() => _WebVideoPlayerState();
}

class _WebVideoPlayerState extends State<WebVideoPlayer> {
  static int _idCounter = 0;
  late final String _viewId;

  @override
  void initState() {
    super.initState();
    _viewId = 'hls-player-${_idCounter++}';
    final hlsUrl = widget.hlsUrl;
    final dashUrl = widget.dashUrl;
    final posterUrl = widget.posterUrl;
    final muted = widget.muted;
    final autoplay = widget.autoplay;
    final showControls = widget.showControls;

    ui_web.platformViewRegistry.registerViewFactory(_viewId, (int id) {
      final video = html.VideoElement()
        ..style.width = '100%'
        ..style.height = '100%'
        ..style.backgroundColor = 'black'
        ..controls = showControls
        ..muted = muted
        ..autoplay = autoplay
        ..setAttribute('preload', 'auto');
      if (posterUrl != null) video.poster = posterUrl;

      // Chrome/Firefox: hls.js with 4-tier ABR (144p → 720p).
      // DASH manifest only has one ultra-low tier so it can't adapt up —
      // hls.js is always preferred for quality adaptation.
      final hlsClass = js.context['Hls'];
      if (hlsClass != null) {
        final isSupported = js.JsObject.fromBrowserObject(hlsClass)
            .callMethod('isSupported', []) as bool;
        if (isSupported) {
          final config = js.JsObject.jsify({
            'autoStartLoad': true,
            'startLevel': 0,
            'capLevelToPlayerSize': false,
            'maxBufferLength': 30,
            'maxMaxBufferLength': 60,
            'fragLoadingTimeOut': 10000,
            'fragLoadingMaxRetry': 2,
            'abrEwmaFastVoD': 3.0,
            'abrEwmaSlowVoD': 9.0,
            'abrBandWidthFactor': 0.8,    // only upgrade if 80% of bandwidth fits the tier
            'abrBandWidthUpFactor': 0.65, // conservative upgrades — avoids jumping over the 50kbps cliff
          });
          final hlsInstance = js.JsObject(hlsClass as js.JsFunction, [config]);
          hlsInstance.callMethod('loadSource', [hlsUrl]);
          hlsInstance.callMethod('attachMedia', [video]);
          return video;
        }
      }

      // Safari: native HLS — preload handles buffering
      video.src = hlsUrl;
      return video;
    });
  }

  @override
  Widget build(BuildContext context) => HtmlElementView(viewType: _viewId);
}
