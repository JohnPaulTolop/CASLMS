import '../../core/app_colors.dart';
import 'workspace_widgets.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'workspace_shell.dart';

import '../../services/notification_service.dart';

const _ink = AppColors.darkText;
const _muted = AppColors.secondaryText;
const _accent = AppColors.primaryBlue;
const _border = AppColors.inputBorder;
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
  Widget build(BuildContext context) =>
      StreamBuilder<List<Map<String, dynamic>>>(
        stream: _stream,
        builder: (context, snapshot) {
          final notices = snapshot.data ?? [];
          final count = notices.where((n) => n['isRead'] != true).length;
          final width = (MediaQuery.sizeOf(context).width - 32).clamp(
            220.0,
            380.0,
          );
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
            color: AppColors.resolve(context, Colors.white),
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            shadowColor: _ink.withValues(alpha: .14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(color: AppColors.resolve(context, _border)),
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
              backgroundColor: AppColors.resolve(context, _accent),
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
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Notifications',
                              style: TextStyle(
                                color: AppColors.resolve(context, _ink),
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            SizedBox(height: 3),
                            Text(
                              'Your latest updates',
                              style: TextStyle(
                                color: AppColors.resolve(context, _muted),
                                fontSize: 12,
                              ),
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
                  child: Row(
                    children: [
                      Icon(
                        Icons.inbox_outlined,
                        size: 19,
                        color: AppColors.resolve(context, _accent),
                      ),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'View all notifications',
                          style: TextStyle(
                            color: AppColors.resolve(context, _accent),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      Icon(
                        Icons.arrow_forward_rounded,
                        size: 18,
                        color: AppColors.resolve(context, _accent),
                      ),
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
    final dark = Theme.of(context).brightness == Brightness.dark;
    final appearance = _NoticeAppearance.from(notice);
    final date = notice['createdAt'];
    final localDate = date is Timestamp ? date.toDate().toLocal() : null;
    return Ink(
      decoration: BoxDecoration(
        color: unread
            ? AppColors.resolve(context, AppColors.blueTint)
            : Colors.transparent,
        borderRadius: _radius,
        border: Border.all(
          color: unread
              ? dark
                    ? Theme.of(context).colorScheme.primary
                          .withValues(alpha: .4)
                    : const Color(0xFFBED4FA)
              : AppColors.resolve(context, _border).withValues(alpha: .5),
        ),
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
                            color: AppColors.resolve(context, _ink),
                            fontSize: compact ? 13 : 14,
                            height: 1.4,
                            fontWeight: unread
                                ? FontWeight.w700
                                : FontWeight.w600,
                          ),
                        ),
                      ),
                      if (unread) ...[
                        const SizedBox(width: 8),
                        Semantics(
                          label: 'Unread notification',
                          child: Padding(
                            padding: EdgeInsets.only(top: 6),
                            child: Icon(
                              Icons.circle,
                              size: 7,
                              color: AppColors.resolve(context, _accent),
                            ),
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
                    style: TextStyle(
                      color: AppColors.resolve(context, _muted),
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
                          style: TextStyle(
                            color: AppColors.resolve(context, _muted),
                            fontSize: 10.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (!compact) ...[
              const SizedBox(width: 8),
              Padding(
                padding: EdgeInsets.only(top: 10),
                child: Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.resolve(context, _muted),
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
  const NotificationInboxScreen({super.key, this.notifications});
  final Stream<List<Map<String, dynamic>>>? notifications;
  @override
  State<NotificationInboxScreen> createState() =>
      _NotificationInboxScreenState();
}

class _NotificationInboxScreenState extends State<NotificationInboxScreen> {
  late final _service = NotificationService();
  final _search = TextEditingController();
  late Stream<List<Map<String, dynamic>>> _stream;
  bool _busy = false;
  bool _unreadOnly = false;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _stream = widget.notifications ?? _service.watchMyNotifications();
  }

  void _retryNotifications() {
    setState(() {
      _stream = widget.notifications ?? _service.watchMyNotifications();
    });
  }

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
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final inset = workspaceInset(width);
    return Scaffold(
      backgroundColor: AppColors.resolve(context, AppColors.background),
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
              constraints: const BoxConstraints(maxWidth: 1450),
              child: CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(inset, 0, inset, 8),
                      child: const WorkspaceHeading(
                        showEyebrow: false,
                        title: 'Your inbox',
                        subtitle: 'Stay up to date with course, activity, and account updates.',
                        eyebrow: 'YOUR UPDATES',
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: EdgeInsets.fromLTRB(inset, 16, inset, 16),
                    sliver: SliverToBoxAdapter(
                      child: Container(
                        padding: EdgeInsets.all(width < 600 ? 16 : 24),
                        decoration: BoxDecoration(
                          color: AppColors.resolve(context, Colors.white),
                          border: Border.all(
                            color: AppColors.resolve(context, _border),
                          ),
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
                                    Text(
                                      'Stay in the loop',
                                      style: TextStyle(
                                        color: AppColors.resolve(context, _ink),
                                        fontSize: 21,
                                        letterSpacing: -0.5,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(height: 5),
                                    Text(
                                      '$unread unread / ${all.length} total updates',
                                      style: TextStyle(
                                        color: AppColors.resolve(
                                          context,
                                          _muted,
                                        ),
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
                                    side: BorderSide(
                                      color: AppColors.resolve(
                                        context,
                                        _border,
                                      ),
                                    ),
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
                                prefixIcon: Icon(
                                  Icons.search_rounded,
                                  color: AppColors.resolve(context, _muted),
                                ),
                                hintText: 'Search notifications',
                                filled: true,
                                fillColor: AppColors.resolve(
                                  context,
                                  AppColors.background,
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 14,
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(
                                    color: AppColors.resolve(context, _border),
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(
                                    color: AppColors.resolve(context, _accent),
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
                      padding: EdgeInsets.symmetric(horizontal: inset),
                      sliver: SliverToBoxAdapter(
                        child: snapshot.hasError
                            ? WorkspaceErrorState(
                                message: 'Unable to load notifications. Check your connection and try again.',
                                onRetry: _retryNotifications,
                              )
                            : waiting
                            ? const WorkspaceLoadingState(
                                label: 'Loading notifications…',
                              )
                            : _query.isNotEmpty
                            ? const WorkspaceEmptyState(
                                icon: Icons.search_off_rounded,
                                title: 'No matching notifications',
                                message: 'Try a different title or keyword.',
                              )
                            : WorkspaceEmptyState(
                                icon: Icons.notifications_none_rounded,
                                title: _unreadOnly
                                    ? 'You are all caught up'
                                    : 'No notifications yet',
                                message: _unreadOnly
                                    ? 'You have no unread updates.'
                                    : 'Course, activity, and account updates will appear here.',
                              ),
                      ),
                    )
                  else
                    SliverPadding(
                      padding: EdgeInsets.fromLTRB(inset, 0, inset, 24),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate((context, index) {
                          final notice = notices[index];
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Material(
                              key: ValueKey(notice['id']),
                              color: Colors.transparent,
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
  }

  Widget _filter(String label, bool selected, VoidCallback onSelected) =>
      ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onSelected(),
        showCheckmark: false,
        selectedColor: AppColors.resolve(context, AppColors.blueTint),
        backgroundColor: AppColors.resolve(context, Colors.white),
        side: BorderSide(
          color: selected
              ? Theme.of(context).brightness == Brightness.dark
                    ? Theme.of(context).colorScheme.primary
                          .withValues(alpha: .4)
                    : const Color(0xFFAFC9F7)
              : AppColors.resolve(context, _border),
        ),
        labelStyle: TextStyle(
          color: AppColors.resolve(context, selected ? _accent : _muted),
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
      color: AppColors.resolve(context, AppColors.background),
      borderRadius: _radius,
      border: Border.all(color: AppColors.resolve(context, _border)),
    ),
    child: Column(
      children: [
        Icon(icon, size: 30, color: AppColors.resolve(context, _muted)),
        const SizedBox(height: 12),
        Text(
          title,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppColors.resolve(context, _ink),
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          message,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppColors.resolve(context, _muted),
            fontSize: 12,
            height: 1.5,
          ),
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
        AppColors.green,
      );
    }
    if (has('grade') ||
        has('feedback') ||
        has('compliance') ||
        has('assessmentsubmission')) {
      return const _NoticeAppearance(
        'Scores',
        Icons.fact_check_outlined,
        AppColors.green,
      );
    }
    if (has('instructor') || has('approval')) {
      return const _NoticeAppearance(
        'Account',
        Icons.verified_user_outlined,
        AppColors.purple,
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
        AppColors.purple,
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
        AppColors.purple,
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
