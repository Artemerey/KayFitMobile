// CopyTargetSheet — bottom sheet for selecting target dates when copying meals.
//
// Shows a mini inline calendar with multi-select, quick-pick chips
// (Yesterday / Tomorrow / +7 days / This week), and a Copy button.
//
// Returns `List<String>` of ISO yyyy-MM-dd dates via Navigator.pop,
// or null if cancelled.

import 'package:flutter/material.dart';
import 'package:intl/intl.dart' as intl;

import '../../../core/i18n/generated/app_localizations.dart';
import '../../../shared/theme/kayfit2_theme.dart';

class CopyTargetSheet extends StatefulWidget {
  const CopyTargetSheet({super.key, required this.currentDate});

  /// The date currently being viewed in the journal (ISO yyyy-MM-dd).
  /// This date is highlighted but not selectable.
  final String currentDate;

  @override
  State<CopyTargetSheet> createState() => _CopyTargetSheetState();
}

class _CopyTargetSheetState extends State<CopyTargetSheet> {
  final _selected = <String>{};
  late DateTime _displayMonth;
  late DateTime _currentDt;

  @override
  void initState() {
    super.initState();
    _currentDt = DateTime.parse(widget.currentDate);
    _displayMonth = DateTime(_currentDt.year, _currentDt.month);
  }

