import 'package:flutter/material.dart';

class AdminAIGatewayScreen extends StatefulWidget {
  const AdminAIGatewayScreen({Key? key}) : super(key: key);

  @override
  State<AdminAIGatewayScreen> createState() => _AdminAIGatewayScreenState();
}

class _AdminAIGatewayScreenState extends State<AdminAIGatewayScreen> {
  final Color adminTheme = Colors.deepPurple;

  // Configuration States
  String _selectedProvider = 'Google Gemini Pro';
  final List<String> _providers = ['Google Gemini Pro', 'OpenAI GPT-4o', 'Anthropic Claude 3'];
  
  bool _isEditingKey = false;
  final TextEditingController _apiKeyController = TextEditingController(text: 'AIzaSy***************************');
  
  double _temperature = 0.7;
  double _maxTokens = 2048;
  bool _isTestingConnection = false;

  // Mock Activity Logs
  final List<Map<String, dynamic>> _activityLogs = [
    {
      'user': 'Prof. Mabansag',
      'action': 'Quiz Generation (15 items)',
      'tokens': 1240,
      'time': '10 mins ago',
      'status': 'Success'
    },
    {
      'user': 'Mr. Santos',
      'action': 'Syllabus Formatting',
      'tokens': 850,
      'time': '1 hour ago',
      'status': 'Success'
    },
    {
      'user': 'Dr. Reyes',
      'action': 'Module Summarization',
      'tokens': 3200,
      'time': '3 hours ago',
      'status': 'Failed (Timeout)'
    },
  ];

