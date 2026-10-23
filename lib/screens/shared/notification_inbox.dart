import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../services/notification_service.dart';

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
          return PopupMenuButton<String>(
            tooltip: snapshot.hasError
                ? 'Notifications unavailable'
                : 'Notifications',
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
              child: const Icon(Icons.notifications_none_rounded),
            ),
            itemBuilder: (context) => [
              for (final n in notices.take(6))
                PopupMenuItem<String>(
                  value: n['id'].toString(),
                  child: SizedBox(
                    width: 300,
                    child: NotificationPreview(notice: n),
                  ),
                ),
              if (notices.isEmpty)
                const PopupMenuItem<String>(
                  enabled: false,
                  child: Text('No notifications yet'),
                ),
              const PopupMenuDivider(),
              const PopupMenuItem<String>(
                value: '__history__',
                child: Text('View all notifications'),
              ),
            ],
          );
        },
      );
}

class NotificationPreview extends StatelessWidget {
  const NotificationPreview({super.key, required this.notice});
  final Map<String, dynamic> notice;
  @override
  Widget build(BuildContext context) {
    final unread = notice['isRead'] != true;
    final date = notice['createdAt'];
    final time = date is Timestamp
        ? date.toDate().toLocal().toString().substring(0, 16)
        : 'Just now';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (unread)
                const Padding(
                  padding: EdgeInsets.only(right: 8),
                  child: Icon(Icons.circle, size: 8, color: Colors.blue),
                ),
              Expanded(
                child: Text(
                  (notice['title'] ?? 'Notification').toString(),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: unread ? FontWeight.w800 : FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          Text(
            (notice['message'] ?? '').toString(),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          Text(time, style: Theme.of(context).textTheme.labelSmall),
        ],
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
  late final _stream = _service.watchMyNotifications();
  bool _busy = false;
  String _query = '';
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Notifications'),
      actions: [
        TextButton.icon(
          onPressed: _busy
              ? null
              : () async {
                  setState(() => _busy = true);
                  try {
                    await _service.markAllAsRead();
                  } catch (_) {
                    if (context.mounted) {
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
                },
          icon: _busy
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.done_all),
          label: const Text('Mark all read'),
        ),
      ],
    ),
    body: Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              labelText: 'Search notifications',
            ),
            onChanged: (value) => setState(() => _query = value.toLowerCase()),
          ),
        ),
        Expanded(
          child: StreamBuilder<List<Map<String, dynamic>>>(
            stream: _stream,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return const Center(
                  child: Text(
                    'Unable to load notifications. Please reopen this page.',
                  ),
                );
              }
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final notices = snapshot.data!
                  .where(
                    (n) => '${n['title']} ${n['message']}'
                        .toLowerCase()
                        .contains(_query),
                  )
                  .toList();
              if (notices.isEmpty) {
                return const Center(child: Text('No notifications found.'));
              }
              return ListView.builder(
                itemCount: notices.length,
                itemBuilder: (context, index) {
                  final notice = notices[index];
                  return Card(
                    color: notice['isRead'] == true
                        ? null
                        : const Color(0xFFEEF4FF),
                    margin: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 4,
                    ),
                    child: InkWell(
                      mouseCursor: SystemMouseCursors.click,
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => NotificationNavigation.open(
                        context,
                        notice['id'].toString(),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: NotificationPreview(notice: notice),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    ),
  );
}
