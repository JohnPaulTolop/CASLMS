import '../../core/app_colors.dart';

import 'dart:async';

import 'package:flutter/material.dart';

import '../../services/live_class_service.dart';
import '../../services/meeting_chat_service.dart';
import 'live_classroom_embed.dart';
import 'grading_ui.dart';
import 'meeting_chat_panel.dart';

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
        final responseLiveClassId = (response['liveClassId'] ?? '')
            .toString()
            .trim();
        final responseSessionId = (response['sessionId'] ?? '')
            .toString()
            .trim();
        final connection = <String, dynamic>{
          ...response,
          'liveClassId': responseLiveClassId.isNotEmpty
              ? responseLiveClassId
              : (_state?['liveClassId'] ?? '').toString().trim(),
          'sessionId': responseSessionId.isNotEmpty
              ? responseSessionId
              : (session?['sessionId'] ?? '').toString().trim(),
        };
        _inRoom = true;
        await Navigator.of(context).push(
          GradeRoute<void>(
            builder: (_) => _LiveRoomScreen(
              courseId: widget.courseId,
              sectionId: _state!['sectionId'] as String,
              connection: connection,
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
        ? AppColors.amber
        : gradeMuted;
    return Scaffold(
      backgroundColor: AppColors.resolve(context, gradeBackground),
      appBar: AppBar(
        backgroundColor: AppColors.resolve(context, Colors.white),
        surfaceTintColor: Colors.transparent,
        title: Text(
          'Live Classes',
          style: TextStyle(
            color: AppColors.resolve(context, gradeInk),
            fontSize: 18,
            fontWeight: FontWeight.w700,
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
                                  Icon(
                                    Icons.info_outline,
                                    color: AppColors.resolve(
                                      context,
                                      AppColors.error,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      _error!,
                                      style: TextStyle(
                                        color: AppColors.resolve(
                                          context,
                                          AppColors.error,
                                        ),
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
                                            style: TextStyle(
                                              color: AppColors.resolve(
                                                context,
                                                gradeInk,
                                              ),
                                              fontSize: 20,
                                              fontWeight: FontWeight.w700,
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
                                        style: TextStyle(
                                          color: AppColors.resolve(
                                            context,
                                            gradeInk,
                                          ),
                                          fontSize: 24,
                                          fontWeight: FontWeight.w700,
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
                                        style: TextStyle(
                                          color: AppColors.resolve(
                                            context,
                                            gradeMuted,
                                          ),
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
                                              style: TextStyle(
                                                color: AppColors.resolve(
                                                  context,
                                                  gradeInk,
                                                ),
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
                                          backgroundColor: AppColors.resolve(
                                            context,
                                            gradeBorder,
                                          ),
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
                                        Padding(
                                          padding: EdgeInsets.only(top: 8),
                                          child: Text(
                                            'Retry only if the room has been starting for over 3 minutes.',
                                            style: TextStyle(
                                              color: AppColors.resolve(
                                                context,
                                                gradeMuted,
                                              ),
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
                                      Text(
                                        'Bring your class together.',
                                        style: TextStyle(
                                          fontSize: 24,
                                          color: AppColors.resolve(
                                            context,
                                            gradeInk,
                                          ),
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      const SizedBox(height: 10),
                                      Text(
                                        'Give this session a title. Once started, enrolled students in this section can join.',
                                        style: TextStyle(
                                          color: AppColors.resolve(
                                            context,
                                            gradeMuted,
                                          ),
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
                                              Text(
                                                'See you in class.',
                                                style: TextStyle(
                                                  color: AppColors.resolve(
                                                    context,
                                                    gradeInk,
                                                  ),
                                                  fontWeight: FontWeight.w700,
                                                  fontSize: 24,
                                                ),
                                              ),
                                              const SizedBox(height: 10),
                                              Text(
                                                'No class is live right now. Your classroom will appear here when your instructor starts a session.',
                                                textAlign: TextAlign.center,
                                                style: TextStyle(
                                                  color: AppColors.resolve(
                                                    context,
                                                    gradeMuted,
                                                  ),
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
                                      Padding(
                                        padding: EdgeInsets.only(top: 20),
                                        child: Row(
                                          children: [
                                            Icon(
                                              Icons.sync_rounded,
                                              size: 16,
                                              color: AppColors.resolve(
                                                context,
                                                gradeMuted,
                                              ),
                                            ),
                                            SizedBox(width: 8),
                                            Expanded(
                                              child: Text(
                                                'Class status updates automatically every 15 seconds.',
                                                style: TextStyle(
                                                  color: AppColors.resolve(
                                                    context,
                                                    gradeMuted,
                                                  ),
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
                                    Text(
                                      'Before you join',
                                      style: TextStyle(
                                        fontSize: 17,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.resolve(
                                          context,
                                          gradeInk,
                                        ),
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
                                    Divider(
                                      color: AppColors.resolve(
                                        context,
                                        gradeBorder,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    GradeBadge(
                                      'Recording is off',
                                      color: AppColors.resolve(
                                        context,
                                        gradeMuted,
                                      ),
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
                    style: TextStyle(
                      color: AppColors.resolve(context, gradeInk),
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    description,
                    style: TextStyle(
                      color: AppColors.resolve(context, gradeMuted),
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
              backgroundColor: AppColors.resolve(context, AppColors.error),
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
  final _chatService = MeetingChatService();
  Timer? _poll;
  StreamSubscription<List<MeetingChatMessage>>? _chatSubscription;
  Stream<List<MeetingChatMessage>>? _panelChatMessages;
  late final String _sessionId;
  late final String _liveClassId;
  bool _ending = false;
  bool _checking = false;
  bool _leaving = false;
  bool _desktopChatOpen = false;
  bool _mobileChatVisible = false;
  bool _chatLayoutInitialized = false;
  bool _chatBaselineLoaded = false;
  String? _latestMessageId;
  int _unreadMessages = 0;

  @override
  void initState() {
    super.initState();
    _sessionId = (widget.connection['sessionId'] ?? '').toString();
    _liveClassId = (widget.connection['liveClassId'] ?? '').toString();
    _chatSubscription = _watchChatMessages().listen(
      _trackUnreadMessages,
      onError: (Object _) {},
    );
    _poll = Timer.periodic(const Duration(seconds: 20), (_) => _check());
  }

  Stream<List<MeetingChatMessage>> _watchChatMessages() {
    return _chatService.watchMessages(
      liveClassId: _liveClassId,
      courseId: widget.courseId,
      sectionId: widget.sectionId,
      sessionId: _sessionId,
    );
  }

  Stream<List<MeetingChatMessage>> get _visibleChatMessages {
    return _panelChatMessages ??= _watchChatMessages();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_chatLayoutInitialized) {
      _desktopChatOpen = MediaQuery.sizeOf(context).width >= 900;
      _chatLayoutInitialized = true;
    }
  }

  void _trackUnreadMessages(List<MeetingChatMessage> messages) {
    if (!_chatBaselineLoaded) {
      _chatBaselineLoaded = true;
      _latestMessageId = messages.isEmpty ? null : messages.last.id;
      return;
    }
    if (messages.isEmpty || messages.last.id == _latestMessageId) return;

    final previousIndex = _latestMessageId == null
        ? -1
        : messages.indexWhere((message) => message.id == _latestMessageId);
    final newMessages = messages
        .skip(previousIndex + 1)
        .where((message) => !message.isMine(_chatService.currentUserId));
    _latestMessageId = messages.last.id;
    if (!mounted || _desktopChatOpen || _mobileChatVisible) return;
    final count = newMessages.length;
    if (count > 0) {
      setState(() => _unreadMessages += count);
    }
  }

  void _setDesktopChat(bool open) {
    setState(() {
      _desktopChatOpen = open;
      if (!open) _panelChatMessages = null;
      if (open) _unreadMessages = 0;
    });
  }

  Future<void> _showMobileChat() async {
    if (_mobileChatVisible || !mounted) return;
    setState(() {
      _mobileChatVisible = true;
      _unreadMessages = 0;
    });
    final messages = _watchChatMessages();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: const Color(0xFF101A2D),
      builder: (sheetContext) => FractionallySizedBox(
        heightFactor: .82,
        child: MeetingChatPanel(
          service: _chatService,
          messages: messages,
          liveClassId: _liveClassId,
          courseId: widget.courseId,
          sectionId: widget.sectionId,
          sessionId: _sessionId,
          onClose: () => Navigator.of(sheetContext).pop(),
        ),
      ),
    );
    if (mounted) setState(() => _mobileChatVisible = false);
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
    _chatSubscription?.cancel();
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
        sessionId: _sessionId,
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
  Widget build(BuildContext context) {
    final desktop = MediaQuery.sizeOf(context).width >= 900;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return Scaffold(
      backgroundColor: AppColors.resolve(context, AppColors.darkText),
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
          IconButton(
            tooltip: desktop && _desktopChatOpen
                ? 'Close meeting chat'
                : 'Open meeting chat',
            onPressed: desktop
                ? () => _setDesktopChat(!_desktopChatOpen)
                : _showMobileChat,
            icon: Badge(
              isLabelVisible:
                  _unreadMessages > 0 &&
                  !(desktop ? _desktopChatOpen : _mobileChatVisible),
              label: Text(_unreadMessages > 99 ? '99+' : '$_unreadMessages'),
              child: Icon(
                desktop && _desktopChatOpen
                    ? Icons.forum_rounded
                    : Icons.forum_outlined,
              ),
            ),
          ),
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
            child: LayoutBuilder(
              builder: (context, constraints) {
                final chatWidth = desktop && _desktopChatOpen
                    ? (constraints.maxWidth * .32).clamp(320.0, 390.0)
                    : 0.0;
                return Row(
                  children: [
                    Expanded(
                      child: LiveClassroomEmbed(
                        connection: widget.connection,
                        onLeave: _leave,
                      ),
                    ),
                    AnimatedContainer(
                      duration: reduceMotion
                          ? Duration.zero
                          : const Duration(milliseconds: 220),
                      curve: Curves.easeOutCubic,
                      width: chatWidth,
                      decoration: const BoxDecoration(
                        border: Border(
                          left: BorderSide(color: Color(0xFF26354D)),
                        ),
                      ),
                      child: chatWidth == 0
                          ? const SizedBox.shrink()
                          : MeetingChatPanel(
                              service: _chatService,
                              messages: _visibleChatMessages,
                              liveClassId: _liveClassId,
                              courseId: widget.courseId,
                              sectionId: widget.sectionId,
                              sessionId: _sessionId,
                              onClose: () => _setDesktopChat(false),
                            ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
