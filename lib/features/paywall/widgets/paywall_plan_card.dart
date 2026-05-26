import 'package:flutter/material.dart';

class PaywallPlanCard extends StatelessWidget {
  const PaywallPlanCard({
    super.key,
    required this.title,
    required this.priceLabel,
    required this.selected,
    required this.onTap,
    this.badge,
  });

  final String title;
  final String priceLabel;
  final bool selected;
  final VoidCallback onTap;
  final String? badge;

  static const _kAccent = Color(0xFFFF597D);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        decoration: BoxDecoration(
          color: selected
              ? const Color(0x28FF597D)
              : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? _kAccent : const Color(0xFFE5E7EB),
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (badge != null)
              Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: _kAccent,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  badge!,
                  style: const TextStyle(
                    fontSize: 9,
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.4,
                  ),
                ),
              ),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: selected ? _kAccent : const Color(0xFF374151),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              priceLabel,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: selected
                    ? _kAccent.withValues(alpha: 0.85)
                    : const Color(0xFF6B7280),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
