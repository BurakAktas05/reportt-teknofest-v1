import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

/// Sesli İhbar Servisi (STT — Speech to Text).
///
/// Türkçe konuşma tanıma ile vatandaşların ellerini kullanmadan
/// ihbar açıklaması girmesini sağlar. Görme engelli erişilebilirlik.
///
/// Kullanım:
/// ```dart
/// final service = VoiceInputService();
/// await service.initialize();
/// service.startListening((text) => descriptionController.text = text);
/// ```
class VoiceInputService {
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isAvailable = false;
  bool _isListening = false;
  String _currentLocale = 'tr_TR';

  bool get isListening => _isListening;
  bool get isAvailable => _isAvailable;

  /// STT motorunu başlatır.
  Future<bool> initialize() async {
    _isAvailable = await _speech.initialize(
      onError: (error) => debugPrint('[STT] Hata: ${error.errorMsg}'),
      onStatus: (status) => debugPrint('[STT] Durum: $status'),
    );

    if (_isAvailable) {
      // Türkçe varsa Türkçe kullan
      final locales = await _speech.locales();
      final turkish = locales.where((l) => l.localeId.startsWith('tr'));
      if (turkish.isNotEmpty) {
        _currentLocale = turkish.first.localeId;
      }
    }

    return _isAvailable;
  }

  /// Dinlemeyi başlatır.
  ///
  /// [onResult] her tanınan metin parçasında çağrılır.
  /// [onFinal] son tanıma tamamlandığında çağrılır.
  void startListening({
    required Function(String text) onResult,
    Function(String finalText)? onFinal,
  }) {
    if (!_isAvailable || _isListening) return;

    _isListening = true;

    _speech.listen(
      onResult: (result) {
        onResult(result.recognizedWords);
        if (result.finalResult && onFinal != null) {
          onFinal(result.recognizedWords);
        }
      },
      localeId: _currentLocale,
      listenOptions: stt.SpeechListenOptions(
        listenMode: stt.ListenMode.dictation,
        cancelOnError: false,
        partialResults: true,
      ),
      listenFor: const Duration(seconds: 60), // Max 60 saniye
    );
  }

  /// Dinlemeyi durdurur.
  void stopListening() {
    if (_isListening) {
      _speech.stop();
      _isListening = false;
    }
  }

  /// Dinlemeyi iptal eder (sonuçları siler).
  void cancelListening() {
    if (_isListening) {
      _speech.cancel();
      _isListening = false;
    }
  }

  /// Desteklenen diller.
  void setLocale(String locale) {
    _currentLocale = locale;
  }

  void dispose() {
    _speech.stop();
  }
}
