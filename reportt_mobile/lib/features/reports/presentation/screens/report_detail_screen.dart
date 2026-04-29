import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
            SliverAppBar(
              expandedHeight: 250.0,
              floating: false,
              pinned: true,
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              flexibleSpace: FlexibleSpaceBar(
                title: const Text('İhbar Detayı', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                background: Container(
                  color: AppColors.backgroundDark,
                  child: Center(
                    child: Icon(Icons.image, size: 80, color: Colors.white.withOpacity(0.2)),
                  ), // TODO: NetworkImage
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: _getStatusColor(report.status).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            _translateStatus(report.status),
                            style: TextStyle(color: _getStatusColor(report.status), fontWeight: FontWeight.bold),
                          ),
                        ),
                        Text('Güncel', style: Theme.of(context).textTheme.bodyMedium),
                      ],
                    ),
                    const Gap(24),
                    Text(
                      report.title.isNotEmpty ? report.title : report.category,
                      style: Theme.of(context).textTheme.displayLarge?.copyWith(fontSize: 24),
                    ),
                    const Gap(8),
                    Row(
                      children: [
                        const Icon(Icons.location_on, color: AppColors.primary, size: 20),
                        const Gap(8),
                        Text(report.addressText, style: Theme.of(context).textTheme.bodyMedium),
                      ],
                    ),
                    const Gap(24),
                    const Divider(),
                    const Gap(24),
                    Text('Açıklama', style: Theme.of(context).textTheme.titleLarge),
                    const Gap(8),
                    Text(
                      report.description,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.5),
                    ),
                    const Gap(32),
                    Text('Süreç Takibi', style: Theme.of(context).textTheme.titleLarge),
                    const Gap(16),
                    _buildTimelineItem(context, 'İhbar Alındı', 'Sistem kaydınız başarıyla oluşturuldu.', 'Tamamlandı', true),
                    if (report.status != 'SUBMITTED')
                      _buildTimelineItem(context, 'Karakola İletildi', 'İlgili birimlere lokasyon bazlı sevk yapıldı.', 'Tamamlandı', true),
                  ],
                ),
              ),
            )
          ],
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Hata: $err', style: const TextStyle(color: AppColors.error))),
      ),
    );
  }

  Widget _buildTimelineItem(BuildContext context, String title, String desc, String time, bool isDone, {bool isFeedback = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  color: isDone ? AppColors.success : (isFeedback ? AppColors.accent : Colors.grey.shade300),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
              ),
              if (!isFeedback)
                Container(
                  width: 2,
                  height: 40,
                  color: Colors.grey.shade200,
                )
            ],
          ),
          const Gap(16),
          Expanded(
            child: Container(
              padding: EdgeInsets.all(isFeedback ? 16 : 0),
              decoration: isFeedback ? BoxDecoration(
                color: AppColors.accent.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.accent.withOpacity(0.2)),
              ) : null,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(title, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 16)),
                      Text(time, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 12)),
                    ],
                  ),
                  const Gap(4),
                  Text(desc, style: Theme.of(context).textTheme.bodyMedium),
                ],
              ),
            ),
          )
        ],
      ),
    );
  }

  String _translateStatus(String status) {
    switch(status) {
      case 'PENDING_ANALYSIS': return 'Analiz Ediliyor';
      case 'SUBMITTED': return 'İletildi';
      case 'UNDER_REVIEW': return 'İnceleniyor';
      case 'VERIFIED': return 'Onaylandı';
      case 'REJECTED': return 'Reddedildi';
      case 'REJECTED_BY_SYSTEM': return 'Sistemden Red (Spam)';
      case 'CLOSED': return 'Kapatıldı';
      default: return status;
    }
  }

  Color _getStatusColor(String status) {
    switch(status) {
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
