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
          // Buffer exactly one 6-second segment ahead so the first click plays instantly.
          final config = js.JsObject.jsify({
            'autoStartLoad': true,
            'maxBufferLength': 6,
            'maxMaxBufferLength': 6,
            'startLevel': -1, // auto quality selection
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
