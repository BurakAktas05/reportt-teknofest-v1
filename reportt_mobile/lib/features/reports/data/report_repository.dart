import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/dio_client.dart';

final reportRepositoryProvider = Provider<ReportRepository>((ref) {
  final dio = ref.watch(dioProvider);
  return ReportRepository(dio);
});

// A simple DTO class for Report
class ReportResponse {
  final int id;
  final String title;
  final String description;
  final String status;
  final String category;
  final String addressText;

  ReportResponse({
    required this.id,
    required this.title,
    required this.description,
    required this.status,
    required this.category,
    required this.addressText,
  });

  factory ReportResponse.fromJson(Map<String, dynamic> json) {
    return ReportResponse(
      id: json['id'] ?? 0,
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      status: json['status'] ?? 'UNKNOWN',
      category: json['category'] ?? '',
      addressText: json['addressText'] ?? '',
    );
  }
}

class ReportRepository {
  final Dio _dio;

  ReportRepository(this._dio);

  Future<List<ReportResponse>> getMyReports() async {
    try {
      final response = await _dio.get('/reports/my');
      final List<dynamic> data = response.data;
      return data.map((e) => ReportResponse.fromJson(e)).toList();
    } on DioException catch (e) {
      throw Exception(e.response?.data['message'] ?? 'İhbarlar alınamadı');
    }
  }

  Future<ReportResponse> getReportDetail(String id) async {
    try {
      final response = await _dio.get('/reports/$id');
      return ReportResponse.fromJson(response.data);
    } on DioException catch (e) {
      throw Exception(e.response?.data['message'] ?? 'Detay alınamadı');
    }
  }

  Future<void> createReport(Map<String, dynamic> payload, String filePath) async {
    try {
      // 1. Get capture session token
      final sessionResp = await _dio.post('/reports/capture-sessions');
      final String sessionToken = sessionResp.data['sessionToken'];

      payload['captureSessionToken'] = sessionToken;

      // 2. Create Multipart Form Data
      final formData = FormData();

      // Spring Boot expects "payload" as application/json and "files" as multipart
      formData.files.add(MapEntry(
        'payload',
        MultipartFile.fromString(
          // Using a simple JSON string representation for the DTO
          '{"title":"${payload['title']}", "description":"${payload['description']}", "category":"${payload['category']}", "latitude":${payload['latitude']}, "longitude":${payload['longitude']}, "addressText":"${payload['addressText']}", "incidentAt":"${DateTime.now().toIso8601String()}", "captureSessionToken":"$sessionToken"}',
          filename: 'payload.json',
          contentType: DioMediaType('application', 'json'),
        ),
      ));

      formData.files.add(MapEntry(
        'files',
        await MultipartFile.fromFile(filePath, filename: filePath.split('/').last),
      ));

      await _dio.post(
        '/reports',
        data: formData,
        options: Options(
          headers: {'Content-Type': 'multipart/form-data'},
        ),
      );
    } on DioException catch (e) {
      throw Exception(e.response?.data['message'] ?? 'İhbar oluşturulamadı');
    }
  }
}

// State provider to fetch reports automatically
final myReportsProvider = FutureProvider<List<ReportResponse>>((ref) async {
  final repository = ref.watch(reportRepositoryProvider);
  return repository.getMyReports();
});

final reportDetailProvider = FutureProvider.family<ReportResponse, String>((ref, id) async {
  final repository = ref.watch(reportRepositoryProvider);
  return repository.getReportDetail(id);
});
