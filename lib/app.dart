import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:kayfit/core/i18n/generated/app_localizations.dart';
import 'core/locale/locale_provider.dart';
import 'core/notifications/notification_service.dart';
import 'router.dart';
import 'shared/theme/app_theme.dart';
import 'shared/widgets/kayfit_brand_frame.dart';

class KayfitApp extends ConsumerWidget {
  const KayfitApp({super.key});

  static const _supportedLocales = [Locale('ru'), Locale('en')];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final locale = ref.watch(localeProvider);

    // Register navigation callback for push notification taps.
    // Called every rebuild but GoRouter.go is idempotent when already on route.
    NotificationService.setNavigationCallback(router.go);

    return MaterialApp.router(
      title: 'Kayfit',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      builder: (context, child) =>
          KayfitBrandFrame(child: child ?? const SizedBox.shrink()),
      routerConfig: router,
      locale: locale,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: _supportedLocales,
      localeResolutionCallback: (deviceLocale, supportedLocales) {
        if (deviceLocale == null) return const Locale('en');
        final isSupported = supportedLocales.any(
          (l) => l.languageCode == deviceLocale.languageCode,
        );
        return isSupported ? deviceLocale : const Locale('en');
      },
    );
  }
}
