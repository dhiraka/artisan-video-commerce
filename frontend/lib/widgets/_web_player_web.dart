import 'dart:html' as html;
import 'dart:js' as js;
// ignore: avoid_web_libraries_in_flutter
import 'dart:ui_web' as ui_web;
import 'package:flutter/material.dart';

class WebVideoPlayer extends StatefulWidget {
  final String hlsUrl;
  final String? posterUrl;
  final bool muted;
  final bool autoplay;
  final bool showControls;

  const WebVideoPlayer({
    super.key,
    required this.hlsUrl,
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

      final hlsClass = js.context['Hls'];
      if (hlsClass != null) {
        final isSupported = js.JsObject.fromBrowserObject(hlsClass)
            .callMethod('isSupported', []) as bool;
        if (isSupported) {
          final config = js.JsObject.jsify({
            'autoStartLoad': true,
            'maxBufferLength': 60,       // buffer 60s so slow network can fill ahead
            'maxMaxBufferLength': 120,
            'startLevel': 0,             // always start at lowest quality (144p)
            'abrEwmaFastLive': 3.0,      // slow down quality upgrades on live
            'abrEwmaSlowLive': 9.0,
            'abrBandWidthFactor': 0.7,   // use only 70% of measured bandwidth for ABR
            'abrBandWidthUpFactor': 0.5, // be conservative upgrading quality
          });
          final hlsInstance = js.JsObject(hlsClass as js.JsFunction, [config]);
          hlsInstance.callMethod('loadSource', [hlsUrl]);
          hlsInstance.callMethod('attachMedia', [video]);
          return video;
        }
      }
      // Safari: native HLS — preload attribute handles buffering
      video.src = hlsUrl;
      return video;
    });
  }

  @override
  Widget build(BuildContext context) => HtmlElementView(viewType: _viewId);
}
