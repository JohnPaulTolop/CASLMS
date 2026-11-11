import '../shared/page_loading_state.dart';
import '../../core/app_colors.dart';
import '../shared/aligned_page_app_bar.dart';
import '../shared/workspace_widgets.dart';
import '../shared/workspace_shell.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class AdminAIGatewayScreen extends StatefulWidget {
  const AdminAIGatewayScreen({super.key});

  @override
  State<AdminAIGatewayScreen> createState() => _AdminAIGatewayScreenState();
}

class _AdminAIGatewayScreenState extends State<AdminAIGatewayScreen> {
  Color get adminTheme => AppColors.resolve(context, AppColors.primaryBlue);
  Color get background => AppColors.resolve(context, AppColors.background);
  Color get textDark => AppColors.resolve(context, AppColors.darkText);
  Color get textGrey => AppColors.resolve(context, AppColors.secondaryText);
  Color get borderColor => AppColors.resolve(context, AppColors.inputBorder);
  Color get surface => AppColors.resolve(context, Colors.white);
  Color get green => AppColors.resolve(context, AppColors.green);
  Color get orange => AppColors.resolve(context, AppColors.amber);
  Color get red => AppColors.resolve(context, AppColors.error);

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  bool _isLoading = true;
  String? _errorMessage;

  int _eligible = 0;
  int _ready = 0;
  int _pending = 0;
  int _failed = 0;
  int _routerSuccess = 0;
  int _routerFailures = 0;
  int _routerRateLimits = 0;
  int _routerFailovers = 0;

  String _model = 'No routed provider request recorded yet';

  List<Map<String, dynamic>> _activities = [];
  List<Map<String, dynamic>> _providerStates = [];

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
      final resourceSnapshot = await _firestore
          .collection('moduleResources')
          .get();

      int eligible = 0;
      int ready = 0;
      int pending = 0;
      int failed = 0;

