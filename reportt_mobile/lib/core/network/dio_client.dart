import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

String _getBaseUrl() {
  return 'https://handbrake-vitalize-bully.ngrok-free.dev/api';
}

const secureStorage = FlutterSecureStorage();

final dioProvider = Provider<Dio>((ref) {
  final dio = Dio(
    BaseOptions(
      baseUrl: _getBaseUrl(), 
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
      headers: {
        'ngrok-skip-browser-warning': 'true',
      },
    ),
  );

  dio.interceptors.add(InterceptorsWrapper(
    onRequest: (options, handler) async {
      final token = await secureStorage.read(key: 'jwt_token');
      if (token != null) {
        options.headers['Authorization'] = 'Bearer $token';
      }
      return handler.next(options);
    },
    onError: (error, handler) {
      // Token expired ise vs. global hataları buradan yakalayabiliriz.
      return handler.next(error);
    }
  ));

  return dio;
});
