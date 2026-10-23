import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../services/notification_service.dart';

const _ink = Color(0xFF17253D);
const _muted = Color(0xFF64748B);
const _accent = Color(0xFF2563EB);
const _border = Color(0xFFDDE5EF);
const _radius = BorderRadius.all(Radius.circular(16));

class NotificationNavigation {
  static bool _opening = false;
  static void open(BuildContext context, String id) {
    if (_opening || id.isEmpty) return;
    _opening = true;
    Navigator.of(context)
        .pushNamed('/notification?id=${Uri.encodeQueryComponent(id)}');
    // Only debounce the transition, not the whole lifetime of the destination.
    Future<void>.delayed(
      const Duration(milliseconds: 500),
      () => _opening = false,
    );
  }
}

class NotificationBell extends StatefulWidget {
  const NotificationBell({super.key});
  @override
  State<NotificationBell> createState() => _NotificationBellState();
}

class _NotificationBellState extends State<NotificationBell> {
  late final _stream = NotificationService().watchMyNotifications();

  @override
  Widget build(
    BuildContext context,
  ) => StreamBuilder<List<Map<String, dynamic>>>(
    stream: _stream,
    builder: (context, snapshot) {
      final notices = snapshot.data ?? [];
      final count = notices.where((n) => n['isRead'] != true).length;
      final width = (MediaQuery.sizeOf(context).width - 32).clamp(220.0, 380.0);
      final loading = !snapshot.hasData && !snapshot.hasError;
      return PopupMenuButton<String>(
        tooltip: snapshot.hasError
            ? 'Notifications unavailable'
            : 'Notifications${count > 0 ? ', $count unread' : ''}',
        position: PopupMenuPosition.under,
        offset: const Offset(0, 10),
        constraints: BoxConstraints(
          minWidth: width,
          maxWidth: width,
          maxHeight: (MediaQuery.sizeOf(context).height - 110).clamp(
            180.0,
            650.0,
          ),
        ),
        menuPadding: const EdgeInsets.symmetric(vertical: 8),
        color: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 8,
        shadowColor: _ink.withValues(alpha: .14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: _border),
        ),
        popUpAnimationStyle: AnimationStyle(
          duration: MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
        ),
        onSelected: (id) {
          if (id == '__history__') {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const NotificationInboxScreen(),
              ),
            );
          } else {
            NotificationNavigation.open(context, id);
          }
        },
        icon: Badge(
          isLabelVisible: count > 0,
          label: Text(count > 99 ? '99+' : '$count'),
          backgroundColor: _accent,
          child: const Icon(Icons.notifications_none_rounded),
        ),
        itemBuilder: (context) => [
          PopupMenuItem<String>(
            enabled: false,
            padding: const EdgeInsets.fromLTRB(18, 6, 18, 12),
            child: SizedBox(
              width: width - 36,
              child: Row(
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Notifications',
                          style: TextStyle(
                            color: _ink,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        SizedBox(height: 3),
                        Text(
                          'Your latest updates',
                          style: TextStyle(color: _muted, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  _Pill('$count unread', _accent),
                ],
              ),
            ),
          ),
          if (snapshot.hasError || loading || notices.isEmpty)
            PopupMenuItem<String>(
              enabled: false,
              padding: const EdgeInsets.all(12),
              child: SizedBox(
                width: width - 24,
                child: _InboxMessage(
                  compact: true,
                  icon: snapshot.hasError
                      ? Icons.cloud_off_outlined
                      : Icons.notifications_none_rounded,
                  title: snapshot.hasError
                      ? 'Unable to load updates'
                      : loading
                      ? 'Loading notifications...'
                      : 'You are all caught up',
                  message: snapshot.hasError
                      ? 'Reopen the bell to try again.'
                      : loading
                      ? 'Checking your latest updates.'
                      : 'New updates will appear here.',
                ),
              ),
            ),
          if (!snapshot.hasError)
            for (final n in notices.take(6))
              PopupMenuItem<String>(
                value: n['id'].toString(),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                child: SizedBox(
                  width: width - 20,
                  child: NotificationPreview(notice: n, compact: true),
                ),
              ),
          const PopupMenuDivider(height: 16),
          PopupMenuItem<String>(
            value: '__history__',
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: SizedBox(
              width: width - 36,
              child: const Row(
                children: [
                  Icon(Icons.inbox_outlined, size: 19, color: _accent),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'View all notifications',
                      style: TextStyle(
                        color: _accent,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Icon(Icons.arrow_forward_rounded, size: 18, color: _accent),
                ],
              ),
            ),
          ),
        ],
      );
    },
  );
}