      final List<Map<String, dynamic>> activities = [];
      final List<Map<String, dynamic>> providerStates = [];
      try {
        final providerSnapshot = await _firestore
            .collection('aiProviderState')
            .get();
        providerStates.addAll(
          providerSnapshot.docs.map(
            (document) => <String, dynamic>{
              ...document.data(),
              'stateId': document.id,
            },
          ),
        );
      } on FirebaseException catch (error) {
        // Keep the existing material monitor usable during a staged rollout;
        // provider cards appear after the updated admin-read rule is deployed.
        if (error.code != 'permission-denied') rethrow;
      }
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
        } else if (status == 'pending' || status == 'processing') {
          pending++;
        } else if (status == 'failed') {
          failed++;
        }

        final model = (data['aiModel'] ?? '').toString().trim();

        if (model.isNotEmpty) {
          models.add(model);
        }

        final creatorId = (data['createdBy'] ?? '').toString().trim();

        if (creatorId.isNotEmpty) {
          creatorIds.add(creatorId);
        }

        if (status.isNotEmpty || data['aiEligible'] == true) {
          activities.add({
            ...data,
            'resourceId': document.id,
            'activityTimestamp': data['aiProcessedAt'] ?? data['updatedAt'],
          });
        }
      }

      final Map<String, String> creatorNames = {};

      for (final creatorId in creatorIds) {
        final userDocument = await _firestore
            .collection('users')
            .doc(creatorId)
            .get();

        if (userDocument.exists && userDocument.data() != null) {
          creatorNames[creatorId] =
              (userDocument.data()?['name'] ?? 'Instructor').toString();
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
      providerStates.sort((a, b) {
        final aDate = _dateFrom(a['updatedAt']);
        final bDate = _dateFrom(b['updatedAt']);
        if (aDate == null && bDate == null) return 0;
        if (aDate == null) return 1;
        if (bDate == null) return -1;
        return bDate.compareTo(aDate);
      });

      int total(String field) => providerStates.fold<int>(
        0,
        (runningTotal, item) =>
            runningTotal + ((item[field] as num?)?.toInt() ?? 0),
      );

      final recent = activities.take(20).map((item) {
        final creatorId = (item['createdBy'] ?? '').toString();

        return <String, dynamic>{
          ...item,
          'creatorName': creatorNames[creatorId] ?? 'Instructor',
        };
      }).toList();

      if (!mounted) return;

      setState(() {
        _eligible = eligible;
        _ready = ready;
        _pending = pending;
        _failed = failed;
        _activities = recent;
        _providerStates = providerStates;
        _routerSuccess = total('successCount');
        _routerFailures = total('failureCount');
        _routerRateLimits = total('rateLimitCount');
        _routerFailovers = total('failoverCount');

        if (providerStates.isNotEmpty) {
          _model = providerStates
              .map((item) => '${item['provider']}/${item['model']}')
              .join('  •  ');
        } else if (models.isNotEmpty) {
          _model = models.last;
        }

        _isLoading = false;
      });
    } on FirebaseException catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _errorMessage = e.message ?? 'Unable to load Firebase AI activity.';
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const PageLoadingState();
    final width = MediaQuery.sizeOf(context).width;
    final inset = workspaceInset(width);

    return Scaffold(
      backgroundColor: background,
      appBar: AlignedPageAppBar(
        maxWidth: 1320,
        inset: inset,
        child: AppBar(
          backgroundColor: background,
          elevation: 0,
          foregroundColor: textDark,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
            onPressed: () => Navigator.pop(context),
          ),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'AI Service Gateway',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 18,
                  color: textDark,
                ),
              ),
              Text(
                'Multi-provider routing monitoring',
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
              icon: Icon(Icons.refresh_rounded, color: textDark),
            ),
          ],
        ),
      ),
      body: SafeArea(
        top: false,
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1320),
            child: _buildBody(inset),
          ),
        ),
      ),
    );
  }

  Widget _buildBody(double inset) {
    if (_isLoading) {
      return Center(child: CircularProgressIndicator(color: adminTheme));
    }

    if (_errorMessage != null) {
      return Padding(
        padding: EdgeInsets.symmetric(horizontal: inset),
        child: WorkspaceErrorState(
          message: _errorMessage!,
          onRetry: _loadAiStatus,
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
        padding: EdgeInsets.fromLTRB(inset, 16, inset, 40),
        children: [
          _buildSecurityBanner(),
          const SizedBox(height: 18),
          _buildModelCard(),
          const SizedBox(height: 24),
          const WorkspaceSectionHeading(
            title: 'Routing Metrics',
            subtitle: 'Aggregate calls, errors, rate limits, and failovers.',
          ),
          const SizedBox(height: 14),
          _buildRouterMetrics(),
          const SizedBox(height: 28),
          _buildProviderHealth(),
          const SizedBox(height: 28),
          const WorkspaceSectionHeading(
            title: 'Learning Material AI Activity',
            subtitle: 'Aggregate processing pipeline status across uploaded learning resources.',
          ),
          const SizedBox(height: 14),
          _buildMetrics(),
          const SizedBox(height: 28),
          const WorkspaceSectionHeading(
            title: 'Recent Material AI Activity',
            subtitle:
                'Detailed chronological log of material processing events.',
          ),
          const SizedBox(height: 14),
          if (_activities.isEmpty)
            _buildEmptyActivity()
          else
            ..._activities.map(_buildActivityCard),
        ],
      ),
    );
  }

  Widget _buildSecurityBanner() {
    return WorkspaceSurface(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          WorkspaceIconTile(
            icon: Icons.shield_outlined,
            color: adminTheme,
            background: adminTheme.withValues(alpha: 0.12),
            size: 40,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Client Security Boundary',
                  style: TextStyle(
                    color: textDark,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'CASLMS never exposes or edits provider API keys here. AI credentials and routing configuration remain in Supabase Edge Function secrets, outside the Flutter client.',
                  style: TextStyle(color: textGrey, fontSize: 12, height: 1.45),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModelCard() {
    return WorkspaceSurface(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          WorkspaceIconTile(
            icon: Icons.auto_awesome_rounded,
            color: adminTheme,
            background: adminTheme.withValues(alpha: 0.12),
            size: 44,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'OBSERVED PROVIDER MODELS',
                  style: TextStyle(
                    color: textGrey,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _model,
                  style: TextStyle(
                    color: textDark,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: adminTheme.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: adminTheme.withValues(alpha: 0.25)),
            ),
            child: Text(
              'Server routing',
              style: TextStyle(
                color: adminTheme,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRouterMetrics() {
    final cards = [
      _metric(
        'AI Success',
        _routerSuccess,
        Icons.check_circle_outline_rounded,
        green,
      ),
      _metric('Failures', _routerFailures, Icons.error_outline_rounded, red),
      _metric('Rate Limits', _routerRateLimits, Icons.speed_rounded, orange),
      _metric(
        'Failovers',
        _routerFailovers,
        Icons.alt_route_rounded,
        Colors.blue,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 900
            ? 4
            : constraints.maxWidth >= 520
            ? 2
            : 1;

        const spacing = 12.0;
        final width =
            (constraints.maxWidth - spacing * (columns - 1)) / columns;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: cards
              .map((card) => SizedBox(width: width, child: card))
              .toList(),
        );
      },
    );
  }

  Widget _buildProviderHealth() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const WorkspaceSectionHeading(
          title: 'Provider Health',
          subtitle: 'Runtime telemetry for routed AI model endpoints.',
        ),
        const SizedBox(height: 14),
        if (_providerStates.isEmpty)
          const WorkspaceEmptyState(
            title: 'No provider attempts',
            message: 'No provider attempt has been recorded yet. Provider cards appear after the first routed AI request.',
            icon: Icons.hub_outlined,
          )
        else
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth >= 900
                  ? 3
                  : constraints.maxWidth >= 580
                  ? 2
                  : 1;
              const spacing = 12.0;
              final width =
                  (constraints.maxWidth - (columns - 1) * spacing) / columns;
              return Wrap(
                spacing: spacing,
                runSpacing: spacing,
                children: _providerStates
                    .map(
                      (provider) => SizedBox(
                        width: width,
                        child: _buildProviderCard(provider),
                      ),
                    )
                    .toList(),
              );
            },
          ),
      ],
    );
  }

  Widget _buildProviderCard(Map<String, dynamic> item) {
    final provider = (item['provider'] ?? 'provider').toString();
    final model = (item['model'] ?? 'Not recorded').toString();
    final successes = (item['successCount'] as num?)?.toInt() ?? 0;
    final failures = (item['failureCount'] as num?)?.toInt() ?? 0;
    final latencyTotal = (item['totalLatencyMs'] as num?)?.toInt() ?? 0;
    final attempts = successes + failures;
    final averageLatency = attempts == 0 ? 0 : latencyTotal ~/ attempts;
    final until = (item['until'] as num?)?.toInt() ?? 0;
    final cooling = until > DateTime.now().millisecondsSinceEpoch;
    final lastOutcome = (item['lastOutcome'] ?? '').toString();
    final unhealthy = !cooling && lastOutcome == 'failure';
    final color = cooling || unhealthy ? orange : green;
    final label = cooling
        ? 'Cooling down'
        : unhealthy
        ? 'Needs attention'
        : 'Healthy';
    final inputTokens = (item['approximateInputTokens'] as num?)?.toInt() ?? 0;
    final outputTokens =
        (item['approximateOutputTokens'] as num?)?.toInt() ?? 0;
    final cost = (item['estimatedCostUsd'] as num?)?.toDouble() ?? 0;

    return WorkspaceSurface(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 9,
                height: 9,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _capitalize(provider),
                  style: TextStyle(
                    color: textDark,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  label,
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w700,
                    fontSize: 10,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            model,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: textGrey, fontSize: 11),
          ),
          const SizedBox(height: 12),
          Text(
            '$successes successful  •  $failures failed  •  ${averageLatency}ms avg',
            style: TextStyle(color: textDark, fontSize: 11),
          ),
          const SizedBox(height: 4),
          Text(
            'Approx. ${inputTokens + outputTokens} tokens  •  \$${cost.toStringAsFixed(4)} cost',
            style: TextStyle(color: textGrey, fontSize: 10),
          ),
        ],
      ),
    );
  }

  Widget _buildMetrics() {
    final cards = [
      _metric('Eligible', _eligible, Icons.description_outlined, Colors.blue),
      _metric('Ready', _ready, Icons.check_circle_outline_rounded, green),
      _metric('Pending', _pending, Icons.schedule_rounded, orange),
      _metric('Failed', _failed, Icons.error_outline_rounded, red),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 900
            ? 4
            : constraints.maxWidth >= 520
            ? 2
            : 1;

        const spacing = 12.0;
        final width =
            (constraints.maxWidth - spacing * (columns - 1)) / columns;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: cards
              .map((card) => SizedBox(width: width, child: card))
              .toList(),
        );
      },
    );
  }

  Widget _metric(String label, int value, IconData icon, Color color) {
    return WorkspaceSurface(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          WorkspaceIconTile(
            icon: icon,
            color: color,
            background: color.withValues(alpha: 0.12),
            size: 44,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '$value',
                  style: TextStyle(
                    color: textDark,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  style: TextStyle(
                    color: textGrey,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
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

    final fileName = (item['fileName'] ?? item['title'] ?? 'Learning Material')
        .toString();

    final creatorName = (item['creatorName'] ?? 'Instructor').toString();
    final relativeTime = _formatTimestamp(item['activityTimestamp']);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: WorkspaceSurface(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            WorkspaceIconTile(
              icon: status == 'ready'
                  ? Icons.auto_awesome_rounded
                  : status == 'failed'
                  ? Icons.error_outline_rounded
                  : Icons.schedule_rounded,
              color: color,
              background: color.withValues(alpha: 0.10),
              size: 40,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    fileName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: textDark,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '$creatorName • '
                    '${status.isEmpty ? 'AI Eligible' : _capitalize(status)}',
                    style: TextStyle(
                      color: color,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            if (relativeTime != 'No timestamp') ...[
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: background,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: borderColor),
                ),
                child: Text(
                  relativeTime,
                  style: TextStyle(
                    color: textGrey,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyActivity() {
    return const WorkspaceEmptyState(
      title: 'No AI material activity',
      message: 'No AI material activity has been recorded yet.',
      icon: Icons.auto_awesome_outlined,
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

    final difference = DateTime.now().difference(date.toLocal());

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
