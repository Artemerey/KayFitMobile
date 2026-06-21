import 'package:flutter/material.dart';
import 'package:kayfit/core/i18n/generated/app_localizations.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/nutrients_v2.dart';
import '../theme/app_theme.dart';

/// Bottom sheet с полным списком нутриентов одного ингредиента/приёма пищи.
///
/// Использование:
/// ```dart
/// showModalBottomSheet(
///   context: context,
///   isScrollControlled: true,
///   backgroundColor: Colors.transparent,
///   builder: (_) => NutrientDetailSheet(
///     name: item.name,
///     weightGrams: item.weightGrams,
///     per100g: item.nutrientsPer100g,
///     total: item.nutrientsTotal,
///     source: item.source,
///     sourceUrl: item.sourceUrl,
///   ),
/// );
/// ```
class NutrientDetailSheet extends StatelessWidget {
  final String name;
  final double weightGrams;
  final NutrientsV2 per100g;
  final NutrientsV2 total;

  /// Источник данных: 'usda', 'fatsecret', 'claude', 'cache' или произвольный.
  final String source;
  final String? sourceUrl;

  const NutrientDetailSheet({
    super.key,
    required this.name,
    required this.weightGrams,
    required this.per100g,
    required this.total,
    required this.source,
    this.sourceUrl,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      expand: false,
      builder: (ctx, scrollController) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            // Handle
            Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(top: 12, bottom: 4),
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Header: название + вес
            _NdsHeader(
              name: name,
              weightGrams: weightGrams,
              unitGrams: l10n.nds_unit_g,
            ),

            // Source badge
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: SourceBadge(source: source, sourceUrl: sourceUrl),
              ),
            ),

            const SizedBox(height: 8),

