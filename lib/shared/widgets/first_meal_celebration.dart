import 'dart:math' as math;
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/api/api_client.dart';
import '../theme/kayfit2_theme.dart';

const _firstMealCelebrationKeyPrefix = 'first_meal_celebration_shown_v1';

String? _accountScopedCelebrationKey(SharedPreferences prefs) {
  final cachedUser = prefs.getString('cached_user');
  if (cachedUser == null) return null;
  try {
    final user = jsonDecode(cachedUser) as Map<String, dynamic>;
    final id = user['id'];
    return id == null ? null : '$_firstMealCelebrationKeyPrefix:$id';
  } on FormatException {
    return null;
  }
}

/// Determines before a save whether the meal being created is the user's first.
///
/// Existing users are marked as already handled without seeing the popup.
Future<bool> prepareFirstMealCelebration() async {
  final prefs = await SharedPreferences.getInstance();
  final celebrationKey = _accountScopedCelebrationKey(prefs);
  if (celebrationKey == null) return false;
  if (prefs.getBool(celebrationKey) ?? false) return false;

  try {
    final response = await apiDio.get(
      '/api/meals/history',
      queryParameters: const {'limit': 1},
    );
    final history = response.data;
    if (history is List && history.isEmpty) return true;
    await prefs.setBool(celebrationKey, true);
  } on Exception {
    // If history cannot be verified, avoid showing a potentially incorrect
    // "first meal" message. The next successful save can try again.
  }
  return false;
}

/// Shows the one-time celebration after the first meal was saved successfully.
Future<void> showFirstMealCelebrationIfNeeded(
  BuildContext context, {
  required bool eligible,
}) async {
  if (!eligible || !context.mounted) return;

  final prefs = await SharedPreferences.getInstance();
  final celebrationKey = _accountScopedCelebrationKey(prefs);
  if (celebrationKey == null) return;
  if (prefs.getBool(celebrationKey) ?? false) return;
  await prefs.setBool(celebrationKey, true);
  if (!context.mounted) return;

  final isRu = Localizations.localeOf(context).languageCode == 'ru';
  await showDialog<void>(
    context: context,
    useRootNavigator: true,
    barrierDismissible: false,
    builder: (dialogContext) => _ConfettiCelebrationOverlay(
      child: _FirstMealCelebrationDialog(isRu: isRu),
    ),
  );
}

class _ConfettiCelebrationOverlay extends StatefulWidget {
  const _ConfettiCelebrationOverlay({required this.child});

  final Widget child;

  @override
  State<_ConfettiCelebrationOverlay> createState() =>
      _ConfettiCelebrationOverlayState();
}

class _ConfettiCelebrationOverlayState
    extends State<_ConfettiCelebrationOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Center(child: widget.child),
        if (!MediaQuery.disableAnimationsOf(context))
          IgnorePointer(
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, child) => CustomPaint(
                key: const Key('first_meal_confetti'),
                painter: _ConfettiPainter(progress: _controller.value),
              ),
            ),
          ),
      ],
    );
  }
}

class _ConfettiPainter extends CustomPainter {
  const _ConfettiPainter({required this.progress});

  final double progress;

  static const _colors = [
    Color(0xFF007AFF),
    Color(0xFF5AC8FA),
    Color(0xFFFFCC00),
    Color(0xFFFF3B30),
    Color(0xFFAF52DE),
    Color(0xFF34C759),
    Color(0xFFFF9500),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final random = math.Random(2707);
    final paint = Paint()..style = PaintingStyle.fill;

    for (var index = 0; index < 72; index++) {
      final startDelay = random.nextDouble() * 0.24;
      final particleProgress = ((progress - startDelay) / (1 - startDelay))
          .clamp(0.0, 1.0);
      if (particleProgress <= 0 || particleProgress >= 1) continue;

      final startX = random.nextDouble() * size.width;
      final horizontalDrift = (random.nextDouble() - 0.5) * 90;
      final wave =
          math.sin(
            particleProgress * math.pi * 3 + random.nextDouble() * math.pi,
          ) *
          18;
      final x = startX + horizontalDrift * particleProgress + wave;
      final y =
          -24 + (size.height + 70) * Curves.easeIn.transform(particleProgress);
      final opacity = particleProgress < 0.82
          ? 1.0
          : (1 - particleProgress) / 0.18;
      final width = 5.0 + random.nextDouble() * 5;
      final height = 8.0 + random.nextDouble() * 8;
      final rotation =
          particleProgress * math.pi * (4 + random.nextDouble() * 6);

      paint.color = _colors[index % _colors.length].withValues(alpha: opacity);
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(rotation);
      if (index % 5 == 0) {
        canvas.drawCircle(Offset.zero, width * 0.55, paint);
      } else {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(center: Offset.zero, width: width, height: height),
            const Radius.circular(1.5),
          ),
          paint,
        );
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

class _FirstMealCelebrationDialog extends StatelessWidget {
  const _FirstMealCelebrationDialog({required this.isRu});

  final bool isRu;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 28),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 76,
              height: 76,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF83D5FF), K2Colors.accent],
                ),
              ),
              child: const Icon(
                Icons.auto_awesome_rounded,
                color: Colors.white,
                size: 36,
              ),
            ),
            const SizedBox(height: 22),
            Text(
              isRu ? 'Первая запись — готово!' : 'First entry, locked in!',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: K2Fonts.sans,
                fontSize: 23,
                height: 1.15,
                fontWeight: FontWeight.w800,
                color: K2Colors.lightFg,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              isRu
                  ? 'Первый шаг сделан. Регулярные записи помогают лучше видеть прогресс.'
                  : 'You took the first step. Consistent logging makes your progress easier to see.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: K2Fonts.sans,
                fontSize: 15,
                height: 1.4,
                color: K2Colors.lightFgDim,
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: const LinearGradient(
                    colors: [Color(0xFF5AC8FA), K2Colors.accent],
                  ),
                ),
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Text(
                    isRu ? 'Продолжить' : 'Keep going',
                    style: const TextStyle(
                      fontFamily: K2Fonts.sans,
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
