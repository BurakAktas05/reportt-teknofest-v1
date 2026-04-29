import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/dio_client.dart';

final reportRepositoryProvider = Provider<ReportRepository>((ref) {
  final dio = ref.watch(dioProvider);
  return ReportRepository(dio);
});

class ReportResponse {
  final int id;
  final String title;
  final String description;
  final String status;
  final String category;
  final String addressText;
  final double? latitude;
  final double? longitude;
  final int urgencyScore;
  final bool deviceVerified;
  final String? aiTriageSummary;
  final bool bypassAnalysis;
  final String? citizenName;
  final int? citizenScore;
  final String? assignedStationName;
  final String? createdAt;
  final List<EvidenceItem> evidences;
  final List<FeedbackItem> feedback;

  ReportResponse({
    required this.id,
    required this.title,
    required this.description,
    required this.status,
    required this.category,
    required this.addressText,
    this.latitude,
    this.longitude,
    this.urgencyScore = 0,
    this.deviceVerified = false,
    this.aiTriageSummary,
    this.bypassAnalysis = false,
    this.citizenName,
    this.citizenScore,
    this.assignedStationName,
    this.createdAt,
    this.evidences = const [],
    this.feedback = const [],
  });

  factory ReportResponse.fromJson(Map<String, dynamic> json) {
    return ReportResponse(
      id: json['id'] ?? 0,
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      status: json['status'] ?? 'UNKNOWN',
      category: json['category'] ?? '',
      addressText: json['addressText'] ?? '',
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      urgencyScore: json['urgencyScore'] ?? 0,
      deviceVerified: json['deviceVerified'] ?? false,
      aiTriageSummary: json['aiTriageSummary'],
      bypassAnalysis: json['bypassAnalysis'] ?? false,
      citizenName: json['citizenName'],
      citizenScore: json['citizenScore'],
      assignedStationName: json['assignedStationName'],
      createdAt: json['createdAt'],
      evidences: (json['evidences'] as List<dynamic>?)
              ?.map((e) => EvidenceItem.fromJson(e))
              .toList() ??
          [],
      feedback: (json['feedback'] as List<dynamic>?)
              ?.map((e) => FeedbackItem.fromJson(e))
              .toList() ??
          [],
    );
  }
}

class EvidenceItem {
  final int id;
  final String evidenceType;
  final String originalFileName;
  final String contentType;
  final String? analysisStatus;
  final String? analysisSummary;
  final double? outdoorConfidence;
  final double? selfieRisk;
  final String? sha256Hash;
  final bool hashVerified;

  EvidenceItem({
    required this.id,
    required this.evidenceType,
    required this.originalFileName,
    required this.contentType,
    this.analysisStatus,
    this.analysisSummary,
    this.outdoorConfidence,
    this.selfieRisk,
    this.sha256Hash,
    this.hashVerified = false,
  });

  factory EvidenceItem.fromJson(Map<String, dynamic> json) {
    return EvidenceItem(
      id: json['id'] ?? 0,
      evidenceType: json['evidenceType'] ?? 'PHOTO',
      originalFileName: json['originalFileName'] ?? '',
      contentType: json['contentType'] ?? '',
      analysisStatus: json['analysisStatus'],
      analysisSummary: json['analysisSummary'],
      outdoorConfidence: (json['outdoorConfidence'] as num?)?.toDouble(),
      selfieRisk: (json['selfieRisk'] as num?)?.toDouble(),
      sha256Hash: json['sha256Hash'],
      hashVerified: json['hashVerified'] ?? false,
    );
  }
}

class FeedbackItem {
  final int id;
  final String authorName;
  final String role;
  final String message;
  final bool internalNote;
  final String? createdAt;

  FeedbackItem({
    required this.id,
    required this.authorName,
    required this.role,
    required this.message,
    this.internalNote = false,
    this.createdAt,
  });

  factory FeedbackItem.fromJson(Map<String, dynamic> json) {
    return FeedbackItem(
      id: json['id'] ?? 0,
      authorName: json['authorName'] ?? '',
      role: json['role'] ?? '',
      message: json['message'] ?? '',
      internalNote: json['internalNote'] ?? false,
      createdAt: json['createdAt'],
    );
  }
}

class StatsData {
  final int totalReports;
  final int? reputationScore;
  final int verifiedCount;
  final int rejectedCount;
  final double approvalRate;
  final int reportsThisWeek;
  final String? trustLevel;
  final List<BadgeData> badges;
  final int? pendingCount;
  final int? urgentCount;
  final List<DailyCountData> weeklyTrend;

