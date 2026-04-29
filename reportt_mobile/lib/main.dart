import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'offline/sync_worker.dart';
import 'features/reports/data/report_repository.dart';
import 'services/push_notification_service.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'core/l10n/app_localizations_delegate.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // V3: Firebase Push Notification başlat
  await PushNotificationService.initialize();

  runApp(
    const ProviderScope(
      child: ReporttApp(),
    ),
  );
}

class ReporttApp extends ConsumerStatefulWidget {
  const ReporttApp({super.key});

  @override
  ConsumerState<ReporttApp> createState() => _ReporttAppState();
}

class _ReporttAppState extends ConsumerState<ReporttApp> {
  @override
  void initState() {
    super.initState();
    // V2 Modül 6: Çevrimdışı senkronizasyon worker'ını başlat
    _initSyncWorker();
  }

  void _initSyncWorker() {
    // Widget ağacı hazır olduğunda repository'yi al ve sync worker'ı başlat
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final repository = ref.read(reportRepositoryProvider);
      SyncWorker.instance.startListening(repository);
    });
  }

  @override
  void dispose() {
    SyncWorker.instance.stopListening();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(appRouterProvider);

    return MaterialApp.router(
      title: 'Reportt',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
      localizationsDelegates: const [
        AppLocalizationsDelegate(),
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('tr', ''),
        Locale('en', ''),
        Locale('ar', ''),
      ],
    );
  }
}