class NotificationPreview extends StatelessWidget {
  const NotificationPreview({
    super.key,
    required this.notice,
    this.compact = false,
  });
  final Map<String, dynamic> notice;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final unread = notice['isRead'] != true;
    final appearance = _NoticeAppearance.from(notice);
    final date = notice['createdAt'];
    final localDate = date is Timestamp ? date.toDate().toLocal() : null;
    return Ink(
      decoration: BoxDecoration(
        color: unread ? const Color(0xFFF0F6FF) : Colors.white,
        borderRadius: _radius,
        border: Border.all(color: unread ? const Color(0xFFBED4FA) : _border),
      ),
      child: Padding(
        padding: EdgeInsets.all(compact ? 12 : 16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: compact ? 34 : 42,
              height: compact ? 34 : 42,
              decoration: BoxDecoration(
                color: appearance.color.withValues(alpha: .10),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: appearance.color.withValues(alpha: .16),
                ),
              ),
              child: Icon(
                appearance.icon,
                size: compact ? 18 : 21,
                color: appearance.color,
              ),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          (notice['title'] ?? 'Notification').toString(),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: _ink,
                            fontSize: compact ? 13 : 14,
                            height: 1.4,
                            fontWeight: unread
                                ? FontWeight.w800
                                : FontWeight.w600,
                          ),
                        ),
                      ),
                      if (unread) ...[
                        const SizedBox(width: 8),
                        Semantics(
                          label: 'Unread notification',
                          child: const Padding(
                            padding: EdgeInsets.only(top: 6),
                            child: Icon(Icons.circle, size: 7, color: _accent),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 5),
                  Text(
                    (notice['message'] ?? '').toString(),
                    maxLines: compact ? 2 : 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _muted,
                      fontSize: 12,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      _Pill(appearance.label, appearance.color),
                      Tooltip(
                        message:
                            localDate?.toString().substring(0, 16) ??
                            'Awaiting timestamp',
                        child: Text(
                          _noticeTime(localDate),
                          style: const TextStyle(color: _muted, fontSize: 10.5),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (!compact) ...[
              const SizedBox(width: 8),
              const Padding(
                padding: EdgeInsets.only(top: 10),
                child: Icon(
                  Icons.chevron_right_rounded,
                  color: _muted,
                  size: 20,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class NotificationInboxScreen extends StatefulWidget {
  const NotificationInboxScreen({super.key});
  @override
  State<NotificationInboxScreen> createState() =>
      _NotificationInboxScreenState();
}

class _NotificationInboxScreenState extends State<NotificationInboxScreen> {
  final _service = NotificationService();
  final _search = TextEditingController();
  late final _stream = _service.watchMyNotifications();
  bool _busy = false;
  bool _unreadOnly = false;
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _markAllRead() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await _service.markAllAsRead();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Unable to mark notifications as read. Please retry.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFFF5F7FB),
    appBar: AppBar(
      title: const Text(
        'Notifications',
        style: TextStyle(fontWeight: FontWeight.w700),
      ),
      backgroundColor: Colors.white,
      foregroundColor: _ink,
      surfaceTintColor: Colors.transparent,
      bottom: const PreferredSize(
        preferredSize: Size.fromHeight(1),
        child: Divider(height: 1, color: _border),
      ),
    ),
    body: StreamBuilder<List<Map<String, dynamic>>>(
      stream: _stream,
      builder: (context, snapshot) {
        final all = snapshot.data ?? [];
        final unread = all.where((n) => n['isRead'] != true).length;
        final notices = all
            .where(
              (n) =>
                  (!_unreadOnly || n['isRead'] != true) &&
                  '${n['title'] ?? ''} ${n['message'] ?? ''}'
                      .toLowerCase()
                      .contains(_query),
            )
            .toList();
        final waiting = !snapshot.hasData && !snapshot.hasError;
        return Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 920),
            child: CustomScrollView(
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
                  sliver: SliverToBoxAdapter(
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(color: _border),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            spacing: 16,
                            runSpacing: 14,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Your inbox',
                                    style: TextStyle(
                                      color: _ink,
                                      fontSize: 22,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(height: 5),
                                  Text(
                                    '$unread unread / ${all.length} total updates',
                                    style: const TextStyle(
                                      color: _muted,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                              OutlinedButton.icon(
                                onPressed:
                                    _busy || unread == 0 || snapshot.hasError
                                    ? null
                                    : _markAllRead,
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: _accent,
                                  side: const BorderSide(color: _border),
                                  minimumSize: const Size(0, 42),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                icon: _busy
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Icon(
                                        Icons.done_all_rounded,
                                        size: 18,
                                      ),
                                label: const Text('Mark all as read'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          TextField(
                            controller: _search,
                            decoration: InputDecoration(
                              prefixIcon: const Icon(
                                Icons.search_rounded,
                                color: _muted,
                              ),
                              hintText: 'Search notifications',
                              filled: true,
                              fillColor: const Color(0xFFF8FAFC),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 14,
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(color: _border),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(
                                  color: _accent,
                                  width: 1.5,
                                ),
                              ),
                              suffixIcon: _query.isEmpty
                                  ? null
                                  : IconButton(
                                      tooltip: 'Clear search',
                                      icon: const Icon(
                                        Icons.close_rounded,
                                        size: 18,
                                      ),
                                      onPressed: () {
                                        _search.clear();
                                        setState(() => _query = '');
                                      },
                                    ),
                            ),
                            onChanged: (value) => setState(
                              () => _query = value.trim().toLowerCase(),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Wrap(
                            spacing: 10,
                            runSpacing: 8,
                            children: [
                              _filter(
                                'All (${all.length})',
                                !_unreadOnly,
                                () => setState(() => _unreadOnly = false),
                              ),
                              _filter(
                                'Unread ($unread)',
                                _unreadOnly,
                                () => setState(() => _unreadOnly = true),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                if (snapshot.hasError || waiting || notices.isEmpty)
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    sliver: SliverToBoxAdapter(
                      child: _InboxMessage(
                        icon: snapshot.hasError
                            ? Icons.cloud_off_outlined
                            : _query.isNotEmpty
                            ? Icons.search_off_rounded
                            : Icons.notifications_none_rounded,
                        title: snapshot.hasError
                            ? 'Notifications unavailable'
                            : waiting
                            ? 'Loading your updates...'
                            : _query.isNotEmpty
                            ? 'No matching notifications'
                            : _unreadOnly
                            ? 'You are all caught up'
                            : 'No notifications yet',
                        message: snapshot.hasError
                            ? 'Check your connection and reopen this page.'
                            : waiting
                            ? 'Your latest updates will appear shortly.'
                            : _query.isNotEmpty
                            ? 'Try a different title or keyword.'
                            : _unreadOnly
                            ? 'You have no unread updates.'
                            : 'Course, activity and account updates will appear here.',
                      ),
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate((context, index) {
                        final notice = notices[index];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Material(
                            key: ValueKey(notice['id']),
                            color: Colors.white,
                            borderRadius: _radius,
                            clipBehavior: Clip.antiAlias,
                            child: InkWell(
                              mouseCursor: SystemMouseCursors.click,
                              borderRadius: _radius,
                              hoverColor: _accent.withValues(alpha: .04),
                              focusColor: _accent.withValues(alpha: .10),
                              onTap: () => NotificationNavigation.open(
                                context,
                                notice['id'].toString(),
                              ),
                              child: NotificationPreview(notice: notice),
                            ),
                          ),
                        );
                      }, childCount: notices.length),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    ),
  );

  Widget _filter(String label, bool selected, VoidCallback onSelected) =>
      ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onSelected(),
        showCheckmark: false,
        selectedColor: const Color(0xFFEAF1FF),
        backgroundColor: Colors.white,
        side: BorderSide(color: selected ? const Color(0xFFAFC9F7) : _border),
        labelStyle: TextStyle(
          color: selected ? _accent : _muted,
          fontWeight: FontWeight.w700,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      );
}

class _Pill extends StatelessWidget {
  const _Pill(this.label, this.color);
  final String label;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .08),
      borderRadius: BorderRadius.circular(7),
    ),
    child: Text(
      label,
      style: TextStyle(
        color: color,
        fontSize: 10,
        fontWeight: FontWeight.w700,
        height: 1.2,
      ),
    ),
  );
}

class _InboxMessage extends StatelessWidget {
  const _InboxMessage({
    required this.icon,
    required this.title,
    required this.message,
    this.compact = false,
  });
  final IconData icon;
  final String title, message;
  final bool compact;
  @override
  Widget build(BuildContext context) => Container(
    padding: EdgeInsets.all(compact ? 20 : 36),
    decoration: BoxDecoration(
      color: const Color(0xFFF8FAFC),
      borderRadius: _radius,
      border: Border.all(color: _border),
    ),
    child: Column(
      children: [
        Icon(icon, size: 30, color: _muted),
        const SizedBox(height: 12),
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(color: _ink, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(color: _muted, fontSize: 12, height: 1.5),
        ),
      ],
    ),
  );
}

class _NoticeAppearance {
  const _NoticeAppearance(this.label, this.icon, this.color);
  final String label;
  final IconData icon;
  final Color color;
  factory _NoticeAppearance.from(Map<String, dynamic> notice) {
    final kind = '${notice['sourceType'] ?? ''} ${notice['type'] ?? ''}'
        .toLowerCase();
    bool has(String value) => kind.contains(value);
    if (has('received') ||
        has('submissionreceived') ||
        notice['type'] == 'submission') {
      return const _NoticeAppearance(
        'Submission',
        Icons.assignment_turned_in_outlined,
        Color(0xFF0F766E),
      );
    }
    if (has('grade') ||
        has('feedback') ||
        has('compliance') ||
        has('assessmentsubmission')) {
      return const _NoticeAppearance(
        'Scores',
        Icons.fact_check_outlined,
        Color(0xFF0F766E),
      );
    }
    if (has('instructor') || has('approval')) {
      return const _NoticeAppearance(
        'Account',
        Icons.verified_user_outlined,
        Color(0xFF7C3AED),
      );
    }
    if (has('message') || has('conversation')) {
      return const _NoticeAppearance(
        'Message',
        Icons.chat_bubble_outline_rounded,
        _accent,
      );
    }
    if (has('liveclass') || has('schedule')) {
      return const _NoticeAppearance(
        'Class update',
        Icons.videocam_outlined,
        Color(0xFF7C3AED),
      );
    }
    if (has('announcement')) {
      return const _NoticeAppearance(
        'Announcement',
        Icons.campaign_outlined,
        Color(0xFFB45309),
      );
    }
    if (has('resource') || has('material')) {
      return const _NoticeAppearance(
        'Learning material',
        Icons.description_outlined,
        Color(0xFF7C3AED),
      );
    }
    if (has('quiz')) {
      return const _NoticeAppearance('Quiz', Icons.quiz_outlined, _accent);
    }
    if (has('assessment') ||
        has('assignment') ||
        has('activity') ||
        has('exam')) {
      return const _NoticeAppearance(
        'Assessment',
        Icons.assignment_outlined,
        _accent,
      );
    }
    if (has('course') || has('enrollment') || has('module')) {
      return const _NoticeAppearance(
        'Course update',
        Icons.menu_book_outlined,
        _accent,
      );
    }
    return const _NoticeAppearance(
      'Update',
      Icons.notifications_none_rounded,
      _muted,
    );
  }
}

String _noticeTime(DateTime? date) {
  if (date == null) return 'Just now';
  final now = DateTime.now();
  final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
  final clock =
      '$hour:${date.minute.toString().padLeft(2, '0')} ${date.hour < 12 ? 'AM' : 'PM'}';
  if (DateUtils.isSameDay(now, date)) return 'Today, $clock';
  if (DateUtils.isSameDay(DateTime(now.year, now.month, now.day - 1), date)) {
    return 'Yesterday, $clock';
  }
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${date.day} ${months[date.month - 1]}${date.year == now.year ? '' : ' ${date.year}'}, $clock';
}
