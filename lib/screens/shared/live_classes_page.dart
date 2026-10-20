import 'dart:async';

import 'package:flutter/material.dart';

import '../../services/live_class_service.dart';
import 'live_classroom_embed.dart';

class LiveClassesScreen extends StatefulWidget {
  const LiveClassesScreen({super.key, required this.courseId, this.sectionId});
  final String courseId;
  final String? sectionId;
  @override
  State<LiveClassesScreen> createState() => _LiveClassesScreenState();
}

class _LiveClassesScreenState extends State<LiveClassesScreen> {
  final _service = LiveClassService();
  final _title = TextEditingController(text: 'Live class');
  Map<String, dynamic>? _state;
  String? _error;
  bool _loading = true;
  bool _busy = false;
  bool _refreshing = false;
  bool _inRoom = false;
  Timer? _poll;

  @override
  void initState() {
    super.initState();
    _refresh();
    _poll = Timer.periodic(const Duration(seconds: 15), (_) {
      if (!_busy && !_inRoom && _state?['configured'] != false) {
        _refresh(silent: true);
      }
    });
  }

  @override
  void dispose() {
    _poll?.cancel();
    _title.dispose();
    super.dispose();
  }

  Future<void> _refresh({bool silent = false}) async {
    if (_refreshing) return;
    _refreshing = true;
    try {
      final state = await _service.request(
        action: 'state',
        courseId: widget.courseId,
        sectionId: widget.sectionId,
      );
      if (mounted) {
        setState(() {
          _state = state;
          _loading = false;
          _error = null;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = error.toString();
          _loading = false;
        });
      }
    } finally {
      _refreshing = false;
    }
  }

  Future<void> _act(String action) async {
    if (_busy) return;
    final session = _state?['session'] as Map?;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final response = await _service.request(
        action: action,
        courseId: widget.courseId,
        sectionId: widget.sectionId,
        sessionId: session?['sessionId'] as String?,
        title: _title.text.trim(),
      );
      if (!mounted) return;
      if (action == 'join') {
        _inRoom = true;
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => _LiveRoomScreen(
              courseId: widget.courseId,
              sectionId: _state!['sectionId'] as String,
              connection: response,
            ),
          ),
        );
        _inRoom = false;
      }
      await _refresh();
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = _state?['session'] as Map?;
    final status = session?['status'] as String?;
    final instructor = _state?['instructor'] == true;
    final configured = _state?['configured'] == true;
    return Scaffold(
      backgroundColor: const Color(0xFFF5F8FC),
      appBar: AppBar(
        title: const Text('Live Classes'),
        actions: [
          IconButton(
            tooltip: 'Refresh class',
            onPressed: _busy ? null : () => _refresh(),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 650),
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(28),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.video_call_rounded,
                            size: 52,
                            color: Color(0xFF1769FF),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            (_state?['courseTitle'] ?? 'Live classroom')
                                .toString(),
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            (_state?['sectionName'] ?? 'Your enrolled section')
                                .toString(),
                          ),
                          const SizedBox(height: 20),
                          const Text(
                            'Up to 30 students + 1 instructor',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Your place is reserved for this class when you join, so you can reconnect. Camera and microphone start off. Recording is off.',
                          ),
                          const SizedBox(height: 22),
                          if (_error != null)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 18),
                              child: Text(
                                _error!,
                                style: const TextStyle(color: Colors.red),
                              ),
                            ),
                          if (_state != null && !configured)
                            const Text(
                              'Live classes are not ready yet. The administrator needs to finish the video service setup.',
                            )
                          else if (_state != null) ...[
                            if (status == 'live' || status == 'ending') ...[
                              Text(
                                (session?['title'] ?? 'Live class').toString(),
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '${session?['studentCount'] ?? 0} / 30 student places reserved',
                              ),
                              const SizedBox(height: 18),
                              if (status == 'live')
                                FilledButton.icon(
                                  onPressed: _busy ? null : () => _act('join'),
                                  icon: const Icon(Icons.videocam_outlined),
                                  label: const Text('Join class'),
                                ),
                              if (instructor)
                                TextButton.icon(
                                  onPressed: _busy ? null : () => _act('end'),
                                  icon: const Icon(Icons.stop_circle_outlined),
                                  label: Text(
                                    status == 'ending'
                                        ? 'Retry ending class'
                                        : 'End class for everyone',
                                  ),
                                ),
                              if (status == 'ending')
                                const Text(
                                  'The instructor is closing this classroom.',
                                ),
                            ] else if (status == 'starting') ...[
                              const Text(
                                'The classroom is starting. This page will refresh automatically.',
                              ),
                              if (instructor)
                                TextButton(
                                  onPressed: _busy ? null : () => _act('start'),
                                  child: const Text(
                                    'Retry if the class has been starting for over 3 minutes',
                                  ),
                                ),
                            ] else if (instructor) ...[
                              TextField(
                                controller: _title,
                                maxLength: 100,
                                decoration: const InputDecoration(
                                  labelText: 'Class title',
                                  border: OutlineInputBorder(),
                                ),
                              ),
                              const SizedBox(height: 12),
                              FilledButton.icon(
                                onPressed: _busy ? null : () => _act('start'),
                                icon: const Icon(Icons.video_call),
                                label: const Text('Start live class'),
                              ),
                            ] else
                              const Text(
                                'No class is live right now. You can join here when your instructor starts one.',
                              ),
                          ],
                          if (_busy)
                            const Padding(
                              padding: EdgeInsets.only(top: 18),
                              child: LinearProgressIndicator(),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
    );
  }
}

