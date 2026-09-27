import 'package:flutter/material.dart';

import '../theme/kayfit2_theme.dart';

/// Keeps the Kayfit wordmark visible above every route in the app.
class KayfitBrandFrame extends StatelessWidget {
  const KayfitBrandFrame({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final isDark = MediaQuery.platformBrightnessOf(context) == Brightness.dark;
    final background = isDark ? K2Colors.darkBg : K2Colors.lightBg;
    final foreground = isDark ? K2Colors.darkFg : K2Colors.lightFg;
    final hairline = isDark ? K2Colors.darkHairline : K2Colors.lightHairline;

    return ColoredBox(
      color: background,
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            SizedBox(
              height: 42,
              child: Center(
                child: Text(
                  'KAYFIT',
                  key: const Key('global_kayfit_wordmark'),
                  style: TextStyle(
                    color: foreground,
                    fontFamily: K2Fonts.sans,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 2.8,
                    decoration: TextDecoration.none,
                    decorationColor: Colors.transparent,
                  ),
                ),
              ),
            ),
            Container(height: 0.5, color: hairline),
            Expanded(child: child),
          ],
        ),
      ),
    );
  }
}
