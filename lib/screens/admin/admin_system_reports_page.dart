import 'package:flutter/material.dart';

class AdminSystemReportsScreen extends StatefulWidget {
  const AdminSystemReportsScreen({Key? key}) : super(key: key);

  @override
  State<AdminSystemReportsScreen> createState() => _AdminSystemReportsScreenState();
}

class _AdminSystemReportsScreenState extends State<AdminSystemReportsScreen> {
  static const Color reportRed = Color(0xFFFF4B4B);
  static const Color textDark = Color(0xFF10182F);
  static const Color textGrey = Color(0xFF68738A);

  String _selectedTimeframe = 'Current Semester';
  final List<String> _timeframeOptions = [
    'Today',
    'Last 7 Days',
    'Last 30 Days',
    'Current Semester',
    'Academic Year 2025-2026',
  ];

  bool _isExporting = false;

  final List<Map<String, dynamic>> _systemLogs = [
    {
      'event': 'Bulk Grade Export Generated',
      'user': 'Admin (Dr. Anna Reyes)',
      'ip': '192.168.1.104',
      'timestamp': '12 mins ago',
      'level': 'Info',
      'icon': Icons.file_download_outlined,
      'color': Colors.blueAccent,
    },
    {
      'event': 'API Gateway Rate Limit Warning',
      'user': 'System Engine',
      'ip': '127.0.0.1',
      'timestamp': '45 mins ago',
      'level': 'Warning',
      'icon': Icons.warning_amber_rounded,
      'color': Colors.orange,
    },
    {
      'event': 'Instructor Account Provisioned',
      'user': 'Admin (Dr. Anna Reyes)',
      'ip': '192.168.1.104',
      'timestamp': '2 hours ago',
      'level': 'Success',
      'icon': Icons.person_add_alt_1_rounded,
      'color': Colors.green,
    },
    {
      'event': 'Failed Admin Login Attempt',
      'user': 'Unknown (admin_root)',
      'ip': '112.198.74.22',
      'timestamp': '5 hours ago',
      'level': 'Alert',
      'icon': Icons.gpp_bad_outlined,
      'color': reportRed,
    },
    {
      'event': 'Moodle Cache Synchronized',
      'user': 'Cron Automation',
      'ip': 'Internal REST',
      'timestamp': '8 hours ago',
      'level': 'Info',
      'icon': Icons.sync_rounded,
      'color': Colors.teal,
    },
  ];

