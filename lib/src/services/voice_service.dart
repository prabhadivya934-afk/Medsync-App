import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:flutter_tts/flutter_tts.dart';

class VoiceService {
  static final SpeechToText _speech = SpeechToText();
  static final FlutterTts _tts = FlutterTts();

  static bool _speechInitialized = false;
  static bool _isListening = false;

  // ───────────────── INIT ─────────────────
  static Future<void> init() async {
    try {
      _speechInitialized = await _speech.initialize(
        onError: (error) {
          debugPrint("Speech error: ${error.errorMsg}");
          _isListening = false;
        },
        onStatus: (status) {
          debugPrint("Speech status: $status");

          if (status == "done" || status == "notListening") {
            _isListening = false;
          }
        },
      );

      // TTS SETTINGS
      await _tts.setLanguage("en-US");
      await _tts.setSpeechRate(0.5);
      await _tts.setPitch(1.0);
      await _tts.setVolume(1.0);

      debugPrint("Voice initialized: $_speechInitialized");
    } catch (e) {
      debugPrint("Voice init error: $e");
      _speechInitialized = false;
    }
  }

  // ───────────────── START LISTENING ─────────────────
  static Future<void> startListening(Function(String text) onResult) async {
    try {
      // Initialize if needed
      if (!_speechInitialized) {
        _speechInitialized = await _speech.initialize();
      }

      if (!_speechInitialized) {
        await speak("Speech recognition not available");
        return;
      }

      // Stop previous listening
      if (_isListening) {
        await stop();
      }

      _isListening = true;

      await _speech.listen(
        onResult: (result) {
          final words = result.recognizedWords.trim();

          debugPrint("Recognized: $words");

          if (result.finalResult && words.isNotEmpty) {
            _isListening = false;
            onResult(words.toLowerCase());
          }
        },
        listenFor: const Duration(seconds: 10),
        pauseFor: const Duration(seconds: 3),
        partialResults: true,
        cancelOnError: true,
        localeId: "en_US",
      );
    } catch (e) {
      debugPrint("Listen error: $e");
      _isListening = false;
    }
  }

  // ───────────────── SPEAK ─────────────────
  static Future<void> speak(String text) async {
    try {
      await _tts.stop();
      await _tts.speak(text);
    } catch (e) {
      debugPrint("TTS error: $e");
    }
  }

  // ───────────────── STOP ─────────────────
  static Future<void> stop() async {
    try {
      await _speech.stop();
      await _tts.stop();

      _isListening = false;
    } catch (e) {
      debugPrint("Stop error: $e");
    }
  }

  // ───────────────── GETTERS ─────────────────
  static bool get isListening => _isListening;

  static bool get isAvailable => _speechInitialized;
}
