import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class AdminAIGatewayScreen extends StatefulWidget {
  const AdminAIGatewayScreen({super.key});

  @override
  State<AdminAIGatewayScreen> createState() =>
      _AdminAIGatewayScreenState();
}

class _AdminAIGatewayScreenState
    extends State<AdminAIGatewayScreen> {
  static const Color adminTheme = Colors.deepPurple;
  static const Color background = Color(0xFFF8F9FA);
  static const Color textDark = Color(0xFF10182F);
  static const Color textGrey = Color(0xFF68738A);
  static const Color borderColor = Color(0xFFE6EAF0);
  static const Color green = Color(0xFF26A65B);
  static const Color orange = Color(0xFFFF9418);
  static const Color red = Color(0xFFFF4B4B);

  final FirebaseFirestore _firestore =
      FirebaseFirestore.instance;

  bool _isLoading = true;
  String? _errorMessage;

  int _eligible = 0;
  int _ready = 0;
  int _pending = 0;
  int _failed = 0;

  String _model = 'gemini-3.7-flash';

  List<Map<String, dynamic>> _activities = [];

  @override
  void initState() {
    super.initState();
    _loadAiStatus();
  }

  Future<void> _loadAiStatus() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final resourceSnapshot =
          await _firestore.collection('moduleResources').get();

      int eligible = 0;
      int ready = 0;
      int pending = 0;
      int failed = 0;

      final List<Map<String, dynamic>> activities = [];
      final Set<String> creatorIds = {};
      final Set<String> models = {};

      for (final document in resourceSnapshot.docs) {
        final data = document.data();

        if (data['aiEligible'] == true) {
          eligible++;
        }

        final status = (data['aiProcessingStatus'] ?? '')
            .toString()
            .trim()
            .toLowerCase();

        if (status == 'ready') {
          ready++;
        } else if (status == 'pending' ||
            status == 'processing') {
          pending++;
        } else if (status == 'failed') {
          failed++;
        }

        final model =
            (data['aiModel'] ?? '').toString().trim();

        if (model.isNotEmpty) {
          models.add(model);
        }

        final creatorId =
            (data['createdBy'] ?? '').toString().trim();

        if (creatorId.isNotEmpty) {
          creatorIds.add(creatorId);
        }

        if (status.isNotEmpty || data['aiEligible'] == true) {
          activities.add({
            ...data,
            'resourceId': document.id,
            'activityTimestamp':
                data['aiProcessedAt'] ?? data['updatedAt'],
          });
        }
      }

      final Map<String, String> creatorNames = {};

      for (final creatorId in creatorIds) {
        final userDocument =
            await _firestore.collection('users').doc(creatorId).get();

        if (userDocument.exists && userDocument.data() != null) {
          creatorNames[creatorId] =
              (userDocument.data()?['name'] ?? 'Instructor')
                  .toString();
        }
      }

      activities.sort((a, b) {
        final aDate = _dateFrom(a['activityTimestamp']);
        final bDate = _dateFrom(b['activityTimestamp']);

        if (aDate == null && bDate == null) return 0;
        if (aDate == null) return 1;
        if (bDate == null) return -1;

        return bDate.compareTo(aDate);
      });

      final recent = activities.take(20).map((item) {
        final creatorId =
            (item['createdBy'] ?? '').toString();

        return <String, dynamic>{
          ...item,
          'creatorName':
              creatorNames[creatorId] ?? 'Instructor',
        };
      }).toList();

      if (!mounted) return;

      setState(() {
        _eligible = eligible;
        _ready = ready;
        _pending = pending;
        _failed = failed;
        _activities = recent;

        if (models.isNotEmpty) {
          _model = models.last;
        }

        _isLoading = false;
      });
    } on FirebaseException catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _errorMessage =
            e.message ?? 'Unable to load Firebase AI activity.';
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _errorMessage =
            e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        backgroundColor: background,
        elevation: 0,
        foregroundColor: textDark,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'AI Service Gateway',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 18,
              ),
            ),
            Text(
              'Firebase AI Logic Monitoring',
              style: TextStyle(
                fontSize: 12,
                color: textGrey,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: _isLoading ? null : _loadAiStatus,
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh_rounded),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1200),
            child: _buildBody(),
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: adminTheme),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline_rounded,
                color: red,
                size: 50,
              ),
              const SizedBox(height: 14),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: textGrey,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 18),
              ElevatedButton.icon(
                onPressed: _loadAiStatus,
                style: ElevatedButton.styleFrom(
                  backgroundColor: adminTheme,
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Try Again'),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadAiStatus,
      color: adminTheme,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
        children: [
          _buildSecurityBanner(),
          const SizedBox(height: 18),
          _buildModelCard(),
          const SizedBox(height: 18),
          _buildMetrics(),
          const SizedBox(height: 28),
          const Text(
            'Recent Material AI Activity',
            style: TextStyle(
              color: textDark,
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          if (_activities.isEmpty)
            _buildEmptyActivity()
          else
            ..._activities.map(_buildActivityCard),
        ],
      ),
    );
  }

  Widget _buildSecurityBanner() {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: adminTheme.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: adminTheme.withValues(alpha: 0.18),
        ),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.security_rounded, color: adminTheme),
          SizedBox(width: 11),
          Expanded(
            child: Text(
              'CASLMS does not expose or edit Gemini API keys here. Firebase AI Logic configuration belongs in Firebase / Google Cloud, not inside the Flutter client.',
              style: TextStyle(
                color: textDark,
                fontSize: 11.5,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModelCard() {
    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(11),
            decoration: BoxDecoration(
              color: adminTheme.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.auto_awesome_rounded,
              color: adminTheme,
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Detected Model',
                  style: TextStyle(
                    color: textGrey,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  _model,
                  style: const TextStyle(
                    color: textDark,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          const Text(
            'Firebase AI Logic',
            style: TextStyle(
              color: adminTheme,
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetrics() {
    return Row(
      children: [
        Expanded(
          child: _metric(
            'Eligible',
            _eligible,
            Icons.description_outlined,
            Colors.blue,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _metric(
            'Ready',
            _ready,
            Icons.check_circle_outline_rounded,
            green,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _metric(
            'Pending',
            _pending,
            Icons.schedule_rounded,
            orange,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _metric(
            'Failed',
            _failed,
            Icons.error_outline_rounded,
            red,
          ),
        ),
      ],
    );
  }

  Widget _metric(
    String label,
    int value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(
        vertical: 14,
        horizontal: 8,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 5),
          Text(
            '$value',
            style: const TextStyle(
              color: textDark,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          Text(
            label,
            style: const TextStyle(
              color: textGrey,
              fontSize: 9.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActivityCard(Map<String, dynamic> item) {
    final status = (item['aiProcessingStatus'] ?? '')
        .toString()
        .trim()
        .toLowerCase();

    final Color color = status == 'ready'
        ? green
        : status == 'failed'
            ? red
            : orange;

    final fileName =
        (item['fileName'] ?? item['title'] ?? 'Learning Material')
            .toString();

    final creatorName =
        (item['creatorName'] ?? 'Instructor').toString();

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              status == 'ready'
                  ? Icons.auto_awesome_rounded
                  : status == 'failed'
                      ? Icons.error_outline_rounded
                      : Icons.schedule_rounded,
              color: color,
              size: 19,
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  fileName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: textDark,
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '$creatorName • '
                  '${status.isEmpty ? 'AI Eligible' : _capitalize(status)}',
                  style: TextStyle(
                    color: color,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  _formatTimestamp(item['activityTimestamp']),
                  style: const TextStyle(
                    color: textGrey,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyActivity() {
    return  Container(
      padding: EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.all(Radius.circular(16)),
      ),
      child: Column(
        children: [
          Icon(
            Icons.auto_awesome_outlined,
            color: textGrey,
            size: 32,
          ),
          SizedBox(height: 9),
          Text(
            'No AI material activity has been recorded yet.',
            textAlign: TextAlign.center,
            style: TextStyle(color: textGrey),
          ),
        ],
      ),
    );
  }

  DateTime? _dateFrom(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }

  String _formatTimestamp(dynamic value) {
    final date = _dateFrom(value);

    if (date == null) return 'No timestamp';

    final difference =
        DateTime.now().difference(date.toLocal());

    if (difference.inMinutes < 1) return 'Just now';
    if (difference.inMinutes < 60) {
      return '${difference.inMinutes} min ago';
    }
    if (difference.inHours < 24) {
      return '${difference.inHours} hr ago';
    }

    return '${difference.inDays} day${difference.inDays == 1 ? '' : 's'} ago';
  }

  String _capitalize(String value) {
    if (value.isEmpty) return value;
    return '${value[0].toUpperCase()}${value.substring(1)}';
  }
}
