import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../core/theme/app_colors.dart';
import '../../data/report_repository.dart';

class ReportDetailScreen extends ConsumerWidget {
  final String reportId;

  const ReportDetailScreen({super.key, required this.reportId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailAsync = ref.watch(reportDetailProvider(reportId));

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      body: detailAsync.when(
        data: (report) => CustomScrollView(
          slivers: [
            // Kanıt fotoğrafı header
            SliverAppBar(
              expandedHeight: 280.0,
              floating: false,
              pinned: true,
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              flexibleSpace: FlexibleSpaceBar(
                title: const Text('İhbar Detayı', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                background: report.evidences.isNotEmpty
                    ? _EvidenceImageWidget(
                        evidenceId: report.evidences.first.id,
                        repository: ref.read(reportRepositoryProvider),
                      )
                    : Container(
                        color: AppColors.backgroundDark,
                        child: Center(child: Icon(Icons.image, size: 80, color: Colors.white.withValues(alpha: 0.2))),
                      ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Status + Urgency Row
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: _getStatusColor(report.status).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            _translateStatus(report.status),
                            style: TextStyle(color: _getStatusColor(report.status), fontWeight: FontWeight.bold),
                          ),
                        ),
                        const Gap(8),
                        if (report.urgencyScore >= 5)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: report.urgencyScore >= 8
                                  ? Colors.red.withValues(alpha: 0.1)
                                  : Colors.orange.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(report.urgencyScore >= 8 ? '🔥' : '⚠️', style: const TextStyle(fontSize: 14)),
                                const Gap(4),
                                Text(
                                  'Aciliyet ${report.urgencyScore}/10',
                                  style: TextStyle(
                                    color: report.urgencyScore >= 8 ? Colors.red : Colors.orange,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        const Spacer(),
                        if (report.deviceVerified)
                          Tooltip(
                            message: 'Cihaz doğrulandı',
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: Colors.green.withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.verified_user, color: Colors.green, size: 18),
                            ),
                          ),
                      ],
                    ),
                    const Gap(20),

                    // Başlık
                    Text(
                      report.title.isNotEmpty ? report.title : report.category,
                      style: Theme.of(context).textTheme.displayLarge?.copyWith(fontSize: 22),
                    ),
                    const Gap(8),
                    Row(
                      children: [
                        const Icon(Icons.location_on, color: AppColors.primary, size: 18),
                        const Gap(6),
                        Expanded(child: Text(report.addressText, style: Theme.of(context).textTheme.bodyMedium)),
                      ],
                    ),
                    if (report.assignedStationName != null) ...[
                      const Gap(16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.accent.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.accent.withValues(alpha: 0.2)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.local_police, color: AppColors.accent, size: 24),
                            const Gap(12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Sorumlu Karakol', style: TextStyle(fontSize: 12, color: AppColors.accent, fontWeight: FontWeight.bold)),
                                  const Gap(2),
                                  Text(report.assignedStationName!, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    const Gap(20),
                    const Divider(),
                    const Gap(16),

                    // V2: AI Triage bilgisi
                    if (report.aiTriageSummary != null && report.aiTriageSummary!.isNotEmpty) ...[
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.info.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.info.withValues(alpha: 0.2)),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.smart_toy, color: AppColors.info, size: 20),
                            const Gap(12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('AI Triyaj Özeti', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.info)),
                                  const Gap(4),
                                  Text(report.aiTriageSummary!, style: const TextStyle(fontSize: 12)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Gap(16),
                    ],

                    // Trust bypass göstergesi
                    if (report.bypassAnalysis) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.green.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.green.withValues(alpha: 0.2)),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.verified, color: Colors.green, size: 18),
                            Gap(8),
                            Expanded(child: Text('Güvenilir vatandaş — AI analizi atlandı.', style: TextStyle(fontSize: 12, color: Colors.green))),
                          ],
                        ),
                      ),
                      const Gap(16),
                    ],

                    // Açıklama
                    Text('Açıklama', style: Theme.of(context).textTheme.titleLarge),
                    const Gap(8),
                    Text(report.description, style: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.6)),
                    const Gap(24),

                    // Kanıt dosyaları
                    if (report.evidences.isNotEmpty) ...[
                      Text('Kanıtlar (${report.evidences.length})', style: Theme.of(context).textTheme.titleLarge),
                      const Gap(12),
                      ...report.evidences.map((e) => _buildEvidenceCard(context, ref, e)),
                      const Gap(16),
                    ],

