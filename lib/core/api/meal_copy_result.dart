class MealCopyResult {
  const MealCopyResult({
    required this.mealIds,
    required this.savedDates,
    required this.failed,
  });

  final List<int> mealIds;
  final List<DateTime> savedDates;
  final int failed;

  List<String> get savedDateIsos =>
      savedDates.map(_formatCalendarDate).toSet().toList(growable: false);

  String get firstSavedDateIso => savedDateIsos.first;

  factory MealCopyResult.fromJson(Object? value) {
    final json = switch (value) {
      final Map<String, dynamic> map => map,
      final Map map => Map<String, dynamic>.from(map),
      _ => throw const FormatException('Invalid meal copy response'),
    };
    final rawCopies = json['copies'];
    if (rawCopies is! List || rawCopies.isEmpty) {
      throw const FormatException('Copy response has no persisted dates');
    }

    final ids = <int>[];
    final dates = <DateTime>[];
    for (final rawCopy in rawCopies) {
      if (rawCopy is! Map) {
        throw const FormatException('Invalid copy entry');
      }
      final copy = Map<String, dynamic>.from(rawCopy);
      final rawId = copy['id'];
      final rawDate = copy['date'];
      if (rawId is! num || rawDate is! String) {
        throw const FormatException('Copy entry is missing id or date');
      }
      final date = _parseCalendarDate(rawDate);
      ids.add(rawId.toInt());
      dates.add(date);
    }

    return MealCopyResult(
      mealIds: List.unmodifiable(ids),
      savedDates: List.unmodifiable(dates),
      failed: (json['failed'] as num?)?.toInt() ?? 0,
    );
  }

  static DateTime _parseCalendarDate(String value) {
    final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(value);
    if (match == null) {
      throw const FormatException('Invalid persisted copy date');
    }
    final year = int.parse(match.group(1)!);
    final month = int.parse(match.group(2)!);
    final day = int.parse(match.group(3)!);
    final date = DateTime(year, month, day);
    if (_formatCalendarDate(date) != value) {
      throw const FormatException('Invalid persisted copy date');
    }
    return date;
  }

  static String _formatCalendarDate(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
}
