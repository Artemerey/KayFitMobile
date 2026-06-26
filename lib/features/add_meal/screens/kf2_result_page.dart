import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/theme/kayfit2_theme.dart';
import 'recognition_result_args.dart';
import 'recognition_result_sheet_kf2.dart';

/// Page shown at `/kf2/result` — the photo recognition result sheet.
///
/// The payload is read from [activeRecognitionResultProvider] first, falling
/// back to GoRouter `extra`. This is what makes the sheet survive an OS-driven
/// route refresh: when the app is backgrounded with the sheet open and the user
/// returns, iOS re-delivers RouteInformation and go_router rebuilds this route
/// with `extra == null`. The provider still holds the args, so the sheet
/// re-renders instead of crashing on a null cast (the old behaviour painted a
/// permanent grey ErrorWidget). If the payload is genuinely gone, we bounce
/// back to the chat rather than show a dead screen.
class Kf2ResultPage extends ConsumerWidget {
  const Kf2ResultPage({super.key, this.extraArgs});

  /// Args from GoRouter `extra` on the initial push (fallback source).
  final RecognitionResultArgs? extraArgs;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final args = ref.watch(activeRecognitionResultProvider) ?? extraArgs;

    if (args == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) context.go('/chat-v2');
      });
      return const Scaffold(backgroundColor: K2Colors.darkBg);
    }

    return Scaffold(
      backgroundColor: K2Colors.darkBg,
      body: RecognitionResultSheetKF2(
        dishName: args.dishName,
        ingredients: args.items,
        mealDate: null,
        originalText: null,
        onSaved: args.onSaved,
      ),
    );
  }
}
