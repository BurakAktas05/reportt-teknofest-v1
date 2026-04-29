import 'dart:io';
import 'package:flutter/foundation.dart';

/// Zero-Trust cihaz doğrulama servisi (Modül 1).
///
/// iOS için DeviceCheck API, Android için Play Integrity API token'ı üretir.
/// Token sunucu tarafında doğrulanarak uçta (edge) yapılan işlemlerin
/// hacklenmesi önlenir.
///
/// Mimari:
/// ```
/// [Flutter] ──attestation token──▶ [Spring Boot] ──verify──▶ [Apple/Google]
///                                       │
///                                  deviceVerified = true/false
/// ```
class DeviceAttestationService {
  DeviceAttestationService._();

  /// Platform bazlı cihaz doğrulama token'ı üretir.
  ///
  /// - **iOS**: DeviceCheck API (DCDevice) kullanılarak token alınır
  /// - **Android**: Play Integrity API (StandardIntegrityManager) kullanılır
  /// - **Web**: Token üretilmez (null döner)
  ///
  /// Üretim ortamında platform kanalları (MethodChannel) üzerinden
  /// native API'lere bağlanır.
  static Future<String?> generateToken() async {
    try {
      if (kIsWeb) {
        // Web platformunda cihaz doğrulama desteklenmiyor
        return null;
      }

      if (Platform.isIOS) {
        return _generateiOSToken();
      } else if (Platform.isAndroid) {
        return _generateAndroidToken();
      }

      return null;
    } catch (e) {
      debugPrint('Device attestation hatasi: $e');
      return null;
    }
  }

  /// iOS DeviceCheck token üretimi.
  ///
  /// ÜRETİM ENTEGRASYONu:
  /// ```swift
  /// // AppDelegate.swift veya platform channel handler
  /// DCDevice.current.generateToken { token, error in
  ///     result(token?.base64EncodedString())
  /// }
  /// ```
  static Future<String?> _generateiOSToken() async {
    // Geliştirme ortamı: simüle edilmiş token
    // Üretim: MethodChannel ile native DCDevice.generateToken() çağrılır
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return 'ios_dev_token_$timestamp';
  }

  /// Android Play Integrity token üretimi.
  ///
  /// ÜRETİM ENTEGRASYONu:
  /// ```kotlin
  /// // MainActivity.kt veya platform channel handler
  /// val integrityManager = IntegrityManagerFactory.create(context)
  /// val tokenRequest = IntegrityTokenRequest.builder()
  ///     .setNonce(nonce)
  ///     .build()
  /// integrityManager.requestIntegrityToken(tokenRequest)
  ///     .addOnSuccessListener { response ->
  ///         result.success(response.token())
  ///     }
  /// ```
  static Future<String?> _generateAndroidToken() async {
    // Geliştirme ortamı: simüle edilmiş token
    // Üretim: MethodChannel ile native PlayIntegrity API çağrılır
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return 'android_dev_token_$timestamp';
  }

  /// Basit bir on-device aciliyet ön skoru hesaplar (Hybrid Check için).
  ///
  /// Sunucu tarafında Python NLP ile tekrar hesaplanır ve fark
  /// belirli eşiği geçerse bayrak kaldırılır.
  static int computeClientUrgencyScore(String description, String category) {
    if (description.isEmpty) return 1;

    final lower = description.toLowerCase();
    int score = 1;

    // Basit anahtar kelime eşleştirme
    const highUrgency = ['silah', 'ölüm', 'cinayet', 'patlama', 'rehin', 'bomba', 'yangın', 'yangin'];
    const mediumUrgency = ['kavga', 'kaza', 'hirsizlik', 'gasp', 'soygun', 'taciz', 'yaralama'];
    const lowUrgency = ['park', 'çöp', 'gürültü', 'bozuk', 'çukur'];

    for (final keyword in highUrgency) {
      if (lower.contains(keyword)) {
        score = score > 8 ? score : 8;
      }
    }
    for (final keyword in mediumUrgency) {
      if (lower.contains(keyword)) {
        score = score > 5 ? score : 5;
      }
    }
    for (final keyword in lowUrgency) {
      if (lower.contains(keyword)) {
        score = score > 3 ? score : 3;
      }
    }

    // Kategori bazlı taban
    switch (category) {
      case 'VIOLENCE':
        score = score > 7 ? score : 7;
        break;
      case 'SECURITY':
        score = score > 6 ? score : 6;
        break;
      case 'TRAFFIC_OFFENSE':
        score = score > 4 ? score : 4;
        break;
    }

    return score.clamp(1, 10);
  }
}
