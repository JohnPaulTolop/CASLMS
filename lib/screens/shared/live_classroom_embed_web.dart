import 'dart:convert';
import 'dart:js_interop';
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

class LiveClassroomEmbed extends StatefulWidget {
  const LiveClassroomEmbed({
    super.key,
    required this.connection,
    required this.onLeave,
  });
  final Map<String, dynamic> connection;
  final VoidCallback onLeave;
  @override
  State<LiveClassroomEmbed> createState() => _LiveClassroomEmbedState();
}

class _LiveClassroomEmbedState extends State<LiveClassroomEmbed> {
  static int _nextId = 0;
  late final String _viewId;
  late final web.HTMLIFrameElement _frame;
  late final JSFunction _listener;

  @override
  void initState() {
    super.initState();
    _viewId = 'cas-live-class-${_nextId++}';
    _frame = web.HTMLIFrameElement()
      ..src = Uri.parse(web.document.baseURI)
          .resolve('live-class.html')
          .toString()
      ..title = 'Live classroom'
      ..allow = 'camera; microphone; display-capture; autoplay; fullscreen'
      ..style.border = '0'
      ..style.width = '100%'
      ..style.height = '100%';
    _listener = ((web.MessageEvent event) {
      if (event.origin != web.window.location.origin ||
          event.source != _frame.contentWindow ||
          event.data == null) {
        return;
      }
      final raw = event.data.dartify();
      if (raw is! String) return;
      try {
        final message = jsonDecode(raw);
        if (message is! Map || message['source'] != 'cas-classroom') return;
        if (message['type'] == 'ready') {
          // Credentials stay in memory; never put a room token in a URL or log.
          _frame.contentWindow?.postMessage(
            jsonEncode({
              'source': 'cas-lms',
              'type': 'connect',
              'url': widget.connection['url'],
              'token': widget.connection['token'],
              'title': widget.connection['title'],
              'instructor': widget.connection['instructor'],
            }).toJS,
            web.window.location.origin.toJS,
          );
        } else if (message['type'] == 'leave' && mounted) {
          widget.onLeave();
        }
      } catch (_) {
        // Ignore unrelated/malformed window messages.
      }
    }).toJS;
    web.window.addEventListener('message', _listener);
    ui_web.platformViewRegistry.registerViewFactory(_viewId, (_) => _frame);
  }

  @override
  void dispose() {
    web.window.removeEventListener('message', _listener);
    _frame.src = 'about:blank'; // Stops media tracks and the WebRTC connection.
    _frame.remove();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => HtmlElementView(viewType: _viewId);
}
