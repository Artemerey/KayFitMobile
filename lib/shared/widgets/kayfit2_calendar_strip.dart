// Kayfit 2.0 — Calendar strip widget (KF2-FOUND-2).
//
// Mirrors the JSX CalendarStrip implementation from
// specs/kayfit_2.0/source_handoff/project/kayfit-app.jsx lines 263-422.
//
// Two modes:
//   • Compact (default) — week strip showing last 7 days, height ~80pt.
//   • Expanded — full month grid with legend, toggled via chevron.
//
// Each day cell renders a closed Apple-style status ring drawn by
// [_StatusRingPainter]. Today is a filled blue circle (#007AFF).

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/kayfit2_theme.dart';

// ── Public API types ──────────────────────────────────────────────────────────

/// Per-day status for the calendar ring indicators.
enum K2DayStatus {
  /// Within calorie goal — renders green ring.
  good,

  /// Over calorie goal — renders red ring.
  over,
}

/// Calendar strip widget for the KayFit 2.0 Journal screen.
///
/// Renders a 7-day week strip (compact) that expands into a full month grid
/// when [expanded] is true. The caller owns the [expanded] state; the widget
/// fires [onToggle] when the user taps the chevron.
class Kayfit2CalendarStrip extends StatelessWidget {
  const Kayfit2CalendarStrip({
    super.key,
    required this.theme,
    required this.expanded,
    required this.onToggle,
    required this.selectedIso,
    required this.onSelect,
    this.statusByIso,
  });

  /// Design tokens.
  final K2Theme theme;

  /// Whether the full-month grid is shown.
  final bool expanded;

  /// Called when the user taps the chevron.
  final VoidCallback onToggle;

  /// ISO date string of the selected day (e.g. "2026-01-15") or `"today"`.
  final String selectedIso;

  /// Called with an ISO string or `"today"` when the user taps a day.
  final ValueChanged<String> onSelect;

  /// Optional map of ISO date → status.  Null means no rings are drawn.
  final Map<String, K2DayStatus>? statusByIso;

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _WeekStrip(
          theme: theme,
          expanded: expanded,
          onToggle: onToggle,
          selectedIso: selectedIso,
          onSelect: onSelect,
          statusByIso: statusByIso,
        ),
        if (expanded)
          _MonthGrid(
            theme: theme,
            selectedIso: selectedIso,
            onSelect: onSelect,
            statusByIso: statusByIso,
          ),
        Container(height: 1, color: theme.hairline),
      ],
    );
  }
}

// ── Week strip ────────────────────────────────────────────────────────────────

class _WeekStrip extends StatelessWidget {
  const _WeekStrip({
    required this.theme,
    required this.expanded,
    required this.onToggle,
    required this.selectedIso,
    required this.onSelect,
    required this.statusByIso,
  });

  final K2Theme theme;
  final bool expanded;
  final VoidCallback onToggle;
  final String selectedIso;
  final ValueChanged<String> onSelect;
  final Map<String, K2DayStatus>? statusByIso;

  static const _dayLetters = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final days = List.generate(7, (i) {
      final d = today.subtract(Duration(days: 6 - i));
      final iso = _isoDate(d);
      final isToday = i == 6;
      final letter = _dayLetters[(d.weekday - 1) % 7]; // weekday: 1=Mon..7=Sun
      return _DayEntry(
        letter: letter,
        day: d.day,
        iso: iso,
        isToday: isToday,
        status: statusByIso?[iso],
      );
    });

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          for (final entry in days)
            Expanded(
              child: _DayCell(
                entry: entry,
                isSelected: _isSelected(entry),
                theme: theme,
                onTap: () => onSelect(entry.isToday ? 'today' : entry.iso),
              ),
            ),
          // chevron toggle
          SizedBox(
            width: 36,
            height: 48,
            child: IconButton(
              padding: EdgeInsets.zero,
              icon: Icon(
                expanded
                    ? Icons.keyboard_arrow_up_rounded
                    : Icons.keyboard_arrow_down_rounded,
                size: 20,
                color: theme.fgDim,
              ),
              onPressed: onToggle,
              splashRadius: 18,
            ),
          ),
        ],
      ),
    );
  }

  bool _isSelected(_DayEntry e) {
    if (selectedIso == 'today') return e.isToday;
    return selectedIso == e.iso;
  }
}

// ── Month grid ────────────────────────────────────────────────────────────────

class _MonthGrid extends StatelessWidget {
  const _MonthGrid({
    required this.theme,
    required this.selectedIso,
    required this.onSelect,
    required this.statusByIso,
  });