  void _triggerExport(String fileType) async {
    Navigator.pop(context);
    setState(() => _isExporting = true);

    await Future.delayed(const Duration(seconds: 2));

    if (mounted) {
      setState(() => _isExporting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
              const SizedBox(width: 12),
              Text('CASLMS_System_Report_$fileType downloaded successfully.'),
            ],
          ),
          backgroundColor: Colors.green.shade600,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(60.0),
        child: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.black87, size: 20),
            onPressed: () => Navigator.pop(context),
          ),
          titleSpacing: 0,
          title: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'System Reports & Logs',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: Colors.black87, letterSpacing: -0.5),
              ),
              Text(
                'Audit Trails & Academic Performance',
                style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          actions: [
            IconButton(
              icon: _isExporting
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: reportRed))
                  : const Icon(Icons.file_download_outlined, color: reportRed),
              tooltip: 'Export Comprehensive Report',
              onPressed: _isExporting ? null : () => _showExportModal(context),
            ),
            const SizedBox(width: 16),
          ],
        ),
      ),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1200),
            child: ListView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
              children: [
                _buildTimeframeSelector(),
                const SizedBox(height: 20),
                _buildKeyMetrics(),
                const SizedBox(height: 28),
                const Text(
                  'Grade Distribution (CAS Department)',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: textDark),
                ),
                const SizedBox(height: 14),
                _buildGradeDistributionCard(),
                const SizedBox(height: 28),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Audit & Activity Logs',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: textDark),
                    ),
                    Text(
                      '${_systemLogs.length} Events Recorded',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: textGrey),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                _buildAuditLogsSection(),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ==============================================================
  // UI SECTIONS & CARDS
  // ==============================================================

  Widget _buildTimeframeSelector() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE6EAF0)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 8, offset: const Offset(0, 3)),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Row(
            children: [
              Icon(Icons.date_range_rounded, color: reportRed, size: 20),
              SizedBox(width: 10),
              Text('Reporting Period:', style: TextStyle(color: textGrey, fontSize: 13, fontWeight: FontWeight.w600)),
            ],
          ),
          DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _selectedTimeframe,
              icon: const Icon(Icons.arrow_drop_down_rounded, color: textDark),
              items: _timeframeOptions.map((time) {
                return DropdownMenuItem(
                  value: time,
                  child: Text(
                    time,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: textDark),
                  ),
                );
              }).toList(),
              onChanged: (val) {
                if (val != null) setState(() => _selectedTimeframe = val);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKeyMetrics() {
    return Row(
      children: [
        Expanded(
          child: _buildMetricCard(
            title: 'Passing Rate',
            value: '88.4%',
            subtitle: '+2.1% from Midterms',
            icon: Icons.auto_graph_rounded,
            color: Colors.green.shade600,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildMetricCard(
            title: 'Daily Active',
            value: '2,819',
            subtitle: '82% of student body',
            icon: Icons.person_pin_circle_rounded,
            color: Colors.blueAccent,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildMetricCard(
            title: 'Submissions',
            value: '14.2k',
            subtitle: 'Tasks & Quizzes',
            icon: Icons.checklist_rtl_rounded,
            color: Colors.deepPurple,
          ),
        ),
      ],
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE6EAF0)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 12),
          Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: color)),
          const SizedBox(height: 2),
          Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: textDark)),
          const SizedBox(height: 2),
          Text(
            subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: textGrey),
          ),
        ],
      ),
    );
  }

  Widget _buildGradeDistributionCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE6EAF0)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        children: [
          _buildGradeBar('Excellent (1.0 - 1.5)', 0.38, '38%', Colors.green.shade600),
          const SizedBox(height: 14),
          _buildGradeBar('Good (1.75 - 2.25)', 0.42, '42%', Colors.blueAccent),
          const SizedBox(height: 14),
          _buildGradeBar('Satisfactory (2.5 - 3.0)', 0.14, '14%', Colors.orange),
          const SizedBox(height: 14),
          _buildGradeBar('Conditional / Failed (4.0 - 5.0)', 0.06, '6%', reportRed),
        ],
      ),
    );
  }

  Widget _buildGradeBar(String label, double ratio, String percentage, Color barColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: textDark)),
            Text(percentage, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: barColor)),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: ratio,
            backgroundColor: const Color(0xFFEEF2F6),
            valueColor: AlwaysStoppedAnimation<Color>(barColor),
            minHeight: 8,
          ),
        ),
      ],
    );
  }

  Widget _buildAuditLogsSection() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE6EAF0)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        children: _systemLogs.asMap().entries.map((entry) {
          final log = entry.value;
          final isLast = entry.key == _systemLogs.length - 1;

          return Column(
            children: [
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: (log['color'] as Color).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(log['icon'] as IconData, color: log['color'] as Color, size: 22),
                ),
                title: Text(
                  log['event'],
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5, color: textDark),
                ),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 4.0),
                  child: Text(
                    '${log['user']} • IP: ${log['ip']}',
                    style: const TextStyle(color: textGrey, fontSize: 11.5, fontWeight: FontWeight.w500),
                  ),
                ),
                trailing: Text(
                  log['timestamp'],
                  style: const TextStyle(color: Color(0xFF9BA4B4), fontSize: 11, fontWeight: FontWeight.w600),
                ),
              ),
              if (!isLast) const Divider(height: 1, indent: 68, endIndent: 18, color: Color(0xFFF0F2F5)),
            ],
          );
        }).toList(),
      ),
    );
  }

  // ==============================================================
  // EXPORT BOTTOM SHEET MODAL
  // ==============================================================

  void _showExportModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Export System Reports',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: textDark),
              ),
              const SizedBox(height: 6),
              const Text(
                'Choose format to download platform audit logs & student metrics:',
                style: TextStyle(fontSize: 12, color: textGrey),
              ),
              const SizedBox(height: 20),
              _buildExportOption(
                icon: Icons.picture_as_pdf_rounded,
                title: 'PDF Formal Report (.pdf)',
                subtitle: 'Formatted summary charts & executive review',
                color: reportRed,
                onTap: () => _triggerExport('PDF'),
              ),
              const SizedBox(height: 10),
              _buildExportOption(
                icon: Icons.table_chart_rounded,
                title: 'Spreadsheet Format (.xlsx / .csv)',
                subtitle: 'Raw log rows, user IDs, and timestamps',
                color: Colors.green.shade700,
                onTap: () => _triggerExport('CSV'),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildExportOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE6EAF0)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5, color: textDark)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: const TextStyle(color: textGrey, fontSize: 11, fontWeight: FontWeight.w500)),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded, color: Color(0xFF9BA4B4), size: 14),
          ],
        ),
      ),
    );
  }
}