                    // Geri bildirimler
                    if (report.feedback.isNotEmpty) ...[
                      Text('Süreç Takibi', style: Theme.of(context).textTheme.titleLarge),
                      const Gap(12),
                      ...report.feedback.map((f) => _buildFeedbackCard(context, f)),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Hata: $err', style: const TextStyle(color: AppColors.error))),
      ),
    );
  }

  Widget _buildEvidenceCard(BuildContext context, WidgetRef ref, EvidenceItem evidence) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(evidence.evidenceType == 'VIDEO' ? Icons.videocam : Icons.photo_camera,
                  color: AppColors.primary, size: 20),
              const Gap(8),
              Expanded(
                child: Text(evidence.originalFileName,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
              // Hash durumu
              if (evidence.hashVerified)
                Tooltip(
                  message: 'Dijital mühür doğrulandı',
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(color: Colors.green.withValues(alpha: 0.1), shape: BoxShape.circle),
                    child: const Icon(Icons.lock, color: Colors.green, size: 14),
                  ),
                ),
            ],
          ),
          if (evidence.analysisSummary != null) ...[
            const Gap(8),
            Text(evidence.analysisSummary!, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
          ],
          if (evidence.outdoorConfidence != null || evidence.selfieRisk != null) ...[
            const Gap(8),
            Row(
              children: [
                if (evidence.outdoorConfidence != null)
                  _miniGauge('Dış Mekan', evidence.outdoorConfidence!, Colors.blue),
                if (evidence.outdoorConfidence != null && evidence.selfieRisk != null) const Gap(16),
                if (evidence.selfieRisk != null)
                  _miniGauge('Selfie Risk', evidence.selfieRisk!, Colors.orange),
              ],
            ),
          ],
          if (evidence.sha256Hash != null) ...[
            const Gap(6),
            Text('SHA-256: ${evidence.sha256Hash!.substring(0, 20)}...', style: TextStyle(fontSize: 9, fontFamily: 'monospace', color: Colors.grey.shade500)),
          ],
        ],
      ),
    );
  }

  Widget _miniGauge(String label, double value, Color color) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
          const Gap(3),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: value,
              backgroundColor: Colors.grey.shade200,
              color: color,
              minHeight: 6,
            ),
          ),
          const Gap(2),
          Text('${(value * 100).toStringAsFixed(0)}%', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }

  Widget _buildFeedbackCard(BuildContext context, FeedbackItem feedback) {
    final isSystem = feedback.role == 'CITIZEN';
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  color: isSystem ? AppColors.info : AppColors.success,
                  shape: BoxShape.circle,
                ),
              ),
              Container(width: 2, height: 30, color: Colors.grey.shade200),
            ],
          ),
          const Gap(14),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: (isSystem ? AppColors.info : AppColors.success).withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: (isSystem ? AppColors.info : AppColors.success).withValues(alpha: 0.15)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(feedback.authorName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                      if (feedback.createdAt != null)
                        Text(feedback.createdAt!.substring(0, 10), style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
                    ],
                  ),
                  const Gap(4),
                  Text(feedback.message, style: const TextStyle(fontSize: 12)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _translateStatus(String status) {
    switch (status) {
      case 'PENDING_ANALYSIS': return 'Analiz Ediliyor';
      case 'SUBMITTED': return 'İletildi';
      case 'UNDER_REVIEW': return 'İnceleniyor';
      case 'VERIFIED': return 'Onaylandı';
      case 'REJECTED': return 'Reddedildi';
      case 'REJECTED_BY_SYSTEM': return 'Sistem Reddi';
      case 'CLOSED': return 'Kapatıldı';
      default: return status;
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'PENDING_ANALYSIS': return AppColors.warning;
      case 'SUBMITTED': return AppColors.info;
      case 'UNDER_REVIEW': return AppColors.primary;
      case 'VERIFIED': return AppColors.success;
      case 'REJECTED':
      case 'REJECTED_BY_SYSTEM': return AppColors.error;
      case 'CLOSED': return AppColors.textSecondaryLight;
      default: return AppColors.info;
    }
  }
}

/// Presigned URL ile kanıt fotoğrafı yükleyen widget.
class _EvidenceImageWidget extends StatefulWidget {
  final int evidenceId;
  final ReportRepository repository;

  const _EvidenceImageWidget({required this.evidenceId, required this.repository});

  @override
  State<_EvidenceImageWidget> createState() => _EvidenceImageWidgetState();
}

class _EvidenceImageWidgetState extends State<_EvidenceImageWidget> {
  String? _imageUrl;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadUrl();
  }

  Future<void> _loadUrl() async {
    try {
      final url = await widget.repository.getEvidenceUrl(widget.evidenceId);
      if (mounted) setState(() { _imageUrl = url; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Container(
        color: AppColors.backgroundDark,
        child: const Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }

    if (_imageUrl == null) {
      return Container(
        color: AppColors.backgroundDark,
        child: Center(child: Icon(Icons.image_not_supported, size: 60, color: Colors.white.withValues(alpha: 0.3))),
      );
    }

    return CachedNetworkImage(
      imageUrl: _imageUrl!,
      fit: BoxFit.cover,
      placeholder: (_, _) => Container(
        color: AppColors.backgroundDark,
        child: const Center(child: CircularProgressIndicator(color: Colors.white)),
      ),
      errorWidget: (_, _, _) => Container(
        color: AppColors.backgroundDark,
        child: Center(child: Icon(Icons.broken_image, size: 60, color: Colors.white.withValues(alpha: 0.3))),
      ),
    );
  }
}
