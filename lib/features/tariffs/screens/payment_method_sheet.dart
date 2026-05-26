import 'package:flutter/material.dart';

const _kBg = Color(0xFFFFF1EA);
const _kDark = Color(0xFF1A1A2E);
const _kMuted = Color(0xFF9CA3AF);
const _kSurface = Colors.white;

/// Shows the payment method selection sheet.
/// [tariffTitle] and [price] are displayed as a summary.
/// Tapping either method closes the sheet — actual processing is not yet wired.
Future<void> showPaymentMethodSheet(
  BuildContext context, {
  required String tariffTitle,
  required String price,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _PaymentMethodSheet(tariffTitle: tariffTitle, price: price),
  );
}

class _PaymentMethodSheet extends StatelessWidget {
  const _PaymentMethodSheet({
    required this.tariffTitle,
    required this.price,
  });

  final String tariffTitle;
  final String price;

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.paddingOf(context).bottom;

    return Container(
      decoration: const BoxDecoration(
        color: _kBg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(24, 12, 24, bottomPadding + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 32,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFCDD1D6),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Title
          const Text(
            'Способ оплаты',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: _kDark,
            ),
          ),
          const SizedBox(height: 6),

          // Order summary
          Row(
            children: [
              Expanded(
                child: Text(
                  tariffTitle,
                  style: const TextStyle(fontSize: 14, color: _kMuted),
                ),
              ),
              Text(
                price,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: _kDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Divider(color: Color(0xFFE9D5CB), height: 1),
          const SizedBox(height: 16),

          // Bank card
          _MethodTile(
            icon: const _CardIcon(),
            label: 'Банковская карта',
            subtitle: 'Visa, Mastercard, Мир',
            onTap: () => Navigator.of(context).pop(),
          ),
          const SizedBox(height: 10),

          // SBP
          _MethodTile(
            icon: const _SbpIcon(),
            label: 'СБП',
            subtitle: 'Система быстрых платежей',
            onTap: () => Navigator.of(context).pop(),
          ),
          const SizedBox(height: 24),

          // Security note
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              Icon(Icons.lock_outline, size: 13, color: _kMuted),
              SizedBox(width: 4),
              Text(
                'Платёж защищён',
                style: TextStyle(fontSize: 12, color: _kMuted),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MethodTile extends StatelessWidget {
  const _MethodTile({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.onTap,
  });

  final Widget icon;
  final String label;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _kSurface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              icon,
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: _kDark,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(fontSize: 12, color: _kMuted),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: _kMuted, size: 22),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Icons ──────────────────────────────────────────────────────────────────────

class _CardIcon extends StatelessWidget {
  const _CardIcon();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Icon(Icons.credit_card_rounded, color: Colors.white, size: 24),
    );
  }
}

class _SbpIcon extends StatelessWidget {
  const _SbpIcon();

  @override
  Widget build(BuildContext context) {
    // SBP brand colours: #1DB954 green + #FFCC00 yellow on white
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(11),
        child: CustomPaint(
          painter: _SbpPainter(),
        ),
      ),
    );
  }
}

class _SbpPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Green left bar
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.12, h * 0.22, w * 0.15, h * 0.56),
        const Radius.circular(3),
      ),
      Paint()..color = const Color(0xFF1DB954),
    );

    // Yellow bolt / lightning shape (simplified)
    final path = Path()
      ..moveTo(w * 0.35, h * 0.22)
      ..lineTo(w * 0.72, h * 0.22)
      ..lineTo(w * 0.52, h * 0.50)
      ..lineTo(w * 0.68, h * 0.50)
      ..lineTo(w * 0.32, h * 0.78)
      ..lineTo(w * 0.48, h * 0.50)
      ..lineTo(w * 0.33, h * 0.50)
      ..close();

    canvas.drawPath(path, Paint()..color = const Color(0xFFFFCC00));
  }

  @override
  bool shouldRepaint(_SbpPainter oldDelegate) => false;
}
