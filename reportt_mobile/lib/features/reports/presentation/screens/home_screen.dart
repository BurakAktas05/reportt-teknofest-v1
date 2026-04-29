import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:gap/gap.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../data/report_repository.dart';
import '../../../auth/data/auth_repository.dart';

/// Dashboard sayfası — yalnızca ihbar listesi ve istatistik gösterir.
/// Bottom navigation MainShell tarafından yönetilir.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reportsAsync = ref.watch(myReportsProvider);
    final statsAsync = ref.watch(statsProvider);
    final roleFuture = ref.watch(authRepositoryProvider).getSavedRole();

    return FutureBuilder<String?>(
      future: roleFuture,
      builder: (context, roleSnapshot) {
        final isOfficer = roleSnapshot.data == 'OFFICER';

        return CustomScrollView(
          slivers: [
            // Hero Header
            SliverToBoxAdapter(
              child: Container(
                padding: const EdgeInsets.fromLTRB(24, 56, 24, 24),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [AppColors.primaryDark, AppColors.primary],
                  ),
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(32),
                    bottomRight: Radius.circular(32),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Hoş Geldiniz,', style: TextStyle(color: Colors.white70, fontSize: 14)),
                            Text(
                              isOfficer ? 'Emniyet Görevlisi' : 'Vatandaş',
                              style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        IconButton(
                          icon: const Icon(Icons.logout, color: Colors.white70),
                          onPressed: () {
                            ref.read(authRepositoryProvider).logout();
                            context.go('/');
                          },
                        ),
                      ],
                    ),
                    const Gap(20),
                    statsAsync.when(
                      data: (stats) => Row(
                        children: [
                          _buildStatCard(
                            isOfficer ? 'Bekleyen' : 'Toplam',
                            isOfficer ? '${stats.pendingCount ?? 0}' : '${stats.totalReports}',
                            isOfficer ? Icons.pending_actions : Icons.assignment,
                          ),
                          const Gap(12),
                          _buildStatCard(
                            isOfficer ? 'Acil' : 'Puan',
                            isOfficer ? '${stats.urgentCount ?? 0}' : '${stats.reputationScore ?? 0}',
                            isOfficer ? Icons.warning_amber : Icons.star,
                          ),
                          const Gap(12),
                          _buildStatCard(
                            isOfficer ? 'Toplam' : 'Onaylı',
                            isOfficer ? '${stats.totalReports}' : '${stats.verifiedCount}',
                            isOfficer ? Icons.summarize : Icons.check_circle,
                          ),
                        ],
                      ),
                      loading: () => const Center(child: CircularProgressIndicator(color: Colors.white)),
                      error: (_, _) => Row(
                        children: [
                          _buildStatCard('Toplam', '—', Icons.assignment),
                          const Gap(12),
                          _buildStatCard('Puan', '—', Icons.star),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SliverToBoxAdapter(child: Gap(20)),

            // İhbar listesi başlığı
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
                    TextButton.icon(
                      onPressed: () {
                        ref.invalidate(myReportsProvider);
                        ref.invalidate(statsProvider);
                      },
                      icon: const Icon(Icons.refresh, size: 18),
                      label: const Text('Yenile'),
                    ),
                  ],
                ),
              ),
            ),

            // İhbar listesi
            reportsAsync.when(
              data: (reports) {
                if (reports.isEmpty) {
                  return SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(40),
                      child: Column(
                        children: [
                          Icon(Icons.inbox_rounded, size: 64, color: Colors.grey.shade300),
                          const Gap(16),
                          Text('Henüz ihbar yok.', style: TextStyle(color: Colors.grey.shade500)),
                          const Gap(8),
                          Text('Aşağıdaki "Yeni İhbar" butonuyla başlayabilirsiniz.',
                              style: TextStyle(color: Colors.grey.shade400, fontSize: 12)),
                        ],
                      ),
                    ),
                  );
                }
                return SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) => _buildReportCard(context, reports[index]),
                      childCount: reports.length,
                    ),
                  ),
                );
              },
              loading: () => const SliverToBoxAdapter(
                child: Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator())),
              ),
              error: (err, _) => SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(40),
                  child: Text('Hata: $err', style: const TextStyle(color: AppColors.error)),
                ),
              ),
            ),

            // Boşluk
            const SliverToBoxAdapter(child: Gap(80)),
          ],
        );
      },
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
        ),
        child: Column(
          children: [
            Icon(icon, color: Colors.white, size: 22),
            const Gap(6),
            Text(value, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
            Text(title, style: const TextStyle(color: Colors.white70, fontSize: 10)),
          ],
        ),
      ),
    );
  }

  Widget _buildReportCard(BuildContext context, ReportResponse report) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => context.push('/report_detail/${report.id}'),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: _getCategoryColor(report.category).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(_getCategoryIcon(report.category), color: _getCategoryColor(report.category), size: 24),
                ),
                const Gap(14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        report.title.isNotEmpty ? report.title : _translateCategory(report.category),
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const Gap(2),
                      Text(report.addressText,
                          style: TextStyle(fontSize: 11, color: Colors.grey.shade600), maxLines: 1, overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: _getStatusColor(report.status).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        _translateStatus(report.status),
                        style: TextStyle(color: _getStatusColor(report.status), fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ),
                    if (report.urgencyScore >= 7) ...[
                      const Gap(4),
                      Text('🔥 ${report.urgencyScore}/10', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _translateCategory(String cat) {
    switch (cat) {
      case 'VIOLENCE': return 'Şiddet';
      case 'SECURITY': return 'Güvenlik';
      case 'TRAFFIC_OFFENSE': return 'Trafik';
      case 'PARKING_VIOLATION': return 'Hatalı Park';
      case 'ENVIRONMENTAL': return 'Çevre';
      case 'VANDALISM': return 'Vandalizm';
      case 'INFRASTRUCTURE': return 'Altyapı';
      default: return 'Diğer';
    }
  }

  IconData _getCategoryIcon(String cat) {
    switch (cat) {
      case 'VIOLENCE': return Icons.warning_rounded;
      case 'SECURITY': return Icons.shield;
      case 'TRAFFIC_OFFENSE': return Icons.directions_car;
      case 'PARKING_VIOLATION': return Icons.local_parking;
      case 'ENVIRONMENTAL': return Icons.eco;
      case 'VANDALISM': return Icons.broken_image;
      case 'INFRASTRUCTURE': return Icons.construction;
      default: return Icons.report;
    }
  }

  Color _getCategoryColor(String cat) {
    switch (cat) {
      case 'VIOLENCE': return Colors.red;
      case 'SECURITY': return Colors.orange;
      case 'TRAFFIC_OFFENSE': return Colors.blue;
      case 'PARKING_VIOLATION': return Colors.purple;
      case 'ENVIRONMENTAL': return Colors.green;
      case 'VANDALISM': return Colors.brown;
      case 'INFRASTRUCTURE': return Colors.teal;
      default: return Colors.grey;
    }
  }

  String _translateStatus(String s) {
    switch (s) {
      case 'PENDING_ANALYSIS': return 'Analiz';
      case 'SUBMITTED': return 'İletildi';
      case 'UNDER_REVIEW': return 'İnceleme';
      case 'VERIFIED': return 'Onaylı';
      case 'REJECTED': return 'Red';
      case 'REJECTED_BY_SYSTEM': return 'Spam';
      case 'CLOSED': return 'Kapalı';
      default: return s;
    }
  }

  Color _getStatusColor(String s) {
    switch (s) {
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