            // Таблица нутриентов
            Expanded(
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                children: [
                  _NdsSection(l10n.nds_section_basic, [
                    _NdsRow.required(l10n.nds_nutrient_calories, total.calories,
                        l10n.nds_unit_kcal, per100g.calories,
                        per100gLabel: l10n.nds_per100g),
                    _NdsRow.required(l10n.nds_nutrient_protein, total.protein,
                        l10n.nds_unit_g, per100g.protein,
                        per100gLabel: l10n.nds_per100g),
                    _NdsRow.required(l10n.nds_nutrient_fat, total.fat,
                        l10n.nds_unit_g, per100g.fat,
                        per100gLabel: l10n.nds_per100g),
                    _NdsRow.required(l10n.nds_nutrient_carbs, total.carbs,
                        l10n.nds_unit_g, per100g.carbs,
                        per100gLabel: l10n.nds_per100g),
                  ]),
                  _NdsSection(l10n.nds_section_carbs_detail, [
                    _NdsRow.optional(l10n.nds_nutrient_fiber, total.fiber,
                        l10n.nds_unit_g, per100g.fiber,
                        per100gLabel: l10n.nds_per100g),
                    _NdsRow.optional(
                        l10n.nds_nutrient_sugar_alcohols, total.sugarAlcohols,
                        l10n.nds_unit_g, per100g.sugarAlcohols,
                        per100gLabel: l10n.nds_per100g),
                    _NdsRow.optional(l10n.nds_nutrient_net_carbs, total.netCarbs,
                        l10n.nds_unit_g, per100g.netCarbs,
                        per100gLabel: l10n.nds_per100g),
                    _NdsRow.gi(
                      per100g.glycemicIndex,
                      per100g.glycemicIndexCategory,
                      giLabel: l10n.nds_nutrient_gi,
                      lowLabel: l10n.nds_gi_low,
                      mediumLabel: l10n.nds_gi_medium,
                      highLabel: l10n.nds_gi_high,
                    ),
                  ]),
                  _NdsSection(l10n.nds_section_fats_detail, [
                    _NdsRow.optional(l10n.nds_nutrient_sat_fat,
                        total.saturatedFat, l10n.nds_unit_g,
                        per100g.saturatedFat,
                        per100gLabel: l10n.nds_per100g),
                    _NdsRow.optional(l10n.nds_nutrient_mono_fat,
                        total.monounsaturatedFat, l10n.nds_unit_g,
                        per100g.monounsaturatedFat,
                        per100gLabel: l10n.nds_per100g),
                    _NdsRow.optional(l10n.nds_nutrient_poly_fat,
                        total.polyunsaturatedFat, l10n.nds_unit_g,
                        per100g.polyunsaturatedFat,
                        per100gLabel: l10n.nds_per100g),
                  ]),
                  _NdsSection(l10n.nds_section_minerals, [
                    _NdsRow.optional(l10n.nds_nutrient_sodium, total.sodiumMg,
                        l10n.nds_unit_mg, per100g.sodiumMg,
                        per100gLabel: l10n.nds_per100g),
                    _NdsRow.optional(l10n.nds_nutrient_cholesterol,
                        total.cholesterolMg, l10n.nds_unit_mg,
                        per100g.cholesterolMg,
                        per100gLabel: l10n.nds_per100g),
                    _NdsRow.optional(l10n.nds_nutrient_potassium,
                        total.potassiumMg, l10n.nds_unit_mg,
                        per100g.potassiumMg,
                        per100gLabel: l10n.nds_per100g),
                    _NdsRow.optional(l10n.nds_nutrient_calcium, total.calciumMg,
                        l10n.nds_unit_mg, per100g.calciumMg,
                        per100gLabel: l10n.nds_per100g),
                    _NdsRow.optional(l10n.nds_nutrient_iron, total.ironMg,
                        l10n.nds_unit_mg, per100g.ironMg,
                        per100gLabel: l10n.nds_per100g),
                  ]),
                  _NdsSection(l10n.nds_section_vitamins, [
                    _NdsRow.optional(l10n.nds_nutrient_vitamin_a,
                        total.vitaminAMcg, l10n.nds_unit_mcg,
                        per100g.vitaminAMcg,
                        per100gLabel: l10n.nds_per100g),
                    _NdsRow.optional(l10n.nds_nutrient_vitamin_c,
                        total.vitaminCMg, l10n.nds_unit_mg, per100g.vitaminCMg,
                        per100gLabel: l10n.nds_per100g),
                    _NdsRow.optional(l10n.nds_nutrient_vitamin_d,
                        total.vitaminDMcg, l10n.nds_unit_mcg,
                        per100g.vitaminDMcg,
                        per100gLabel: l10n.nds_per100g),
                  ]),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Внутренние виджеты
// ─────────────────────────────────────────────────────────────────────────────

class _NdsHeader extends StatelessWidget {
  final String name;
  final double weightGrams;
  final String unitGrams;
  const _NdsHeader({
    required this.name,
    required this.weightGrams,
    required this.unitGrams,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Text(
              name,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
                color: AppColors.text,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            '${weightGrams.toStringAsFixed(0)} $unitGrams',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

class _NdsSection extends StatelessWidget {
  final String title;
  final List<Widget> rows;
  const _NdsSection(this.title, this.rows);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title.toUpperCase(),
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: AppColors.textMuted,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border, width: 1),
            ),
            child: Column(children: rows),
          ),
        ],
      ),
    );
  }
}

/// Строка нутриента в таблице.
///
/// Фабрики:
/// - [_NdsRow.required] — обязательное поле (всегда есть значение)
/// - [_NdsRow.optional] — опциональное поле (null → "N/A")
/// - [_NdsRow.gi] — гликемический индекс со значком категории
class _NdsRow extends StatelessWidget {
  final String label;
  final String valueStr;   // уже отформатированное итоговое значение
  final String? per100Str; // "(X/100г)" или null
  final bool isLast;

  const _NdsRow._({
    required this.label,
    required this.valueStr,
    this.per100Str,
    this.isLast = false,
  });

  factory _NdsRow.required(
    String label,
    double total,
    String unit,
    double per100, {
    bool isLast = false,
    required String per100gLabel,
  }) {
    return _NdsRow._(
      label: label,
      valueStr: '${total.toStringAsFixed(1)} $unit',
      per100Str: '(${per100.toStringAsFixed(1)}$per100gLabel)',
      isLast: isLast,
    );
  }

  factory _NdsRow.optional(
    String label,
    double? total,
    String unit,
    double? per100, {
    bool isLast = false,
    required String per100gLabel,
  }) {
    if (total == null) {
      return _NdsRow._(label: label, valueStr: 'N/A', isLast: isLast);
    }
    return _NdsRow._(
      label: label,
      valueStr: '${total.toStringAsFixed(1)} $unit',
      per100Str: per100 != null
          ? '(${per100.toStringAsFixed(1)}$per100gLabel)'
          : null,
      isLast: isLast,
    );
  }

