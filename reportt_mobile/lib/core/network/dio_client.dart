import 'package:dio/dio.dart';
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

  dio.interceptors.add(_AuthInterceptor(dio));

  return dio;
});

/// JWT otomatik yenileme interceptor'ı.
///
/// Access token süresi dolduğunda (401), refresh token ile
/// sessiz yenileme yapar. Kullanıcı fark etmez.
class _AuthInterceptor extends Interceptor {
  final Dio _dio;
  bool _isRefreshing = false;

  _AuthInterceptor(this._dio);

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    final token = await secureStorage.read(key: 'jwt_token');
    if (token != null) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    // 401 ve refresh denemesi yapılmamışsa
    if (err.response?.statusCode == 401 && !_isRefreshing) {
      _isRefreshing = true;
      try {
        final refreshToken = await secureStorage.read(key: 'refresh_token');
        if (refreshToken == null) {
          _isRefreshing = false;
          return handler.next(err);
        }

        // Yeni bir Dio instance'ı ile refresh isteği yap (interceptor döngüsü önlemek için)
        final refreshDio = Dio(BaseOptions(
          baseUrl: _getBaseUrl(),
          headers: {'ngrok-skip-browser-warning': 'true'},
        ));

        final response = await refreshDio.post('/auth/refresh', data: {
          'refreshToken': refreshToken,
        });

        final newAccessToken = response.data['accessToken'];
        final newRefreshToken = response.data['refreshToken'];

        // Yeni token'ları kaydet
        await secureStorage.write(key: 'jwt_token', value: newAccessToken);
        if (newRefreshToken != null) {
          await secureStorage.write(key: 'refresh_token', value: newRefreshToken);
        }

        // Orijinal isteği yeni token ile tekrar gönder
        final opts = err.requestOptions;
        opts.headers['Authorization'] = 'Bearer $newAccessToken';
        final retryResponse = await _dio.fetch(opts);

        _isRefreshing = false;
        return handler.resolve(retryResponse);
      } catch (e) {
        _isRefreshing = false;
        // Refresh de başarısız — login ekranına at
        await secureStorage.delete(key: 'jwt_token');
        await secureStorage.delete(key: 'refresh_token');
        return handler.next(err);
      }
    }

    handler.next(err);
  }
}