  final K2Theme theme;
  final String selectedIso;
  final ValueChanged<String> onSelect;
  final Map<String, K2DayStatus>? statusByIso;

  static const _headers = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final firstOfMonth = DateTime(today.year, today.month);
    final daysInMonth =
        DateTime(today.year, today.month + 1, 0).day; // last day
    // Mon=0 … Sun=6 offset for the grid
    final startOffset = (firstOfMonth.weekday - 1) % 7;

    // Build cell list: nulls for leading blanks, then 1..daysInMonth.
    final cells = <_MonthCell?>[
      for (var i = 0; i < startOffset; i++) null,
      for (var d = 1; d <= daysInMonth; d++)
        _MonthCell(
          day: d,
          iso: _isoDate(DateTime(today.year, today.month, d)),
          isToday: d == today.day,
          status: statusByIso?[
              _isoDate(DateTime(today.year, today.month, d))],
        ),
    ];

    final monthLabel =
        '${_monthName(today.month)} ${today.year}'.toLowerCase();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Month label
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              monthLabel,
              style: TextStyle(
                fontSize: 11,
                color: theme.fgDim,
                letterSpacing: 1.0,
                fontFamily: K2Fonts.sans,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          // Day-of-week headers
          Row(
            children: [
              for (final h in _headers)
                Expanded(
                  child: Center(
                    child: Text(
                      h,
                      style: TextStyle(
                        fontSize: 10,
                        color: theme.fgMute,
                        fontFamily: K2Fonts.sans,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 2),
          // Grid
          _buildGrid(cells, today),
          // Legend
          _Legend(theme: theme),
        ],
      ),
    );
  }

  Widget _buildGrid(List<_MonthCell?> cells, DateTime today) {
    // Pad to a multiple of 7.
    final padded = List<_MonthCell?>.from(cells);
    while (padded.length % 7 != 0) {
      padded.add(null);
    }

    final rows = <Widget>[];
    for (var r = 0; r < padded.length ~/ 7; r++) {
      final rowCells = padded.sublist(r * 7, r * 7 + 7);
      rows.add(
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final cell in rowCells)
                Expanded(
                  child: cell == null
                      ? const SizedBox()
                      : _MonthDayCell(
                          cell: cell,
                          isSelected: _isCellSelected(cell, today),
                          theme: theme,
                          onTap: () => onSelect(
                            cell.isToday ? 'today' : cell.iso,
                          ),
                        ),
                ),
            ],
          ),
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: rows,
    );
  }

  bool _isCellSelected(_MonthCell cell, DateTime today) {
    if (selectedIso == 'today') return cell.isToday;
    return selectedIso == cell.iso;
  }
}

// ── Legend ────────────────────────────────────────────────────────────────────

class _Legend extends StatelessWidget {
  const _Legend({required this.theme});

  final K2Theme theme;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 14, 4, 4),
      child: Row(
        children: [
          _LegendItem(
            color: K2CalendarStatus.goodRing,
            label: 'on track',
            theme: theme,
          ),
          const SizedBox(width: 14),
          _LegendItem(
            color: K2CalendarStatus.overRing,
            label: 'over goal',
            theme: theme,
          ),
          const SizedBox(width: 14),
          _LegendItem(
            color: theme.border,
            label: 'empty',
            theme: theme,
          ),
        ],
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({
    required this.color,
    required this.label,
    required this.theme,
  });

  final Color color;
  final String label;
  final K2Theme theme;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        CustomPaint(
          size: const Size(14, 14),
          painter: _SmallRingPainter(color: color),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: theme.fgDim,
            fontFamily: K2Fonts.mono,
          ),
        ),
      ],
    );
  }
}