  String _iso(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  void _toggle(String iso) {
    if (iso == widget.currentDate) return;
    setState(() {
      if (_selected.contains(iso)) {
        _selected.remove(iso);
      } else {
        _selected.add(iso);
      }
    });
  }

  Set<String> _chipDates(String key) {
    switch (key) {
      case 'yesterday':
        return {_iso(_currentDt.subtract(const Duration(days: 1)))};
      case 'tomorrow':
        return {_iso(_currentDt.add(const Duration(days: 1)))};
      case 'next7':
        return {
          for (int i = 1; i <= 7; i++)
            _iso(_currentDt.add(Duration(days: i))),
        };
      case 'thisWeek':
        final dow = _currentDt.weekday;
        final monday = _currentDt.subtract(Duration(days: dow - 1));
        return {
          for (int i = 0; i < 7; i++)
            _iso(monday.add(Duration(days: i))),
        }..remove(widget.currentDate);
      default:
        return {};
    }
  }

  bool _chipActive(String key) {
    final dates = _chipDates(key);
    if (dates.isEmpty) return false;
    return _selected.containsAll(dates);
  }

  void _onChip(String key) {
    final dates = _chipDates(key);
    setState(() {
      if (_selected.containsAll(dates)) {
        _selected.removeAll(dates);
      } else {
        _selected.addAll(dates);
      }
    });
  }

  String _russianDayWord(int n) {
    if (n % 100 >= 11 && n % 100 <= 14) return 'дн.';
    return switch (n % 10) {
      1 => 'день',
      2 || 3 || 4 => 'дня',
      _ => 'дн.',
    };
  }

  @override
  Widget build(BuildContext context) {
    const t = K2Theme.light;
    final l10n = AppLocalizations.of(context)!;
    final isRu = l10n.localeName == 'ru';
    final n = _selected.length;

    final copyLabel = n == 0
        ? l10n.journal_copy_btn
        : isRu
            ? '${l10n.journal_copy_btn}  ·  $n ${_russianDayWord(n)}'
            : '${l10n.journal_copy_btn}  ·  $n d.';

    return SafeArea(
      child: Container(
        margin: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: t.surface,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: t.fgMute.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Title
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  l10n.journal_copy_select_dates,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    fontFamily: K2Fonts.sans,
                    color: t.fg,
                    letterSpacing: -0.3,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 14),

            // Quick chips
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _QuickChip(
                    label: isRu ? 'Вчера' : 'Yesterday',
                    active: _chipActive('yesterday'),
                    onTap: () => _onChip('yesterday'),
                    theme: t,
                  ),
                  _QuickChip(
                    label: isRu ? 'Завтра' : 'Tomorrow',
                    active: _chipActive('tomorrow'),
                    onTap: () => _onChip('tomorrow'),
                    theme: t,
                  ),
                  _QuickChip(
                    label: '+7 ${isRu ? 'дней' : 'days'}',
                    active: _chipActive('next7'),
                    onTap: () => _onChip('next7'),
                    theme: t,
                  ),
                  _QuickChip(
                    label: isRu ? 'Эта неделя' : 'This week',
                    active: _chipActive('thisWeek'),
                    onTap: () => _onChip('thisWeek'),
                    theme: t,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Month navigation
            _MonthNav(
              month: _displayMonth,
              onPrev: () => setState(() {
                _displayMonth =
                    DateTime(_displayMonth.year, _displayMonth.month - 1);
              }),
              onNext: () => setState(() {
                _displayMonth =
                    DateTime(_displayMonth.year, _displayMonth.month + 1);
              }),
              theme: t,
              locale: l10n.localeName,
            ),

            const SizedBox(height: 8),

            // Calendar grid
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: _CalGrid(
                month: _displayMonth,
                selected: _selected,
                currentDate: widget.currentDate,
                onTap: _toggle,
                theme: t,
                locale: l10n.localeName,
              ),
            ),

            const SizedBox(height: 16),

            // Copy button
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: n == 0
                      ? null
                      : () => Navigator.of(context)
                          .pop(_selected.toList()..sort()),
                  style: FilledButton.styleFrom(
                    backgroundColor: K2Colors.accent,
                    disabledBackgroundColor:
                        t.fgMute.withValues(alpha: 0.15),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    copyLabel,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: n == 0 ? t.fgMute : Colors.white,
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

// ─────────────────────────────────────────────────────────────────────────────
// Quick chip
// ─────────────────────────────────────────────────────────────────────────────

class _QuickChip extends StatelessWidget {
  const _QuickChip({
    required this.label,
    required this.active,
    required this.onTap,
    required this.theme,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;
  final K2Theme theme;

  @override
  Widget build(BuildContext context) {
    final accent = K2Colors.accent;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: active ? accent : theme.bg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: active ? accent : theme.fgMute.withValues(alpha: 0.3),
            width: active ? 1.5 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            fontFamily: K2Fonts.sans,
            color: active ? Colors.white : theme.fg,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Month navigation header
// ─────────────────────────────────────────────────────────────────────────────

class _MonthNav extends StatelessWidget {
  const _MonthNav({
    required this.month,
    required this.onPrev,
    required this.onNext,
    required this.theme,
    required this.locale,
  });

  final DateTime month;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final K2Theme theme;
  final String locale;

  @override
  Widget build(BuildContext context) {
    final label = intl.DateFormat('LLLL yyyy', locale).format(month);
    final capitalized =
        label.isEmpty ? label : label[0].toUpperCase() + label.substring(1);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        IconButton(
          icon: Icon(Icons.chevron_left_rounded,
              color: theme.fgDim, size: 22),
          onPressed: onPrev,
          padding: const EdgeInsets.symmetric(horizontal: 12),
        ),
        Text(
          capitalized,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            fontFamily: K2Fonts.sans,
            color: theme.fg,
            letterSpacing: -0.1,
          ),
        ),
        IconButton(
          icon: Icon(Icons.chevron_right_rounded,
              color: theme.fgDim, size: 22),
          onPressed: onNext,
          padding: const EdgeInsets.symmetric(horizontal: 12),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Calendar grid
// ─────────────────────────────────────────────────────────────────────────────

class _CalGrid extends StatelessWidget {
  const _CalGrid({
    required this.month,
    required this.selected,
    required this.currentDate,
    required this.onTap,
    required this.theme,
    required this.locale,
  });

  final DateTime month;
  final Set<String> selected;
  final String currentDate;
  final ValueChanged<String> onTap;
  final K2Theme theme;
  final String locale;

  String _iso(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final firstDay = DateTime(month.year, month.month, 1);
    final lastDayNum =
        DateTime(month.year, month.month + 1, 0).day;
    // 0 = Monday, 6 = Sunday offset
    final offset = (firstDay.weekday - 1) % 7;
    final totalCells = offset + lastDayNum;
    final rowCount = (totalCells / 7).ceil();

    // Day label row (Mo Tue ... Sun)
    final now = DateTime.now();
    final dayLabels = List.generate(7, (i) {
      final dt = DateTime(now.year, now.month, now.day - now.weekday + 1 + i);
      return intl.DateFormat('E', locale).format(dt);
    });

    return Column(
      children: [
        // Day labels
        Row(
          children: [
            for (final lbl in dayLabels)
              Expanded(
                child: Center(
                  child: Text(
                    lbl,
                    style: TextStyle(
                      fontSize: 11,
                      fontFamily: K2Fonts.mono,
                      color: theme.fgMute,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        // Date rows
        for (int row = 0; row < rowCount; row++) ...[
          Row(
            children: [
              for (int col = 0; col < 7; col++) _buildCell(row, col, offset, lastDayNum),
            ],
          ),
          const SizedBox(height: 4),
        ],
      ],
    );
  }

  Widget _buildCell(int row, int col, int offset, int lastDayNum) {
    final cellIdx = row * 7 + col;
    final dayNum = cellIdx - offset + 1;

    if (dayNum < 1 || dayNum > lastDayNum) {
      return const Expanded(child: SizedBox(height: 36));
    }

    final dt = DateTime(month.year, month.month, dayNum);
    final iso = _iso(dt);
    final isCurrent = iso == currentDate;
    final isSelected = selected.contains(iso);
    final accent = K2Colors.accent;

    return Expanded(
      child: GestureDetector(
        onTap: isCurrent ? null : () => onTap(iso),
        child: Container(
          height: 36,
          margin: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            color: isSelected
                ? accent
                : isCurrent
                    ? theme.fgMute.withValues(alpha: 0.12)
                    : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: isCurrent && !isSelected
                ? Border.all(
                    color: accent.withValues(alpha: 0.4),
                    width: 1.5,
                  )
                : null,
          ),
          child: Center(
            child: Text(
              '$dayNum',
              style: TextStyle(
                fontSize: 13,
                fontFamily: K2Fonts.mono,
                fontWeight:
                    isSelected ? FontWeight.w700 : FontWeight.w400,
                color: isSelected
                    ? Colors.white
                    : isCurrent
                        ? accent
                        : theme.fg,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
