import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../services/notification_service.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({
    super.key,
  });

  @override
  State<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState
    extends State<NotificationsScreen> {
  // ============================================================
  // DESIGN SYSTEM
  // ============================================================

  static const Color primaryBlue =
      Color(0xFF1769FF);

  static const Color background =
      Color(0xFFF7F9FC);

  static const Color textDark =
      Color(0xFF10182F);

  static const Color textGrey =
      Color(0xFF68738A);

  static const Color orange =
      Color(0xFFFF9418);

  // ============================================================
  // SERVICE
  // ============================================================

  final NotificationService _notificationService =
      NotificationService();

  // ============================================================
  // STATE
  // ============================================================

  String _searchQuery =
      '';

  bool _isMarkingAll =
      false;

  // ============================================================
  // MARK ALL AS READ
  // ============================================================

  Future<void> _markAllAsRead() async {
    if (_isMarkingAll) {
      return;
    }

    setState(() {
      _isMarkingAll =
          true;
    });

    try {
      await _notificationService
          .markAllAsRead();

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content: Text(
            'All notifications marked as read.',
          ),
          behavior:
              SnackBarBehavior.floating,
        ),
      );
    } on NotificationServiceException catch (e) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          content:
              Text(e.message),
          backgroundColor:
              Colors.redAccent,
          behavior:
              SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isMarkingAll =
              false;
        });
      }
    }
  }

  // ============================================================
  // MARK ONE AS READ
  // ============================================================

  Future<void> _markAsRead(
    Map<String, dynamic> notification,
  ) async {
    if (notification['isRead'] ==
        true) {
      return;
    }

    final String notificationId =
        (notification['id'] ?? '')
            .toString();

    if (notificationId.isEmpty) {
      return;
    }

    try {
      await _notificationService
          .markAsRead(
        notificationId,
      );
    } on NotificationServiceException catch (e) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          content:
              Text(e.message),
          backgroundColor:
              Colors.redAccent,
        ),
      );
    }
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor:
          background,

      appBar:
          AppBar(
        backgroundColor:
            background,

        foregroundColor:
            textDark,

        elevation:
            0,

        title:
            const Text(
          'Notifications',
          style:
              TextStyle(
            color:
                textDark,
            fontSize:
                20,
            fontWeight:
                FontWeight.w800,
          ),
        ),

        actions: [
          IconButton(
            tooltip:
                'Mark all as read',

            onPressed:
                _isMarkingAll
                    ? null
                    : _markAllAsRead,

            icon:
                _isMarkingAll
                    ? const SizedBox(
                        width:
                            19,
                        height:
                            19,
                        child:
                            CircularProgressIndicator(
                          strokeWidth:
                              2,
                          color:
                              primaryBlue,
                        ),
                      )
                    : const Icon(
                        Icons
                            .done_all_rounded,
                        color:
                            primaryBlue,
                      ),
          ),

          const SizedBox(
            width:
                8,
          ),
        ],
      ),

      body:
          SafeArea(
        child:
            Align(
          alignment:
              Alignment.topCenter,

          child:
              ConstrainedBox(
            constraints:
                const BoxConstraints(
              maxWidth:
                  1000,
            ),

            child:
                Column(
              children: [
                // ================================================
                // SEARCH
                // ================================================

                Padding(
                  padding:
                      const EdgeInsets.fromLTRB(
                    24,
                    14,
                    24,
                    10,
                  ),

                  child:
                      TextField(
                    onChanged:
                        (value) {
                      setState(() {
                        _searchQuery =
                            value;
                      });
                    },

                    decoration:
                        InputDecoration(
                      hintText:
                          'Search notifications...',

                      prefixIcon:
                          const Icon(
                        Icons
                            .search_rounded,
                        color:
                            primaryBlue,
                      ),

                      filled:
                          true,

                      fillColor:
                          Colors.white,

                      border:
                          OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(
                          16,
                        ),
                        borderSide:
                            const BorderSide(
                          color:
                              Color(
                            0xFFE3E7EE,
                          ),
                        ),
                      ),

                      enabledBorder:
                          OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(
                          16,
                        ),
                        borderSide:
                            const BorderSide(
                          color:
                              Color(
                            0xFFE3E7EE,
                          ),
                        ),
                      ),

                      focusedBorder:
                          OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(
                          16,
                        ),
                        borderSide:
                            const BorderSide(
                          color:
                              primaryBlue,
                          width:
                              1.5,
                        ),
                      ),
                    ),
                  ),
                ),

                // ================================================
                // LIVE FIRESTORE NOTIFICATIONS
                // ================================================

                Expanded(
                  child:
                      StreamBuilder<
                          List<
                              Map<
                                  String,
                                  dynamic>>>(
                    stream:
                        _notificationService
                            .watchMyNotifications(),

                    builder:
                        (
                      context,
                      snapshot,
                    ) {
                      if (snapshot.connectionState ==
                              ConnectionState.waiting &&
                          !snapshot.hasData) {
                        return const Center(
                          child:
                              CircularProgressIndicator(
                            color:
                                primaryBlue,
                          ),
                        );
                      }

                      if (snapshot.hasError) {
                        return const Center(
                          child:
                              Padding(
                            padding:
                                EdgeInsets.all(
                              24,
                            ),
                            child:
                                Text(
                              'Unable to load notifications.',
                              style:
                                  TextStyle(
                                color:
                                    textGrey,
                                fontWeight:
                                    FontWeight.w600,
                              ),
                            ),
                          ),
                        );
                      }

                      final List<
                              Map<
                                  String,
                                  dynamic>>
                          notifications =
                          snapshot.data ??
                              [];

                      final List<
                              Map<
                                  String,
                                  dynamic>>
                          filtered =
                          _filterNotifications(
                        notifications,
                      );

                      if (notifications.isEmpty) {
                        return _buildEmptyState();
                      }

                      if (filtered.isEmpty) {
                        return const Center(
                          child:
                              Text(
                            'No matching notifications.',
                            style:
                                TextStyle(
                              color:
                                  textGrey,
                              fontWeight:
                                  FontWeight.w600,
                            ),
                          ),
                        );
                      }

                      final List<
                              Map<
                                  String,
                                  dynamic>>
                          unread =
                          filtered.where(
                        (notification) {
                          return notification[
                                  'isRead'] !=
                              true;
                        },
                      ).toList();

                      final List<
                              Map<
                                  String,
                                  dynamic>>
                          read =
                          filtered.where(
                        (notification) {
                          return notification[
                                  'isRead'] ==
                              true;
                        },
                      ).toList();

                      return ListView(
                        physics:
                            const BouncingScrollPhysics(),

                        padding:
                            const EdgeInsets.fromLTRB(
                          24,
                          12,
                          24,
                          30,
                        ),

                        children: [
                          if (unread.isNotEmpty) ...[
                            Text(
                              'New (${unread.length})',

                              style:
                                  const TextStyle(
                                color:
                                    textDark,
                                fontSize:
                                    16,
                                fontWeight:
                                    FontWeight.w800,
                              ),
                            ),

                            const SizedBox(
                              height:
                                  12,
                            ),

                            ...unread.map(
                              (
                                notification,
                              ) =>
                                  _buildNotificationCard(
                                notification,
                              ),
                            ),
                          ],

                          if (unread.isNotEmpty &&
                              read.isNotEmpty)
                            const SizedBox(
                              height:
                                  20,
                            ),

                          if (read.isNotEmpty) ...[
                            const Text(
                              'Earlier',

                              style:
                                  TextStyle(
                                color:
                                    textDark,
                                fontSize:
                                    16,
                                fontWeight:
                                    FontWeight.w800,
                              ),
                            ),

                            const SizedBox(
                              height:
                                  12,
                            ),

                            ...read.map(
                              (
                                notification,
                              ) =>
                                  _buildNotificationCard(
                                notification,
                              ),
                            ),
                          ],
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // SEARCH FILTER
  // ============================================================

  List<Map<String, dynamic>>
      _filterNotifications(
    List<Map<String, dynamic>>
        notifications,
  ) {
    final String query =
        _searchQuery
            .trim()
            .toLowerCase();

    if (query.isEmpty) {
      return notifications;
    }

    return notifications.where(
      (notification) {
        final String title =
            (notification['title'] ?? '')
                .toString()
                .toLowerCase();

        final String message =
            (notification['message'] ?? '')
                .toString()
                .toLowerCase();

        final String courseCode =
            (notification['courseCode'] ?? '')
                .toString()
                .toLowerCase();

        final String courseTitle =
            (notification['courseTitle'] ?? '')
                .toString()
                .toLowerCase();

        final String actorName =
            (notification['actorName'] ?? '')
                .toString()
                .toLowerCase();

        return title.contains(query) ||
            message.contains(query) ||
            courseCode.contains(query) ||
            courseTitle.contains(query) ||
            actorName.contains(query);
      },
    ).toList();
  }

  // ============================================================
  // NOTIFICATION CARD
  // ============================================================

  Widget _buildNotificationCard(
    Map<String, dynamic> notification,
  ) {
    final String type =
        (notification['type'] ??
                'notification')
            .toString()
            .trim()
            .toLowerCase();

    final String title =
        (notification['title'] ??
                'Notification')
            .toString();

    final String message =
        (notification['message'] ?? '')
            .toString();

    final String courseCode =
        (notification['courseCode'] ?? '')
            .toString();

    final String courseTitle =
        (notification['courseTitle'] ?? '')
            .toString();

    final String actorName =
        (notification['actorName'] ?? '')
            .toString();

    final bool isRead =
        notification['isRead'] ==
            true;

    final bool isUrgent =
        notification['isUrgent'] ==
            true ||
        (notification['priority'] ?? '')
                .toString()
                .trim()
                .toLowerCase() ==
            'urgent';

    final DateTime? createdAt =
        _toDate(
      notification['createdAt'],
    );

    IconData icon =
        Icons.notifications_rounded;

    Color iconColor =
        primaryBlue;

    if (type == 'announcement') {
      icon =
          Icons.campaign_rounded;

      iconColor =
          isUrgent
              ? orange
              : primaryBlue;
    } else if (type == 'module') {
      icon = Icons.view_module_rounded;
      iconColor = const Color(0xFF7C3AED);
    } else if (type == 'resource') {
      icon = Icons.attach_file_rounded;
      iconColor = const Color(0xFF0891B2);
    } else if (type == 'assessment' ||
        type == 'assignment') {
      icon = Icons.assignment_rounded;
      iconColor = orange;
    } else if (type == 'grade') {
      icon = Icons.workspace_premium_rounded;
      iconColor = const Color(0xFF16A365);
    } else if (type == 'compliance_approved') {
      icon = Icons.check_circle_rounded;
      iconColor = const Color(0xFF16A365);
    } else if (type == 'compliance_rejected') {
      icon = Icons.cancel_rounded;
      iconColor = const Color(0xFFE53935);
    }

    final String courseLabel =
        courseCode.isNotEmpty
            ? courseTitle.isNotEmpty
                ? '$courseCode • $courseTitle'
                : courseCode
            : courseTitle.isNotEmpty
                ? courseTitle
                : 'All Classes';

    return InkWell(
      borderRadius:
          BorderRadius.circular(
        18,
      ),

      onTap:
          () {
        _markAsRead(
          notification,
        );
      },

      child:
          Container(
        margin:
            const EdgeInsets.only(
          bottom:
              12,
        ),

        padding:
            const EdgeInsets.all(
          16,
        ),

        decoration:
            BoxDecoration(
          color: !isRead
              ? primaryBlue.withValues(
                  alpha:
                      0.035,
                )
              : Colors.white,

          borderRadius:
              BorderRadius.circular(
            18,
          ),

          border:
              Border.all(
            color: !isRead
                ? primaryBlue.withValues(
                    alpha:
                        0.24,
                  )
                : const Color(
                    0xFFE6EAF0,
                  ),

            width:
                1.3,
          ),
        ),

        child:
            Row(
          crossAxisAlignment:
              CrossAxisAlignment.start,

          children: [
            Container(
              width:
                  44,

              height:
                  44,

              decoration:
                  BoxDecoration(
                color:
                    iconColor.withValues(
                  alpha:
                      0.10,
                ),

                borderRadius:
                    BorderRadius.circular(
                  12,
                ),
              ),

              child:
                  Icon(
                icon,

                color:
                    iconColor,

                size:
                    22,
              ),
            ),

            const SizedBox(
              width:
                  13,
            ),

            Expanded(
              child:
                  Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,

                children: [
                  Row(
                    children: [
                      Expanded(
                        child:
                            Text(
                          title,

                          style:
                              TextStyle(
                            color:
                                textDark,

                            fontSize:
                                14.5,

                            fontWeight:
                                !isRead
                                    ? FontWeight
                                        .w800
                                    : FontWeight
                                        .w700,
                          ),
                        ),
                      ),

                      if (!isRead)
                        Container(
                          width:
                              9,

                          height:
                              9,

                          decoration:
                              const BoxDecoration(
                            color:
                                primaryBlue,

                            shape:
                                BoxShape.circle,
                          ),
                        ),
                    ],
                  ),

                  const SizedBox(
                    height:
                        5,
                  ),

                  Text(
                    message,

                    style:
                        const TextStyle(
                      color:
                          textGrey,

                      fontSize:
                          12.5,

                      height:
                          1.45,
                    ),
                  ),

                  const SizedBox(
                    height:
                        9,
                  ),

                  Wrap(
                    spacing:
                        8,

                    runSpacing:
                        5,

                    children: [
                      Text(
                        courseLabel,

                        style:
                            const TextStyle(
                          color:
                              primaryBlue,

                          fontSize:
                              10.5,

                          fontWeight:
                              FontWeight.w700,
                        ),
                      ),

                      if (actorName.isNotEmpty)
                        Text(
                          '• $actorName',

                          style:
                              const TextStyle(
                            color:
                                textGrey,

                            fontSize:
                                10.5,
                          ),
                        ),

                      if (createdAt != null)
                        Text(
                          '• ${_formatDate(createdAt)}',

                          style:
                              const TextStyle(
                            color:
                                textGrey,

                            fontSize:
                                10.5,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // EMPTY STATE
  // ============================================================

  Widget _buildEmptyState() {
    return const Center(
      child:
          Column(
        mainAxisSize:
            MainAxisSize.min,

        children: [
          Icon(
            Icons
                .notifications_none_rounded,

            color:
                primaryBlue,

            size:
                52,
          ),

          SizedBox(
            height:
                12,
          ),

          Text(
            'No notifications yet',

            style:
                TextStyle(
              color:
                  textDark,

              fontSize:
                  17,

              fontWeight:
                  FontWeight.w800,
            ),
          ),

          SizedBox(
            height:
                5,
          ),

          Text(
            'New announcements and updates will appear here.',

            textAlign:
                TextAlign.center,

            style:
                TextStyle(
              color:
                  textGrey,

              fontSize:
                  12,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // DATE HELPERS
  // ============================================================

  DateTime? _toDate(
    dynamic value,
  ) {
    if (value is Timestamp) {
      return value.toDate();
    }

    if (value is DateTime) {
      return value;
    }

    return null;
  }

  String _formatDate(
    DateTime date,
  ) {
    const List<String> months = [
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

    final int hour =
        date.hour == 0
            ? 12
            : date.hour > 12
                ? date.hour - 12
                : date.hour;

    final String minute =
        date.minute
            .toString()
            .padLeft(
              2,
              '0',
            );

    final String period =
        date.hour >= 12
            ? 'PM'
            : 'AM';

    return '${months[date.month - 1]} '
        '${date.day} • '
        '$hour:$minute $period';
  }
}
