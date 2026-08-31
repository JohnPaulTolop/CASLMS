import 'package:flutter/material.dart';

class QuizScreen extends StatefulWidget {
  final String quizTitle;
  const QuizScreen({super.key, required this.quizTitle});

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  // Controller to hold the student's code input
  final TextEditingController _codeController = TextEditingController(
    text: '''// Complete the function to return a welcome message
String getWelcomeMessage(String name) {
  // Write your code here:
  return "Hello, " + name;
}''',
  );

  String _outputResult = 'Tap "Run Code" to test your solution against test cases.';
  bool _isRunning = false;

  void _runCode() {
    setState(() {
      _isRunning = true;
      _outputResult = 'Compiling and executing code...';
    });

    // Simulate code compilation delay
    Future.delayed(const Duration(seconds: 1), () {
      setState(() {
        _isRunning = false;
        if (_codeController.text.contains('return')) {
          _outputResult = '✅ Test Passed! Output: "Hello, Rolando"';
        } else {
          _outputResult = '❌ Error: Missing return statement in function.';
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E2841),
        elevation: 0,
        foregroundColor: Colors.white,
        title: Text(
          widget.quizTitle,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: Column(
              children: [
                // --- Instruction Header ---
                Container(
                  padding: const EdgeInsets.all(20),
                  color: Colors.white,
                  width: double.infinity,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.blueAccent.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text('Coding Challenge', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.blueAccent)),
                          ),
                          const Text('100 Points', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey)),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Write a function that accepts a name string and returns a customized greeting message.',
                        style: TextStyle(fontSize: 14, color: Colors.black87, height: 1.4),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1, thickness: 1),

                // --- Mini IDE (Code Editor) ---
                Expanded(
                  flex: 3,
                  child: Container(
                    margin: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F172A), // Dark IDE theme
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey.shade800),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // IDE Top Bar
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E293B),
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Container(width: 10, height: 10, decoration: const BoxDecoration(color: Colors.redAccent, shape: BoxShape.circle)),
                                  const SizedBox(width: 6),
                                  Container(width: 10, height: 10, decoration: const BoxDecoration(color: Colors.orangeAccent, shape: BoxShape.circle)),
                                  const SizedBox(width: 6),
                                  Container(width: 10, height: 10, decoration: const BoxDecoration(color: Colors.greenAccent, shape: BoxShape.circle)),
                                  const SizedBox(width: 12),
                                  const Text('solution.dart', style: TextStyle(color: Colors.white70, fontSize: 12, fontFamily: 'monospace')),
                                ],
                              ),
                              TextButton.icon(
                                onPressed: _isRunning ? null : _runCode,
                                style: TextButton.styleFrom(
                                  backgroundColor: Colors.blueAccent,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                  minimumSize: Size.zero,
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                ),
                                icon: const Icon(Icons.play_arrow_rounded, size: 16),
                                label: const Text('Run', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                              ),
                            ],
                          ),
                        ),
                        
                        // Text Area for Code Editing
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: TextField(
                              controller: _codeController,
                              maxLines: null,
                              style: const TextStyle(color: Colors.greenAccent, fontFamily: 'monospace', fontSize: 13),
                              decoration: const InputDecoration(
                                border: InputBorder.none,
                                isDense: true,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // --- Output / Console Terminal Box ---
                Expanded(
                  flex: 1,
                  child: Container(
                    margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.black87,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Console Output:', style: TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 6),
                        Expanded(
                          child: SingleChildScrollView(
                            child: Text(
                              _outputResult,
                              style: TextStyle(
                                color: _outputResult.contains('✅') ? Colors.greenAccent : (_outputResult.contains('❌') ? Colors.redAccent : Colors.white70),
                                fontFamily: 'monospace',
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                
                // --- Submit Button Bottom Bar ---
                Container(
                  padding: const EdgeInsets.all(16),
                  color: Colors.white,
                  child: ElevatedButton(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Quiz solution submitted successfully!')),
                      );
                      Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueAccent,
                      minimumSize: const Size(double.infinity, 50),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      elevation: 0,
                    ),
                    child: const Text('Submit Final Solution', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}