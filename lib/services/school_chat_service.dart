import 'ai_router_service.dart';

/// Study mode sends conversation text only, never a scoped student report.
class SchoolChatService {
  Future<String> ask({
    required String question,
    required List<Map<String, String>> history,
    void Function(String text)? onDelta,
  }) async {
    final clean = question.trim();
    if (clean.isEmpty || clean.length > 1500) {
      throw const AiRouterException(
        'Enter a schoolwork or LMS question of up to 1,500 characters.',
      );
    }
    final recent = <Map<String, String>>[];
    for (final turn in history.skip(
      history.length > 6 ? history.length - 6 : 0,
    )) {
      final role = turn['role'];
      final text = (turn['content'] ?? '').trim();
      if (!['user', 'assistant'].contains(role) ||
          text.isEmpty ||
          recent.isEmpty && role != 'user') {
        continue;
      }
      if (recent.isNotEmpty && recent.last['role'] == role) recent.removeLast();
      recent.add({
        'role': role!,
        'content': text.length > 1500 ? text.substring(0, 1500) : text,
      });
    }
    if (recent.isNotEmpty && recent.last['role'] == 'user') recent.removeLast();
    return AiRouterService().complete(
      task: 'study_chat',
      messages: [
        ...recent,
        {'role': 'user', 'content': clean},
      ],
      onDelta: onDelta,
    );
  }
}
