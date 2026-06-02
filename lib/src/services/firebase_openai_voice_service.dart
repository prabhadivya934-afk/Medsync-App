import 'package:cloud_functions/cloud_functions.dart';

import 'ai_command_service.dart';

class FirebaseOpenAIVoiceService {
  static Future<Map<String, dynamic>> processVoiceCommand(String text) async {
    try {
      final callable = FirebaseFunctions.instance.httpsCallable(
        'medsyncVoiceAssistant',
      );

      final result = await callable.call<Map<String, dynamic>>({
        'message': text,
      });

      return Map<String, dynamic>.from(result.data);
    } catch (_) {
      final localCommand = AICommandService.process(text);
      return {...localCommand, 'reply': _fallbackReply(localCommand)};
    }
  }

  static String _fallbackReply(Map<String, dynamic> command) {
    switch (command['intent']) {
      case 'add_medicine':
        return 'I understood that you want to add a medicine.';
      case 'greeting':
        return 'Hello. How can I help you with your medicines?';
      default:
        return "Sorry, I could not understand that command.";
    }
  }
}
