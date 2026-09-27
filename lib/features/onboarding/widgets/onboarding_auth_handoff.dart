import 'package:flutter/material.dart';

import '../../../shared/theme/app_theme.dart';

class OnboardingAuthHandoff extends StatelessWidget {
  const OnboardingAuthHandoff({super.key});

  @override
  Widget build(BuildContext context) {
    final isRu = Localizations.localeOf(context).languageCode == 'ru';
    final text = isRu
        ? 'Отлично! План готов. Чтобы сохранить его и приступить к цели, зарегистрируйтесь или войдите'
        : 'Great! Your plan is ready. To save it and start working toward your goal, register or sign in.';
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.accentSoft,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.accentOver.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.celebration_rounded, color: AppColors.accentOver),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: AppColors.text,
                fontSize: 15,
                fontWeight: FontWeight.w600,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