class _LiveRoomScreen extends StatefulWidget {
  const _LiveRoomScreen({
    required this.courseId,
    required this.sectionId,
    required this.connection,
  });
  final String courseId;
  final String sectionId;
  final Map<String, dynamic> connection;
  @override
  State<_LiveRoomScreen> createState() => _LiveRoomScreenState();
}

class _LiveRoomScreenState extends State<_LiveRoomScreen> {
  final _service = LiveClassService();
  Timer? _poll;
  bool _ending = false;
  bool _checking = false;
  bool _leaving = false;

  @override
  void initState() {
    super.initState();
    _poll = Timer.periodic(const Duration(seconds: 20), (_) => _check());
  }

  Future<void> _check() async {
    if (_checking || _ending) return;
    _checking = true;
    try {
      final state = await _service.request(
        action: 'state',
        courseId: widget.courseId,
        sectionId: widget.sectionId,
      );
      final session = state['session'] as Map?;
      if (state['sectionId'] != widget.sectionId ||
          session?['sessionId'] != widget.connection['sessionId'] ||
          session?['status'] != 'live') {
        _leave();
      }
    } on LiveClassException catch (error) {
      if (error.status == 401 || error.status == 403) _leave();
      // Network errors are handled by WebRTC's reconnect UI. The backend never
      // issues a fresh room token without checking enrollment again.
    } finally {
      _checking = false;
    }
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  void _leave() {
    if (mounted && !_leaving) {
      _leaving = true;
      Navigator.of(context).pop();
    }
  }

  Future<void> _end() async {
    if (_ending) return;
    setState(() => _ending = true);
    try {
      await _service.request(
        action: 'end',
        courseId: widget.courseId,
        sectionId: widget.sectionId,
        sessionId: widget.connection['sessionId'] as String,
      );
      _leave();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.toString())));
      }
    } finally {
      if (mounted) setState(() => _ending = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFF101827),
    appBar: AppBar(
      title: Text((widget.connection['title'] ?? 'Live class').toString()),
      leading: IconButton(
        tooltip: 'Leave class',
        onPressed: _leave,
        icon: const Icon(Icons.arrow_back),
      ),
      actions: [
        if (widget.connection['instructor'] == true)
          TextButton(
            onPressed: _ending ? null : _end,
            child: Text(_ending ? 'Ending...' : 'End for everyone'),
          ),
        TextButton(onPressed: _leave, child: const Text('Leave')),
      ],
    ),
    body: LiveClassroomEmbed(connection: widget.connection, onLeave: _leave),
  );
}
