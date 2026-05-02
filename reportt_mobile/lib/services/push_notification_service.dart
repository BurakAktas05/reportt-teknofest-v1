import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// V3: Firebase Cloud Messaging (FCM) Push Bildirim Servisi.
///
/// Cihaz token'ını backend'e kaydeder ve
/// gelen push bildirimleri yönetir.
///
/// Kullanım:
/// ```dart
/// await PushNotificationService.initialize();
/// await PushNotificationService.registerToken(dio);
/// ```
class PushNotificationService {
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  static String? _fcmToken;

  /// Firebase'i başlatır ve bildirim izni ister.
  static Future<void> initialize() async {
    try {
      await Firebase.initializeApp();
      debugPrint('[FCM] Firebase başlatıldı.');

      // Bildirim izni iste
      NotificationSettings settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        announcement: false,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
      );

      debugPrint('[FCM] İzin durumu: ${settings.authorizationStatus}');

      // Token al
      _fcmToken = await _messaging.getToken();
      debugPrint('[FCM] Token: ${_fcmToken?.substring(0, 20)}...');

      // Token yenilenirse güncelle
      _messaging.onTokenRefresh.listen((newToken) {
        _fcmToken = newToken;
        debugPrint('[FCM] Token yenilendi.');
        // Backend'e otomatik gönder
        _sendTokenToBackend(newToken);
      });

      // Foreground mesajları dinle
      FirebaseMessaging.onMessage.listen(_onForegroundMessage);

      // Background/terminated mesajları
      FirebaseMessaging.onBackgroundMessage(_onBackgroundMessage);

      // Bildirime tıklanınca uygulama açılırsa
      FirebaseMessaging.onMessageOpenedApp.listen(_onMessageOpenedApp);
    } catch (e) {
      debugPrint('[FCM] UYARI: Firebase başlatılamadı: $e');
    }
  }

  /// FCM token'ını backend'e gönderir.
  static Future<void> registerToken(Dio dio) async {
    if (_fcmToken == null) {
      debugPrint('[FCM] Token henüz alınamadı.');
      return;
    }

    try {
      await dio.post('/auth/fcm-token', data: {
        'fcmToken': _fcmToken,
      });
      debugPrint('[FCM] Token backend\'e kaydedildi.');
    } catch (e) {
      debugPrint('[FCM] Token kayıt hatası: $e');
    }
  }

  /// Foreground mesaj handler
  static void _onForegroundMessage(RemoteMessage message) {
    debugPrint('[FCM] Foreground mesaj: ${message.notification?.title}');
    // SnackBar veya overlay bildirim göster
    // Bu kısım UI layer'da dinlenebilir
    _lastMessage = message;
    _onMessageCallback?.call(message);
  }

  /// Bildirime tıklandığında
  static void _onMessageOpenedApp(RemoteMessage message) {
    debugPrint('[FCM] Bildirime tıklandı: ${message.data}');
    // Navigasyon yap — reportId varsa detay sayfasına git
    _onTapCallback?.call(message);
  }

  /// Backend'e token gönder (internal)
  static Future<void> _sendTokenToBackend(String token) async {
    try {
      const storage = FlutterSecureStorage();
      final jwtToken = await storage.read(key: 'jwt_token');
      if (jwtToken == null) return;

      // Build-time env variable veya platform-aware fallback
      const envUrl = String.fromEnvironment('REPORTT_API_BASE_URL');
      final String baseUrl = envUrl.isNotEmpty
          ? envUrl
          : (kIsWeb ? 'http://localhost:8080/api' : 'http://10.0.2.2:8080/api');

      final dio = Dio(BaseOptions(
        baseUrl: baseUrl,
        headers: {
          'Authorization': 'Bearer $jwtToken',
          'ngrok-skip-browser-warning': 'true',
        },
      ));

      await dio.post('/auth/fcm-token', data: {'fcmToken': token});
    } catch (e) {
      debugPrint('[FCM] Token yenileme gönderim hatası: $e');
    }
  }

  // Callback'ler — UI layer'dan set edilir
  static RemoteMessage? _lastMessage;
  static Function(RemoteMessage)? _onMessageCallback;
  static Function(RemoteMessage)? _onTapCallback;

  /// Son alınan mesaj
  static RemoteMessage? get lastMessage => _lastMessage;

  /// Foreground mesaj callback'i ayarla
  static void setOnMessageCallback(Function(RemoteMessage) callback) {
    _onMessageCallback = callback;
  }

  /// Bildirime tıklama callback'i ayarla
  static void setOnTapCallback(Function(RemoteMessage) callback) {
    _onTapCallback = callback;
  }

  /// Mevcut FCM token'ı döndürür
  static String? get currentToken => _fcmToken;
}

/// Background message handler — top-level fonksiyon olmalı
@pragma('vm:entry-point')
Future<void> _onBackgroundMessage(RemoteMessage message) async {
  debugPrint('[FCM] Background mesaj: ${message.notification?.title}');
}