  StatsData({
    required this.totalReports,
    this.reputationScore,
    this.verifiedCount = 0,
    this.rejectedCount = 0,
    this.approvalRate = 0.0,
    this.reportsThisWeek = 0,
    this.trustLevel,
    this.badges = const [],
    this.pendingCount,
    this.urgentCount,
    this.weeklyTrend = const [],
  });

  factory StatsData.fromJson(Map<String, dynamic> json) {
    return StatsData(
      totalReports: json['totalReports'] ?? 0,
      reputationScore: json['reputationScore'],
      verifiedCount: json['verifiedCount'] ?? 0,
      rejectedCount: json['rejectedCount'] ?? 0,
      approvalRate: (json['approvalRate'] as num?)?.toDouble() ?? 0.0,
      reportsThisWeek: json['reportsThisWeek'] ?? 0,
      trustLevel: json['trustLevel'],
      badges: (json['badges'] as List<dynamic>?)
              ?.map((e) => BadgeData.fromJson(e))
              .toList() ??
          [],
      pendingCount: json['pendingCount'],
      urgentCount: json['urgentCount'],
      weeklyTrend: (json['weeklyTrend'] as List<dynamic>?)
              ?.map((e) => DailyCountData.fromJson(e))
              .toList() ??
          [],
    );
  }
}

class BadgeData {
  final String id;
  final String icon;
  final String title;
  final String description;
  final bool earned;

  BadgeData({required this.id, required this.icon, required this.title, required this.description, required this.earned});

  factory BadgeData.fromJson(Map<String, dynamic> json) {
    return BadgeData(
      id: json['id'] ?? '',
      icon: json['icon'] ?? '🏅',
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      earned: json['earned'] ?? false,
    );
  }
}

class DailyCountData {
  final String date;
  final int count;

  DailyCountData({required this.date, required this.count});

  factory DailyCountData.fromJson(Map<String, dynamic> json) {
    return DailyCountData(
      date: json['date'] ?? '',
      count: json['count'] ?? 0,
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

  Future<StatsData> getStats() async {
    try {
      final response = await _dio.get('/analytics/stats');
      return StatsData.fromJson(response.data);
    } on DioException catch (e) {
      throw Exception(e.response?.data['message'] ?? 'İstatistikler alınamadı');
    }
  }

  Future<String> getEvidenceUrl(int evidenceId) async {
    try {
      final response = await _dio.get('/evidence/$evidenceId/url');
      return response.data['url'] as String;
    } on DioException {
      throw Exception('Fotoğraf URL alınamadı');
    }
  }

  Future<void> createReport(
    Map<String, dynamic> payload,
    String filePath, {
    String? evidenceHash,
    String? deviceAttestationToken,
    int? clientUrgencyScore,
    String? offlineCreatedAt,
  }) async {
    try {
      final sessionResp = await _dio.post('/reports/capture-sessions');
      final String sessionToken = sessionResp.data['sessionToken'];

      final Map<String, dynamic> reportData = {
        'title': payload['title'],
        'description': payload['description'],
        'category': payload['category'],
        'latitude': payload['latitude'],
        'longitude': payload['longitude'],
        'addressText': payload['addressText'],
        'incidentAt': payload['incidentAt'] ?? DateTime.now().toIso8601String().split('.').first,
        'captureSessionToken': sessionToken,
      };

      if (evidenceHash != null) reportData['evidenceHashes'] = [evidenceHash];
      if (deviceAttestationToken != null) reportData['deviceAttestationToken'] = deviceAttestationToken;
      if (clientUrgencyScore != null) reportData['clientUrgencyScore'] = clientUrgencyScore;
      if (offlineCreatedAt != null) reportData['offlineCreatedAt'] = offlineCreatedAt;

      final formData = FormData();
      formData.files.add(MapEntry(
        'payload',
        MultipartFile.fromString(jsonEncode(reportData), contentType: DioMediaType('application', 'json')),
      ));
      formData.files.add(MapEntry(
        'files',
        await MultipartFile.fromFile(filePath, filename: filePath.split('/').last),
      ));

      await _dio.post('/reports', data: formData);
    } on DioException catch (e) {
      final errorMsg = e.response?.data is Map
          ? (e.response?.data['userMessage'] ?? e.response?.data['message'])
          : null;
      throw Exception(errorMsg ?? 'İhbar oluşturulamadı.');
    }
  }
}

final myReportsProvider = FutureProvider<List<ReportResponse>>((ref) async {
  final repository = ref.watch(reportRepositoryProvider);
  return repository.getMyReports();
});

final reportDetailProvider = FutureProvider.family<ReportResponse, String>((ref, id) async {
  final repository = ref.watch(reportRepositoryProvider);
  return repository.getReportDetail(id);
});

final statsProvider = FutureProvider<StatsData>((ref) async {
  final repository = ref.watch(reportRepositoryProvider);
  return repository.getStats();
});