  void _testConnection() async {
    setState(() => _isTestingConnection = true);
    
    // Simulate API handshake
    await Future.delayed(const Duration(seconds: 2));
    
    if (mounted) {
      setState(() => _isTestingConnection = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: Colors.white),
              const SizedBox(width: 12),
              Text('Connection to $_selectedProvider verified.'),
            ],
          ),
          backgroundColor: Colors.green.shade600,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    super.dispose();
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
                'AI Service Gateway',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: Colors.black87, letterSpacing: -0.5),
              ),
              Text(
                'API & Token Management',
                style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.save_rounded, color: Colors.deepPurple),
              tooltip: 'Save Configurations',
              onPressed: () {
                setState(() => _isEditingKey = false);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('AI Configurations saved successfully.'), backgroundColor: Colors.deepPurple),
                );
              },
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
                _buildHealthBanner(),
                const SizedBox(height: 24),
                
                _buildTopMetrics(),
                const SizedBox(height: 32),
                
                const Text('Provider Configuration', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.black87)),
                const SizedBox(height: 16),
                _buildConfigurationSection(),
                
                const SizedBox(height: 32),
                const Text('Recent Model Activity', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.black87)),
                const SizedBox(height: 16),
                _buildActivityLogs(),
                
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ==============================================================
  // UI COMPONENTS
  // ==============================================================

  Widget _buildHealthBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [adminTheme, adminTheme.withOpacity(0.8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: adminTheme.withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 6))],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), shape: BoxShape.circle),
            child: const Icon(Icons.memory_rounded, color: Colors.white, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Gateway Status: Healthy', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text('All AI endpoints are responding normally.', style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 12, fontWeight: FontWeight.w500)),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: _isTestingConnection ? null : _testConnection,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: adminTheme,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: _isTestingConnection 
                ? SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: adminTheme))
                : const Text('Test Ping', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
          ),
        ],
      ),
    );
  }

  Widget _buildTopMetrics() {
    return Row(
      children: [
        Expanded(child: _buildMetricCard('Tokens Used\n(This Month)', '1.4M', Icons.data_usage_rounded, Colors.blueAccent)),
        const SizedBox(width: 12),
        Expanded(child: _buildMetricCard('Total Requests\n(Today)', '342', Icons.compare_arrows_rounded, Colors.teal)),
        const SizedBox(width: 12),
        Expanded(child: _buildMetricCard('Avg Response\nTime', '1.2s', Icons.timer_rounded, Colors.orange.shade600)),
      ],
    );
  }

  Widget _buildMetricCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))],
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 12),
          Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Colors.black87)),
          const SizedBox(height: 4),
          Text(title, textAlign: TextAlign.center, style: TextStyle(fontSize: 10, color: Colors.grey[600], fontWeight: FontWeight.w600, height: 1.3)),
        ],
      ),
    );
  }

  Widget _buildConfigurationSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))],
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Provider Dropdown
          const Text('Active LLM Provider', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedProvider,
                isExpanded: true,
                icon: const Icon(Icons.arrow_drop_down_rounded, color: Colors.grey),
                items: _providers.map((provider) {
                  return DropdownMenuItem(
                    value: provider,
                    child: Text(provider, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: Colors.black87)),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) setState(() => _selectedProvider = value);
                },
              ),
            ),
          ),
          
          const SizedBox(height: 20),
          
          // API Key Field
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Secret API Key', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey)),
              GestureDetector(
                onTap: () => setState(() => _isEditingKey = !_isEditingKey),
                child: Text(_isEditingKey ? 'Lock' : 'Edit', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: adminTheme)),
              )
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _apiKeyController,
            obscureText: !_isEditingKey,
            enabled: _isEditingKey,
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.vpn_key_rounded, color: Colors.grey, size: 20),
              filled: true,
              fillColor: _isEditingKey ? Colors.white : Colors.grey.shade50,
              contentPadding: const EdgeInsets.symmetric(vertical: 14),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)),
              disabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: adminTheme, width: 2)),
            ),
          ),

          const SizedBox(height: 24),
          const Divider(height: 1, color: Color(0xFFF0F2F5)),
          const SizedBox(height: 24),

          // Temperature Slider
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Model Creativity (Temperature)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.black87)),
              Text(_temperature.toStringAsFixed(1), style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: adminTheme)),
            ],
          ),
          Slider(
            value: _temperature,
            min: 0.0,
            max: 1.0,
            divisions: 10,
            activeColor: adminTheme,
            inactiveColor: adminTheme.withOpacity(0.2),
            onChanged: (val) => setState(() => _temperature = val),
          ),
          
          const SizedBox(height: 16),

          // Max Tokens Slider
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Max Output Tokens', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.black87)),
              Text(_maxTokens.toInt().toString(), style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: adminTheme)),
            ],
          ),
          Slider(
            value: _maxTokens,
            min: 256,
            max: 4096,
            divisions: 15,
            activeColor: adminTheme,
            inactiveColor: adminTheme.withOpacity(0.2),
            onChanged: (val) => setState(() => _maxTokens = val),
          ),
        ],
      ),
    );
  }

  Widget _buildActivityLogs() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))],
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Column(
        children: _activityLogs.asMap().entries.map((entry) {
          final log = entry.value;
          final isLast = entry.key == _activityLogs.length - 1;
          final isSuccess = log['status'] == 'Success';

          return Column(
            children: [
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: (isSuccess ? Colors.green : Colors.red).withOpacity(0.1), shape: BoxShape.circle),
                  child: Icon(isSuccess ? Icons.check_rounded : Icons.close_rounded, color: isSuccess ? Colors.green : Colors.red, size: 20),
                ),
                title: Text(log['action'], style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: Colors.black87)),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 4.0),
                  child: Text('${log['user']} • ${log['tokens']} tokens', style: TextStyle(color: Colors.grey.shade600, fontSize: 12, fontWeight: FontWeight.w500)),
                ),
                trailing: Text(log['time'], style: TextStyle(color: Colors.grey.shade400, fontSize: 11, fontWeight: FontWeight.w600)),
              ),
              if (!isLast) const Divider(height: 1, indent: 70, color: Color(0xFFF0F2F5)),
            ],
          );
        }).toList(),
      ),
    );
  }
}