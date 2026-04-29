import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../services/sse_listener.dart';
import '../../../../services/push_notification_service.dart';
import '../../data/report_repository.dart';
import 'home_screen.dart';
import 'map_screen.dart';
import 'profile_screen.dart';

/// Ana navigasyon hub'ı — Bottom Navigation Bar ile Dashboard, Harita ve Profil arası geçiş.
class MainShell extends ConsumerStatefulWidget {
  const MainShell({super.key});

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell> {
  int _currentIndex = 0;
  final SseListener _sseListener = SseListener();

  final _pages = const [
    _DashboardPage(),
    MapScreen(),
    ProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _connectSse();
    _setupFcmCallbacks();
  }

  /// V3: SSE gerçek zamanlı bildirim bağlantısı
  void _connectSse() {
    _sseListener.connect(
      onReportUpdate: (data) {
        // İhbar listesini yenile
        ref.invalidate(myReportsProvider);
        ref.invalidate(statsProvider);
        if (mounted) {
          final status = data['newStatus'] ?? '';
          final message = data['message'] ?? 'İhbarınız güncellendi.';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.notifications_active, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  Expanded(child: Text(message)),
                ],
              ),
              backgroundColor: status == 'VERIFIED' ? Colors.green : AppColors.primary,
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 4),
            ),
          );
        }
      },
      onBadgeEarned: (data) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('🏅 Rozet kazandınız: ${data['title'] ?? 'Yeni rozet!'}'),
              backgroundColor: Colors.amber.shade700,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      },
      onConnected: () {
        debugPrint('[MainShell] SSE bağlantısı kuruldu.');
      },
      onError: (error) {
        debugPrint('[MainShell] SSE hatası: $error');
      },
    );
  }

  /// V3: FCM foreground bildirim callback
  void _setupFcmCallbacks() {
    PushNotificationService.setOnMessageCallback((message) {
      if (mounted) {
        final title = message.notification?.title ?? 'Bildirim';
        final body = message.notification?.body ?? '';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
                if (body.isNotEmpty) Text(body, style: const TextStyle(fontSize: 12)),
              ],
            ),
            backgroundColor: AppColors.primary,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 5),
          ),
        );
        // İhbar listesini yenile
        ref.invalidate(myReportsProvider);
      }
    });

    PushNotificationService.setOnTapCallback((message) {
      final reportId = message.data['reportId'];
      if (reportId != null && mounted) {
        context.push('/report_detail/$reportId');
      }
    });
  }

  @override
  void dispose() {
    _sseListener.disconnect();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (i) => setState(() => _currentIndex = i),
        backgroundColor: Colors.white,
        elevation: 8,
        indicatorColor: AppColors.primary.withValues(alpha: 0.1),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard, color: AppColors.primary),
            label: 'Ana Sayfa',
          ),
          NavigationDestination(
            icon: Icon(Icons.map_outlined),
            selectedIcon: Icon(Icons.map, color: AppColors.primary),
            label: 'Harita',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person, color: AppColors.primary),
            label: 'Profil',
          ),
        ],
      ),
      floatingActionButton: _currentIndex == 0
          ? FloatingActionButton.extended(
              heroTag: 'createReport',
              onPressed: () => context.push('/create_report'),
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add_a_photo),
              label: const Text('Yeni İhbar', style: TextStyle(fontWeight: FontWeight.bold)),
            )
          : null,
    );
  }
}

/// HomeScreen'den dashboard kısmını extract eden widget.
class _DashboardPage extends ConsumerWidget {
  const _DashboardPage();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const HomeScreen();
  }
}

