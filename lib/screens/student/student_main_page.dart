import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'modules_page.dart';
import 'progress_page.dart';
import 'student_assignments_page.dart';
import 'student_dashboard_page.dart';
import 'student_profile_page.dart';

class StudentMainScreen extends StatefulWidget {
  const StudentMainScreen({super.key});

  @override
  State<StudentMainScreen> createState() => _StudentMainScreenState();
}

class _StudentMainScreenState extends State<StudentMainScreen> {
  static const primaryBlue = Color(0xFF1769FF);

  int _selectedIndex = 0;
  late final List<Widget> _pages;

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>?
      _notificationSubscription;

  final Set<String> _knownNotificationIds = {};
  bool _notificationBaselineLoaded = false;

  @override
  void initState() {
    super.initState();

    _pages = [
      StudentDashboardScreen(onNavigateToTab: _onItemTapped),
      const ModulesScreen(),
      const StudentAssignmentsScreen(),
      const ProgressScreen(),
      const StudentProfileScreen(),
    ];

    _startNotificationPopups();
  }

  @override
  void dispose() {
    _notificationSubscription?.cancel();
    super.dispose();
  }

  void _onItemTapped(int index) {
    if (!mounted ||
        index < 0 ||
        index >= _pages.length ||
        index == _selectedIndex) {
      return;
    }

    setState(() => _selectedIndex = index);
  }

  void _startNotificationPopups() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    _notificationSubscription = FirebaseFirestore.instance
        .collection('notifications')
        .where('userId', isEqualTo: user.uid)
        .snapshots(includeMetadataChanges: true)
        .listen(
          (snapshot) {
            if (!mounted) return;

            // Show only committed notifications from the server.
            if (snapshot.metadata.isFromCache ||
                snapshot.metadata.hasPendingWrites) {
              return;
            }

            // Existing inbox messages must not all pop up at login.
            if (!_notificationBaselineLoaded) {
              _knownNotificationIds.addAll(
                snapshot.docs.map((document) => document.id),
              );
              _notificationBaselineLoaded = true;
              return;
            }

            for (final document in snapshot.docs) {
              if (!_knownNotificationIds.add(document.id)) continue;

              final data = document.data();

              if (data['isRead'] == true) continue;

              final type = data['type'];
              if (type != 'grade' && type != 'feedback') continue;

              final title =
                  (data['title'] ?? 'New notification').toString();
              final message = (data['message'] ?? '').toString();

              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!mounted) return;

                ScaffoldMessenger.maybeOf(context)?.showSnackBar(
                  SnackBar(
                    content: Text(
                      '$title\n$message',
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                    ),
                    duration: const Duration(seconds: 6),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              });
            }
          },
          onError: (Object error, StackTrace stackTrace) {
            debugPrint('Notification listener failed: $error');
          },
        );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FC),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: IndexedStack(
            index: _selectedIndex,
            children: _pages,
          ),
        ),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          child: Center(
            heightFactor: 1,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1200),
              child: Theme(
                data: Theme.of(context).copyWith(
                  splashColor: Colors.transparent,
                  highlightColor: Colors.transparent,
                ),
                child: BottomNavigationBar(
                  backgroundColor: Colors.white,
                  elevation: 0,
                  currentIndex: _selectedIndex,
                  onTap: _onItemTapped,
                  selectedItemColor: primaryBlue,
                  unselectedItemColor: Colors.grey[400],
                  showSelectedLabels: true,
                  showUnselectedLabels: true,
                  selectedFontSize: 10,
                  unselectedFontSize: 10,
                  type: BottomNavigationBarType.fixed,
                  iconSize: 24,
                  items: const [
                    BottomNavigationBarItem(
                      icon: Icon(Icons.home_rounded),
                      label: 'Home',
                    ),
                    BottomNavigationBarItem(
                      icon: Icon(Icons.folder_rounded),
                      label: 'Modules',
                    ),
                    BottomNavigationBarItem(
                      icon: Icon(Icons.assignment_rounded),
                      label: 'Tasks',
                    ),
                    BottomNavigationBarItem(
                      icon: Icon(Icons.timeline_rounded),
                      label: 'Progress',
                    ),
                    BottomNavigationBarItem(
                      icon: Icon(Icons.person_outline_rounded),
                      label: 'Profile',
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