// ── Day cell (week strip) ─────────────────────────────────────────────────────

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.entry,
    required this.isSelected,
    required this.theme,
    required this.onTap,
  });

  final _DayEntry entry;
  final bool isSelected;
  final K2Theme theme;
  final VoidCallback onTap;

  static const _cellSize = 36.0;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Day letter
          Text(
            entry.letter,
            style: TextStyle(
              fontSize: 10,
              color: theme.fgDim,
              letterSpacing: 0.5,
              fontFamily: K2Fonts.sans,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          // Ring + number
          SizedBox(
            width: _cellSize,
            height: _cellSize,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Status ring (drawn beneath today fill)
                if (entry.status != null && !isSelected)
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _StatusRingPainter(
                        status: entry.status!,
                        strokeWidth: 2.5,
                      ),
                    ),
                  ),
                // Today / selected fill
                if (isSelected)
                  Positioned.fill(
                    child: Container(
                      decoration: const BoxDecoration(
                        color: K2Colors.accent,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                // Day number
                Text(
                  entry.day.toString(),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: isSelected ? Colors.white : theme.fg,
                    fontFamily: K2Fonts.mono,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Month day cell ────────────────────────────────────────────────────────────

class _MonthDayCell extends StatelessWidget {
  const _MonthDayCell({
    required this.cell,
    required this.isSelected,
    required this.theme,
    required this.onTap,
  });

  final _MonthCell cell;
  final bool isSelected;
  final K2Theme theme;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(2),
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Status ring
              if (cell.status != null && !isSelected)
                Positioned.fill(
                  child: Padding(
                    padding: const EdgeInsets.all(2),
                    child: CustomPaint(
                      painter: _StatusRingPainter(
                        status: cell.status!,
                        strokeWidth: 6,
                        useViewBox100: true,
                      ),
                    ),
                  ),
                ),
              // Today / selected fill
              if (isSelected)
                Positioned.fill(
                  child: Padding(
                    padding: const EdgeInsets.all(2),
                    child: Container(
                      decoration: const BoxDecoration(
                        color: K2Colors.accent,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ),
              // Day number
              Text(
                cell.day.toString(),
                style: TextStyle(
                  fontSize: 13,
                  color: isSelected ? Colors.white : theme.fg,
                  fontFamily: K2Fonts.mono,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Painters ──────────────────────────────────────────────────────────────────

/// Draws a full closed ring (track + solid arc) for a [K2DayStatus].
///
/// Used both in the week strip (small, strokeWidth 2.5) and the month grid
/// (larger, strokeWidth proportional to the 0-0-100-100 viewBox).
class _StatusRingPainter extends CustomPainter {
  const _StatusRingPainter({
    required this.status,
    required this.strokeWidth,
    this.useViewBox100 = false,
  });

  final K2DayStatus status;

  /// Absolute stroke width in logical pixels (week strip).
  /// When [useViewBox100] is true this value is treated as a fraction of the
  /// canvas size scaled from a 100×100 viewBox.
  final double strokeWidth;

  final bool useViewBox100;

  Color get _ring => status == K2DayStatus.good
      ? K2CalendarStatus.goodRing
      : K2CalendarStatus.overRing;

  Color get _track => status == K2DayStatus.good
      ? K2CalendarStatus.goodTrack
      : K2CalendarStatus.overTrack;

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;

    // In the month grid the JSX uses viewBox 0 0 100 100, r=46, strokeWidth=6.
    // We scale the stroke proportionally.
    final sw = useViewBox100 ? strokeWidth * (size.width / 100) : strokeWidth;
    final radius = math.min(cx, cy) - sw / 2;

    final trackPaint = Paint()
      ..color = _track
      ..style = PaintingStyle.stroke
      ..strokeWidth = sw
      ..strokeCap = StrokeCap.round;

    final ringPaint = Paint()
      ..color = _ring
      ..style = PaintingStyle.stroke
      ..strokeWidth = sw
      ..strokeCap = StrokeCap.round;

    final center = Offset(cx, cy);

    // Track — full circle.
    canvas.drawCircle(center, radius, trackPaint);

    // Full closed arc — start at 12 o'clock, sweep 360°.
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi,
      false,
      ringPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _StatusRingPainter old) =>
      old.status != status ||
      old.strokeWidth != strokeWidth ||
      old.useViewBox100 != useViewBox100;
}

/// 14×14 ring used in the legend.
class _SmallRingPainter extends CustomPainter {
  const _SmallRingPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    const sw = 2.5;
    final radius = math.min(cx, cy) - sw / 2;

    canvas.drawCircle(
      Offset(cx, cy),
      radius,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = sw,
    );
  }

  @override
  bool shouldRepaint(covariant _SmallRingPainter old) => old.color != color;
}

// ── Data helpers ──────────────────────────────────────────────────────────────

@immutable
class _DayEntry {
  const _DayEntry({
    required this.letter,
    required this.day,
    required this.iso,
    required this.isToday,
    required this.status,
  });

  final String letter;
  final int day;
  final String iso;
  final bool isToday;
  final K2DayStatus? status;
}

@immutable
class _MonthCell {
  const _MonthCell({
    required this.day,
    required this.iso,
    required this.isToday,
    required this.status,
  });

  final int day;
  final String iso;
  final bool isToday;
  final K2DayStatus? status;
}

String _isoDate(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

const _monthNames = [
  'january',
  'february',
  'march',
  'april',
  'may',
  'june',
  'july',
  'august',
  'september',
  'october',
  'november',
  'december',
];

String _monthName(int month) => _monthNames[(month - 1).clamp(0, 11)];
