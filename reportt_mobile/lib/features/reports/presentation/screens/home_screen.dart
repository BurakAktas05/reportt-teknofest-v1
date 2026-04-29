import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:gap/gap.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../data/report_repository.dart';
import '../../../auth/data/auth_repository.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reportsAsyncValue = ref.watch(myReportsProvider);
    final roleFuture = ref.watch(authRepositoryProvider).getSavedRole();

    return FutureBuilder<String?>(
      future: roleFuture,
      builder: (context, roleSnapshot) {
        final isOfficer = roleSnapshot.data == 'OFFICER';

        return Scaffold(
          backgroundColor: AppColors.backgroundLight,
          appBar: AppBar(
            elevation: 0,
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            title: Text(isOfficer ? 'Memur Paneli' : 'Reportt Dashboard', style: const TextStyle(fontWeight: FontWeight.bold)),
            actions: [
              IconButton(
                icon: const Icon(Icons.logout),
                onPressed: () {
                  ref.read(authRepositoryProvider).logout();
                  context.go('/');
                },
              ),
            ],
          ),
          body: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: const BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(32),
                      bottomRight: Radius.circular(32),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Hoş Geldiniz,',
                        style: TextStyle(color: Colors.white70, fontSize: 16),
                      ),
                      Text(
                        isOfficer ? 'Emniyet Görevlisi' : 'Vatandaş',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Gap(24),
                      Row(
                        children: [
                          _buildStatCard(isOfficer ? 'Bekleyen' : 'Toplam İhbar', '...', Icons.assignment),
                          const Gap(16),
                          _buildStatCard(isOfficer ? 'Bölgem' : 'Puan', isOfficer ? 'Karakol' : '100', isOfficer ? Icons.location_city : Icons.star),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: Gap(24)),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        isOfficer ? 'İşlem Bekleyenler' : 'Son İhbarlarım',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      TextButton(
                        onPressed: () {
                          ref.invalidate(myReportsProvider);
                        },
                        child: const Text('Yenile'),
                      )
                    ],
                  ),
                ),
              ),
              reportsAsyncValue.when(
                data: (reports) {
                  if (reports.isEmpty) {
                    return const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.all(40.0),
                        child: Center(child: Text('Henüz görüntülenecek bir veri yok.')),
                      ),
                    );
                  }
                  return SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          return _buildReportCard(context, reports[index]);
                        },
                        childCount: reports.length,
                      ),
                    ),
                  );
                },
                loading: () => const SliverToBoxAdapter(
                  child: Center(child: Padding(
                    padding: EdgeInsets.all(40.0),
                    child: CircularProgressIndicator(),
                  )),
                ),
                error: (err, stack) => SliverToBoxAdapter(
                  child: Center(child: Padding(
                    padding: const EdgeInsets.all(40.0),
                    child: Text('Hata: $err', style: const TextStyle(color: AppColors.error)),
                  )),
                ),
              ),
            ],
          ),
          floatingActionButton: isOfficer ? null : FloatingActionButton.extended(
            onPressed: () {
              context.push('/create_report');
            },
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            icon: const Icon(Icons.add_a_photo),
            label: const Text('Yeni İhbar', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        );
      },
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.15),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withOpacity(0.2)),
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.white, size: 28),
            const Gap(12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: Colors.white70, fontSize: 12)),
                Text(value, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
              ],
            )
          ],
        ),
      ),
    );
  }

  Widget _buildReportCard(BuildContext context, ReportResponse report) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            context.push('/report_detail/${report.id}');
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: AppColors.backgroundLight,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.assignment_late, color: AppColors.primary),
                ),
                const Gap(16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        report.title.isNotEmpty ? report.title : report.category,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 16),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const Gap(4),
                      Text(
                        report.addressText,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 12),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _getStatusColor(report.status).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    _translateStatus(report.status),
                    style: TextStyle(color: _getStatusColor(report.status), fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                )
              ],
            ),
          ),
        ),
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