  factory _NdsRow.gi(
    int? gi,
    String? category, {
    bool isLast = false,
    required String giLabel,
    required String lowLabel,
    required String mediumLabel,
    required String highLabel,
  }) {
    if (gi == null) {
      return _NdsRow._(label: giLabel, valueStr: 'N/A', isLast: isLast);
    }
    final cat =
        category ?? (gi < 55 ? 'low' : gi < 70 ? 'medium' : 'high');
    final label = switch (cat) {
      'low' => lowLabel,
      'medium' => mediumLabel,
      _ => highLabel,
    };
    return _NdsRow._(
      label: giLabel,
      valueStr: '$gi · $label',
      isLast: isLast,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isNA = valueStr == 'N/A';
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: isNA ? AppColors.textMuted : AppColors.text,
                ),
              ),
              const Spacer(),
              if (per100Str != null) ...[
                Text(
                  per100Str!,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textMuted,
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Text(
                valueStr,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: isNA ? AppColors.textMuted : AppColors.text,
                ),
              ),
            ],
          ),
        ),
        if (!isLast)
          Divider(
            height: 1,
            indent: 14,
            endIndent: 14,
            color: AppColors.border.withValues(alpha: 0.6),
          ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SourceBadge — публичный виджет (используется и в других местах)
// ─────────────────────────────────────────────────────────────────────────────

class _SourceConfig {
  final IconData icon;
  final String label;
  final Color color;
  final Color bg;
  final String? url;
  const _SourceConfig({
    required this.icon,
    required this.label,
    required this.color,
    required this.bg,
    required this.url,
  });
}

/// Маленький чип с иконкой и названием источника данных о нутриентах.
///
/// Параметр [compact] делает чип меньше (для списков ингредиентов).
class SourceBadge extends StatelessWidget {
  final String source;
  final String? sourceUrl;
  final bool compact;

  const SourceBadge({
    super.key,
    required this.source,
    this.sourceUrl,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cfg = _sourceConfig(source, sourceUrl, l10n);

    return GestureDetector(
      onTap: cfg.url != null
          ? () async {
              final uri = Uri.parse(cfg.url!);
              if (await canLaunchUrl(uri)) launchUrl(uri);
            }
          : null,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 6 : 8,
          vertical: compact ? 3 : 5,
        ),
        decoration: BoxDecoration(
          color: cfg.bg,
          borderRadius: BorderRadius.circular(compact ? 6 : 8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(cfg.icon, size: compact ? 10 : 13, color: cfg.color),
            const SizedBox(width: 4),
            Text(
              cfg.label,
              style: TextStyle(
                fontSize: compact ? 9 : 11,
                fontWeight: FontWeight.w600,
                color: cfg.color,
              ),
            ),
            if (cfg.url != null) ...[
              const SizedBox(width: 3),
              Icon(Icons.open_in_new_rounded,
                  size: compact ? 9 : 11,
                  color: cfg.color.withValues(alpha: 0.7)),
            ],
          ],
        ),
      ),
    );
  }

  static _SourceConfig _sourceConfig(
      String source, String? sourceUrl, AppLocalizations l10n) {
    return switch (source.toLowerCase()) {
      'usda' => _SourceConfig(
          icon: Icons.verified_rounded,
          label: 'USDA FoodData Central',
          color: const Color(0xFF1D4ED8),
          bg: const Color(0xFFDBEAFE),
          url: sourceUrl ?? 'https://fdc.nal.usda.gov/',
        ),
      'fatsecret' => _SourceConfig(
          icon: Icons.search_rounded,
          label: 'Nutrition DB',
          color: const Color(0xFF15803D),
          bg: const Color(0xFFDCFCE7),
          // No FatSecret license — never expose a clickable brand link.
          url: null,
        ),
      'claude' => _SourceConfig(
          icon: Icons.auto_awesome_rounded,
          label: 'Claude AI',
          color: const Color(0xFF6D28D9),
          bg: const Color(0xFFEDE9FE),
          url: 'https://anthropic.com',
        ),
      'cache' => _SourceConfig(
          icon: Icons.storage_rounded,
          label: l10n.nds_source_cache,
          color: const Color(0xFF6B7280),
          bg: const Color(0xFFF3F4F6),
          url: null,
        ),
      _ => _SourceConfig(
          icon: Icons.bar_chart_rounded,
          label: source,
          color: const Color(0xFF6B7280),
          bg: const Color(0xFFF3F4F6),
          url: sourceUrl,
        ),
    };
  }
}
