import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../../core/theme/app_colors.dart';
import '../../data/report_repository.dart';

/// Vatandaş Profil & Rozet Ekranı (V3).
/// Güven puanı, onay oranı, rozet koleksiyonu ve haftalık trend grafiğini gösterir.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(statsProvider);

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      body: statsAsync.when(
        data: (stats) => CustomScrollView(
          slivers: [
            // Hero Header
            SliverAppBar(
              expandedHeight: 240,
              pinned: true,
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              flexibleSpace: FlexibleSpaceBar(
                background: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [AppColors.primaryDark, AppColors.primary, AppColors.primaryLight],
                    ),
                  ),
                  child: SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          // Avatar
                          Container(
                            width: 72,
                            height: 72,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white.withValues(alpha: 0.2),
                              border: Border.all(color: Colors.white, width: 3),
                            ),
                            child: const Icon(Icons.person, color: Colors.white, size: 36),
                          ),
                          const Gap(12),
                          Text(
                            _trustLevelLabel(stats.trustLevel),
                            style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          const Gap(4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                            decoration: BoxDecoration(
                              color: _trustLevelColor(stats.trustLevel).withValues(alpha: 0.3),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              '${stats.reputationScore ?? 0} Puan',
                              style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // Stats Cards
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    _statCard('Toplam', '${stats.totalReports}', Icons.assignment, AppColors.info),
                    const Gap(12),
                    _statCard('Onaylı', '${stats.verifiedCount}', Icons.check_circle, AppColors.success),
                    const Gap(12),
                    _statCard('Red', '${stats.rejectedCount}', Icons.cancel, AppColors.error),
                    const Gap(12),
                    _statCard('Bu Hafta', '${stats.reportsThisWeek}', Icons.today, AppColors.warning),
                  ],
                ),
              ),
            ),

            // Onay Oranı Gauge
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4))],
                  ),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 80,
                        height: 80,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            CircularProgressIndicator(
                              value: stats.approvalRate / 100,
                              backgroundColor: Colors.grey.shade200,
                              color: AppColors.success,
                              strokeWidth: 8,
                            ),
                            Text('${stats.approvalRate.toStringAsFixed(0)}%',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                          ],
                        ),
                      ),
                      const Gap(20),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Onay Oranı', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                            const Gap(4),
                            Text(
                              stats.approvalRate >= 80
                                  ? 'Mükemmel! İhbarlarınız güvenilir bulunuyor.'
                                  : stats.approvalRate >= 50
                                      ? 'İyi gidiyorsunuz, devam edin.'
                                      : 'İhbar kalitesini artırarak puanınızı yükseltebilirsiniz.',
                              style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Haftalık Trend
            if (stats.weeklyTrend.isNotEmpty) ...[
              const SliverToBoxAdapter(child: Gap(16)),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4))],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Haftalık Trend', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        const Gap(16),
                        SizedBox(
                          height: 150,
                          child: BarChart(
                            BarChartData(
                              alignment: BarChartAlignment.spaceAround,
                              maxY: stats.weeklyTrend.map((e) => e.count.toDouble()).reduce((a, b) => a > b ? a : b) + 2,
                              barTouchData: BarTouchData(enabled: true),
                              titlesData: FlTitlesData(
                                show: true,
                                bottomTitles: AxisTitles(
                                  sideTitles: SideTitles(
                                    showTitles: true,
                                    getTitlesWidget: (value, meta) {
                                      final idx = value.toInt();
                                      if (idx < stats.weeklyTrend.length) {
                                        final parts = stats.weeklyTrend[idx].date.split('-');
                                        return Text('${parts.last}/${parts[1]}', style: const TextStyle(fontSize: 10));
                                      }
                                      return const Text('');
                                    },
                                  ),
                                ),
                                leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                              ),
                              borderData: FlBorderData(show: false),
                              gridData: const FlGridData(show: false),
                              barGroups: stats.weeklyTrend.asMap().entries.map((entry) {
                                return BarChartGroupData(x: entry.key, barRods: [
                                  BarChartRodData(
                                    toY: entry.value.count.toDouble(),
                                    gradient: const LinearGradient(
                                      colors: [AppColors.primary, AppColors.primaryLight],
                                      begin: Alignment.bottomCenter,
                                      end: Alignment.topCenter,
                                    ),
                                    width: 20,
                                    borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                                  ),
                                ]);
                              }).toList(),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],

            // Rozetler
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(16, 24, 16, 8),
                child: Text('Rozetlerim', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 1.4,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final badge = stats.badges[index];
                    return _badgeCard(badge);
                  },
                  childCount: stats.badges.length,
                ),
              ),
            ),
            const SliverToBoxAdapter(child: Gap(32)),
          ],
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Hata: $err')),
      ),
    );
  }

  Widget _statCard(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8)],
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const Gap(6),
            Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: color)),
            Text(label, style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
          ],
        ),
      ),
    );
  }

  Widget _badgeCard(BadgeData badge) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: badge.earned ? Colors.white : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(16),
        border: badge.earned
            ? Border.all(color: AppColors.success.withValues(alpha: 0.3), width: 2)
            : Border.all(color: Colors.grey.shade300),
        boxShadow: badge.earned
            ? [BoxShadow(color: AppColors.success.withValues(alpha: 0.1), blurRadius: 8)]
            : null,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(badge.icon, style: TextStyle(fontSize: 28, color: badge.earned ? null : Colors.grey)),
          const Gap(6),
          Text(
            badge.title,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 12,
              color: badge.earned ? AppColors.textPrimaryLight : Colors.grey,
            ),
            textAlign: TextAlign.center,
          ),
          const Gap(2),
          Text(
            badge.description,
            style: TextStyle(fontSize: 9, color: Colors.grey.shade500),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  String _trustLevelLabel(String? level) {
    switch (level) {
      case 'TRUSTED': return '🛡️ Güvenilir Vatandaş';
      case 'RELIABLE': return '⭐ Deneyimli İhbarcı';
      case 'ACTIVE': return '📊 Aktif Vatandaş';
      default: return '🆕 Yeni Kullanıcı';
    }
  }

  Color _trustLevelColor(String? level) {
    switch (level) {
      case 'TRUSTED': return Colors.green;
      case 'RELIABLE': return Colors.blue;
      case 'ACTIVE': return Colors.orange;
      default: return Colors.grey;
    }
  }
}
