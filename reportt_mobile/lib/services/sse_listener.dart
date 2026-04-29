import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// SSE (Server-Sent Events) gerçek zamanlı bildirim dinleyicisi.
///
/// Backend'deki `/api/stream/events` endpoint'ine bağlanarak
/// ihbar durum değişikliklerini anında yakalar.
///
/// Kullanım:
/// ```dart
/// final listener = SseListener();
/// listener.connect(
///   onReportUpdate: (data) => refreshReports(),
///   onBadgeEarned: (data) => showBadgeToast(data),
/// );
/// ```
class SseListener {
  StreamSubscription? _subscription;
  bool _isConnected = false;

  bool get isConnected => _isConnected;

  /// SSE bağlantısını başlatır.
  Future<void> connect({
    Function(Map<String, dynamic>)? onReportUpdate,
    Function(Map<String, dynamic>)? onBadgeEarned,
    Function(Map<String, dynamic>)? onNotification,
    Function()? onConnected,
    Function(String error)? onError,
  }) async {
    // Mevcut bağlantıyı kapat
    disconnect();

    try {
      const storage = FlutterSecureStorage();
      final token = await storage.read(key: 'jwt_token');
      if (token == null) {
        onError?.call('Token bulunamadı');
        return;
      }

      final baseUrl = 'https://handbrake-vitalize-bully.ngrok-free.dev/api';
      final dio = Dio();

      final response = await dio.get(
        '$baseUrl/stream/events',
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
            'Accept': 'text/event-stream',
            'Cache-Control': 'no-cache',
            'ngrok-skip-browser-warning': 'true',
          },
          responseType: ResponseType.stream,
        ),
      );

      _isConnected = true;
      onConnected?.call();

      final stream = (response.data as ResponseBody).stream;
      String buffer = '';

      _subscription = stream
          .cast<List<int>>()
          .transform(utf8.decoder)
          .listen(
        (chunk) {
          buffer += chunk;

          // SSE satırlarını parse et
          while (buffer.contains('\n\n')) {
            final eventEnd = buffer.indexOf('\n\n');
            final eventBlock = buffer.substring(0, eventEnd);
            buffer = buffer.substring(eventEnd + 2);

            _parseEvent(eventBlock, onReportUpdate, onBadgeEarned, onNotification);
          }
        },
        onError: (error) {
          _isConnected = false;
          onError?.call(error.toString());
          // 5 saniye sonra yeniden bağlan
          Future.delayed(const Duration(seconds: 5), () {
            connect(
              onReportUpdate: onReportUpdate,
              onBadgeEarned: onBadgeEarned,
              onNotification: onNotification,
              onConnected: onConnected,
              onError: onError,
            );
          });
        },
        onDone: () {
          _isConnected = false;
          debugPrint('[SSE] Bağlantı kapandı, yeniden bağlanılıyor...');
          Future.delayed(const Duration(seconds: 5), () {
            connect(
              onReportUpdate: onReportUpdate,
              onBadgeEarned: onBadgeEarned,
              onNotification: onNotification,
              onConnected: onConnected,
              onError: onError,
            );
          });
        },
        cancelOnError: false,
      );
    } catch (e) {
      _isConnected = false;
      onError?.call(e.toString());
      debugPrint('[SSE] Bağlantı hatası: $e');
    }
  }

  void _parseEvent(
    String block,
    Function(Map<String, dynamic>)? onReportUpdate,
    Function(Map<String, dynamic>)? onBadgeEarned,
    Function(Map<String, dynamic>)? onNotification,
  ) {
    String? eventName;
    String? data;

    for (final line in block.split('\n')) {
      if (line.startsWith('event:')) {
        eventName = line.substring(6).trim();
      } else if (line.startsWith('data:')) {
        data = line.substring(5).trim();
      }
    }

    if (data == null) return;

    try {
      final json = jsonDecode(data) as Map<String, dynamic>;

      switch (eventName) {
        case 'report_update':
          onReportUpdate?.call(json);
          break;
        case 'badge_earned':
          onBadgeEarned?.call(json);
          break;
        case 'connected':
          debugPrint('[SSE] Bağlantı kuruldu: ${json['message']}');
          break;
        default:
          onNotification?.call(json);
      }
    } catch (e) {
      debugPrint('[SSE] Parse hatası: $e');
    }
  }

  /// Bağlantıyı kapatır.
  void disconnect() {
    _subscription?.cancel();
    _subscription = null;
    _isConnected = false;
  }
}
