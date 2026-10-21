import 'dart:async';

import 'package:flutter/material.dart';

import '../../services/live_class_service.dart';
import 'live_classroom_embed.dart';
import 'grading_ui.dart';

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
    if (action == 'end' && !await _confirmEndClass(context)) return;
    if (!mounted) return;
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
          GradeRoute<void>(
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
    final live = status == 'live';
    final transitioning = status == 'starting' || status == 'ending';
    final accent = instructor ? gradeTeal : gradeBlue;
    final count = (session?['studentCount'] as num?)?.toInt() ?? 0;
    final stateLabel = !configured
        ? 'Setup pending'
        : live
        ? 'Live now'
        : status == 'starting'
        ? 'Starting'
        : status == 'ending'
        ? 'Ending'
        : 'No active session';
    final stateColor = live
        ? gradeTeal
        : transitioning
        ? const Color(0xFFB76A00)
        : gradeMuted;
    return Scaffold(
      backgroundColor: gradeBackground,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        title: const Text(
          'Live Classes',
          style: TextStyle(
            color: gradeInk,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
        actions: [
          RoundGradeAction(
            icon: Icons.refresh_rounded,
            label: 'Refresh class',
            accent: accent,
            onTap: _busy ? null : () => _refresh(),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () => _refresh(),
              child: LayoutBuilder(
                builder: (context, size) => SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: EdgeInsets.all(size.maxWidth < 600 ? 16 : 28),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1120),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          GradeEntrance(
                            child: GradeHero(
                              title:
                                  (_state?['courseTitle'] ??
                                          'Your live classroom')
                                      .toString(),
                              subtitle:
                                  '${_state?['sectionName'] ?? 'Your enrolled section'} · Learn together, wherever you are.',
                              icon: Icons.video_call_outlined,
                              accent: accent,
                              eyebrow: instructor
                                  ? 'TEACH & CONNECT'
                                  : 'LEARN & CONNECT',
                              trailing: const GradeBadge(
                                '30 students + 1 instructor',
                                color: Colors.white,
                                icon: Icons.groups_outlined,
                              ),
                            ),
                          ),
                          const SizedBox(height: 22),
                          if (_error != null) ...[
                            GradeSurface(
                              padding: const EdgeInsets.all(18),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Icon(
                                    Icons.info_outline,
                                    color: Color(0xFFC54444),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      _error!,
                                      style: const TextStyle(
                                        color: Color(0xFFC54444),
                                        height: 1.5,
                                      ),
                                    ),
                                  ),
                                  TextButton(
                                    onPressed: _busy ? null : () => _refresh(),
                                    child: const Text('Retry'),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],
                          LayoutBuilder(
                            builder: (context, width) {
                              final sessionPanel = GradeSurface(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            instructor
                                                ? 'Your classroom'
                                                : 'Join your classroom',
                                            style: const TextStyle(
                                              color: gradeInk,
                                              fontSize: 20,
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        GradeBadge(
                                          stateLabel,
                                          color: stateColor,
                                          icon: live
                                              ? Icons.radio_button_checked
                                              : Icons.schedule_rounded,
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 22),
                                    if (_state == null)
                                      const GradeStateMessage(
                                        title: 'Class details unavailable',
                                        message:
                                            'Refresh to load your classroom.',
                                        icon: Icons.cloud_off_outlined,
                                      )
                                    else if (!configured)
                                      const GradeStateMessage(
                                        title:
                                            'Your classroom is being prepared',
                                        message: 'The administrator needs to finish setting up the video service. Check back here when it is ready.',
                                        icon: Icons.video_settings_outlined,
                                      )
                                    else if (live || transitioning) ...[
                                      Text(
                                        (session?['title'] ?? 'Live class')
                                            .toString(),
                                        style: const TextStyle(
                                          color: gradeInk,
                                          fontSize: 24,
                                          fontWeight: FontWeight.w800,
                                          height: 1.3,
                                        ),
                                      ),
                                      const SizedBox(height: 10),
                                      Text(
                                        live
                                            ? 'The room is open. Join when you are ready.'
                                            : status == 'starting'
                                            ? 'Getting the room ready. This page updates automatically.'
                                            : 'The instructor is closing this classroom.',
                                        style: const TextStyle(
                                          color: gradeMuted,
                                          height: 1.6,
                                          fontSize: 13,
                                        ),
                                      ),
                                      const SizedBox(height: 24),
                                      Row(
                                        children: [
                                          Icon(
                                            Icons.groups_outlined,
                                            color: accent,
                                            size: 21,
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: Text(
                                              '$count of 30 student places reserved',
                                              style: const TextStyle(
                                                color: gradeInk,
                                                fontWeight: FontWeight.w700,
                                                fontSize: 13,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 12),
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(6),
                                        child: LinearProgressIndicator(
                                          value: (count / 30).clamp(0.0, 1.0),
                                          minHeight: 7,
                                          color: accent,
                                          backgroundColor: gradeBorder,
                                        ),
                                      ),
                                      const SizedBox(height: 24),
                                      if (live)
                                        SizedBox(
                                          width: double.infinity,
                                          child: FilledButton.icon(
                                            style: FilledButton.styleFrom(
                                              backgroundColor: accent,
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    vertical: 20,
                                                  ),
                                            ),
                                            onPressed: _busy
                                                ? null
                                                : () => _act('join'),
                                            icon: const Icon(
                                              Icons.login_rounded,
                                            ),
                                            label: Text(
                                              _busy
                                                  ? 'Please wait...'
                                                  : 'Join class',
                                            ),
                                          ),
                                        ),
                                      if (status == 'starting' && instructor)
                                        OutlinedButton.icon(
                                          onPressed: _busy
                                              ? null
                                              : () => _act('start'),
                                          icon: const Icon(
                                            Icons.refresh_rounded,
                                          ),
                                          label: const Text(
                                            'Retry starting class',
                                          ),
                                        ),
                                      if (status == 'starting' && instructor)
                                        const Padding(
                                          padding: EdgeInsets.only(top: 8),
                                          child: Text(
                                            'Retry only if the room has been starting for over 3 minutes.',
                                            style: TextStyle(
                                              color: gradeMuted,
                                              fontSize: 12,
                                              height: 1.5,
                                            ),
                                          ),
                                        ),
                                      if (instructor && status != 'starting')
                                        Padding(
                                          padding: const EdgeInsets.only(
                                            top: 12,
                                          ),
                                          child: TextButton.icon(
                                            style: TextButton.styleFrom(
                                              foregroundColor: const Color(
                                                0xFFC54444,
                                              ),
                                            ),
                                            onPressed: _busy
                                                ? null
                                                : () => _act('end'),
                                            icon: const Icon(
                                              Icons.stop_circle_outlined,
                                              size: 19,
                                            ),
                                            label: Text(
                                              status == 'ending'
                                                  ? 'Retry ending class'
                                                  : 'End class for everyone',
                                            ),
                                          ),
                                        ),
                                    ] else if (instructor) ...[
                                      const Text(
                                        'Bring your class together.',
                                        style: TextStyle(
                                          fontSize: 24,
                                          color: gradeInk,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                      const SizedBox(height: 10),
                                      const Text(
                                        'Give this session a title. Once started, enrolled students in this section can join.',
                                        style: TextStyle(
                                          color: gradeMuted,
                                          fontSize: 13,
                                          height: 1.6,
                                        ),
                                      ),
                                      const SizedBox(height: 24),
                                      TextField(
                                        controller: _title,
                                        enabled: !_busy,
                                        maxLength: 100,
                                        textInputAction: TextInputAction.done,
                                        decoration: gradeInput(
                                          'Class title',
                                          icon: Icons.edit_outlined,
                                          hint: 'e.g. Unit 2 discussion',
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      SizedBox(
                                        width: double.infinity,
                                        child: FilledButton.icon(
                                          style: FilledButton.styleFrom(
                                            backgroundColor: accent,
                                            padding: const EdgeInsets.symmetric(
                                              vertical: 20,
                                            ),
                                          ),
                                          onPressed: _busy
                                              ? null
                                              : () => _act('start'),
                                          icon: const Icon(
                                            Icons.video_call_outlined,
                                          ),
                                          label: Text(
                                            _busy
                                                ? 'Starting classroom...'
                                                : 'Start live class',
                                          ),
                                        ),
                                      ),
                                    ] else ...[
                                      Center(
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 16,
                                          ),
                                          child: Column(
                                            children: [
                                              CircleAvatar(
                                                radius: 38,
                                                backgroundColor: accent
                                                    .withValues(alpha: .08),
                                                child: Icon(
                                                  Icons
                                                      .event_available_outlined,
                                                  size: 34,
                                                  color: accent,
                                                ),
                                              ),
                                              const SizedBox(height: 20),
                                              const Text(
                                                'See you in class.',
                                                style: TextStyle(
                                                  color: gradeInk,
                                                  fontWeight: FontWeight.w800,
                                                  fontSize: 24,
                                                ),
                                              ),
                                              const SizedBox(height: 10),
                                              const Text(
                                                'No class is live right now. Your classroom will appear here when your instructor starts a session.',
                                                textAlign: TextAlign.center,
                                                style: TextStyle(
                                                  color: gradeMuted,
                                                  height: 1.6,
                                                  fontSize: 13,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                    if (_busy)
                                      const Padding(
                                        padding: EdgeInsets.only(top: 18),
                                        child: LinearProgressIndicator(),
                                      ),
                                    if (configured)
                                      const Padding(
                                        padding: EdgeInsets.only(top: 20),
                                        child: Row(
                                          children: [
                                            Icon(
                                              Icons.sync_rounded,
                                              size: 16,
                                              color: gradeMuted,
                                            ),
                                            SizedBox(width: 8),
                                            Expanded(
                                              child: Text(
                                                'Class status updates automatically every 15 seconds.',
                                                style: TextStyle(
                                                  color: gradeMuted,
                                                  fontSize: 11,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                  ],
                                ),
                              );
                              final guide = GradeSurface(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Before you join',
                                      style: TextStyle(
                                        fontSize: 17,
                                        fontWeight: FontWeight.w800,
                                        color: gradeInk,
                                      ),
                                    ),
                                    const SizedBox(height: 20),
                                    _tip(
                                      Icons.mic_off_outlined,
                                      'Start quietly',
                                      'Your microphone and camera start off. Turn them on when you are ready.',
                                      accent,
                                    ),
                                    _tip(
                                      Icons.headphones_outlined,
                                      'Hear clearly',
                                      'Use headphones to reduce echo. Enable sound inside the room if needed.',
                                      accent,
                                    ),
                                    _tip(
                                      Icons.wifi_rounded,
                                      'Stay connected',
                                      'Your reserved place lets you rejoin the same session if your connection drops.',
                                      accent,
                                    ),
                                    _tip(
                                      instructor
                                          ? Icons.present_to_all_rounded
                                          : Icons.groups_outlined,
                                      instructor
                                          ? 'Present to your class'
                                          : 'Learn together',
                                      instructor
                                          ? 'Share your screen from inside the room. End the session when everyone is done.'
                                          : 'Open Participants to see who is in the classroom.',
                                      accent,
                                    ),
                                    const Divider(color: gradeBorder),
                                    const SizedBox(height: 8),
                                    const GradeBadge(
                                      'Recording is off',
                                      color: gradeMuted,
                                      icon: Icons.shield_outlined,
                                    ),
                                  ],
                                ),
                              );
                              return width.maxWidth < 850
                                  ? Column(
                                      children: [
                                        sessionPanel,
                                        const SizedBox(height: 16),
                                        guide,
                                      ],
                                    )
                                  : Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Expanded(flex: 3, child: sessionPanel),
                                        const SizedBox(width: 20),
                                        Expanded(flex: 2, child: guide),
                                      ],
                                    );
                            },
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

  Widget _tip(IconData icon, String title, String description, Color accent) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 22),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: accent.withValues(alpha: .08),
              child: Icon(icon, size: 19, color: accent),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: gradeInk,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    description,
                    style: const TextStyle(
                      color: gradeMuted,
                      fontSize: 12,
                      height: 1.6,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
}

Future<bool> _confirmEndClass(BuildContext context) async =>
    await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('End class for everyone?'),
        content: const Text(
          'All participants will be disconnected. To meet again, start a new live class.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog, false),
            child: const Text('Keep class open'),
          ),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFC54444),
            ),
            onPressed: () => Navigator.pop(dialog, true),
            icon: const Icon(Icons.call_end_rounded, size: 18),
            label: const Text('End class'),
          ),
        ],
      ),
    ) ??
    false;

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
      final route = ModalRoute.of(context);
      final navigator = Navigator.of(context);
      // Close an open confirmation before leaving the classroom route.
      if (route != null) navigator.popUntil((candidate) => candidate == route);
      navigator.pop();
    }
  }

  Future<void> _end() async {
    if (_ending) return;
    if (!await _confirmEndClass(context) || !mounted) return;
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
    backgroundColor: const Color(0xFF0B1120),
    appBar: AppBar(
      backgroundColor: const Color(0xFF101A2D),
      foregroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      leading: IconButton(
        tooltip: 'Back to Live Classes',
        onPressed: _leave,
        icon: const Icon(Icons.arrow_back_rounded),
      ),
      title: const Text(
        'Live classroom',
        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
      ),
      actions: [
        if (widget.connection['instructor'] == true)
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: RoundGradeAction(
              icon: Icons.stop_circle_outlined,
              label: _ending ? 'Ending class...' : 'End class for everyone',
              accent: const Color(0xFFFF8797),
              onTap: _ending ? null : _end,
            ),
          ),
        Padding(
          padding: const EdgeInsets.only(right: 12),
          child: TextButton.icon(
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFFCBDAEF),
            ),
            onPressed: _leave,
            icon: const Icon(Icons.logout_rounded, size: 18),
            label: const Text('Leave'),
          ),
        ),
      ],
    ),
    body: Column(
      children: [
        if (_ending) const LinearProgressIndicator(minHeight: 2),
        Expanded(
          child: LiveClassroomEmbed(
            connection: widget.connection,
            onLeave: _leave,
          ),
        ),
      ],
    ),
  );
}
