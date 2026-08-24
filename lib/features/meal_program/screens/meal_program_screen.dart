import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../../../core/api/api_client.dart';

class MealProgramScreen extends StatefulWidget {
  const MealProgramScreen({super.key});
  @override
  State<MealProgramScreen> createState() => _MealProgramScreenState();
}

class _MealProgramScreenState extends State<MealProgramScreen> {
  bool loading = true, saving = false;
  String? error, programId;
  DateTime selected = DateTime.now();
  DateTime? end;
  String query = '';
  List<Map<String, dynamic>> tags = [], entries = [];
  Set<String> selectedTags = {};
  bool get ru => Localizations.localeOf(context).languageCode == 'ru';
  String t(String a, String b) => ru ? a : b;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final values = await Future.wait([
        apiDio.get('/api/restriction-tags'),
        apiDio.get('/api/profile/restriction-tags'),
      ]);
      tags = List<Map<String, dynamic>>.from(
        (values[0].data['items'] as List).map(
          (e) => Map<String, dynamic>.from(e),
        ),
      );
      selectedTags = Set<String>.from(values[1].data['tag_ids'] as List);
      try {
        final p = await apiDio.get('/api/meal-programs/current');
        programId = p.data['id'];
        end = DateTime.parse(p.data['ends_on']);
        await _loadDay();
      } on DioException catch (e) {
        if (e.response?.statusCode != 404 && e.response?.statusCode != 402) {
          rethrow;
        }
      }
    } catch (e) {
      error = t('Не удалось загрузить программу', 'Could not load the program');
    }
    if (mounted) setState(() => loading = false);
  }

  Future<void> _saveTags() async {
    setState(() => saving = true);
    try {
      await apiDio.put(
        '/api/profile/restriction-tags',
        data: {'tag_ids': selectedTags.toList()},
      );
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Future<void> _create() async {
    setState(() => saving = true);
    try {
      await _saveTags();
      final p = await apiDio.post('/api/meal-programs');
      programId = p.data['id'];
      end = DateTime.parse(p.data['ends_on']);
      await _loadDay();
    } on DioException catch (e) {
      error = e.response?.statusCode == 402
          ? t(
              'Доступ включён только владельцу или по подписке',
              'Owner/test entitlement or subscription required',
            )
          : t(
              'Проверьте, что расчёт цели завершён',
              'Complete your goal calculation first',
            );
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  String get iso =>
      '${selected.year.toString().padLeft(4, '0')}-${selected.month.toString().padLeft(2, '0')}-${selected.day.toString().padLeft(2, '0')}';
  Future<void> _loadDay() async {
    if (programId == null) return;
    final r = await apiDio.get(
      '/api/meal-programs/$programId/days',
      queryParameters: {'from': iso, 'to': iso},
    );
    final days = r.data['days'] as List;
    entries = days.isEmpty
        ? []
        : List<Map<String, dynamic>>.from(
            (days.first['entries'] as List).map(
              (e) => Map<String, dynamic>.from(e),
            ),
          );
    if (mounted) setState(() {});
  }

  Future<void> _delete(String id) async {
    await apiDio.delete('/api/meal-plan-entries/$id');
    await _loadDay();
  }

  Future<void> _replace(Map<String, dynamic> item) async {
    final r = await apiDio.post(
      '/api/meal-plan-entries/${item['id']}/replace-options',
    );
    final opts = List<Map<String, dynamic>>.from(
      (r.data['items'] as List).map((e) => Map<String, dynamic>.from(e)),
    );
    if (!mounted) return;
    final choice = await showModalBottomSheet<String>(
      context: context,
      builder: (c) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            for (final o in opts)
              ListTile(
                title: Text(o['name']),
                subtitle: Text(
                  '${o['portion_g']} g · ${o['calories'].round()} kcal',
                ),
                onTap: () => Navigator.pop(c, o['meal_id']),
              ),
          ],
        ),
      ),
    );
    if (choice != null) {
      await apiDio.post(
        '/api/meal-plan-entries/${item['id']}/replace',
        data: {'meal_id': choice},
      );
      await _loadDay();
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = tags
        .where(
          (x) =>
              x['active'] == true &&
              ((ru ? x['name_ru'] : x['name_en']) as String)
                  .toLowerCase()
                  .contains(query.toLowerCase()),
        )
        .toList();
    return Scaffold(
      appBar: AppBar(title: Text(t('AI-программа питания', 'AI meal program'))),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : error != null
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(error!),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: _load,
                    child: Text(t('Повторить', 'Retry')),
                  ),
                ],
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                TextField(
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search),
                    hintText: t('Поиск ограничений', 'Search restrictions'),
                  ),
                  onChanged: (v) => setState(() => query = v),
                ),
                const SizedBox(height: 12),
                if (selectedTags.isNotEmpty)
                  Wrap(
                    spacing: 6,
                    children: [
                      for (final id in selectedTags)
                        Chip(
                          label: Text(
                            (tags.where((x) => x['id'] == id).firstOrNull?[ru
                                        ? 'name_ru'
                                        : 'name_en'] ??
                                    id)
                                .toString(),
                          ),
                          onDeleted: programId == null
                              ? () => setState(() => selectedTags.remove(id))
                              : null,
                        ),
                    ],
                  ),
                for (final category
                    in filtered.map((x) => x['category']).toSet()) ...[
                  Padding(
                    padding: const EdgeInsets.only(top: 14, bottom: 6),
                    child: Text(
                      category.toString().toUpperCase(),
                      style: Theme.of(context).textTheme.labelMedium,
                    ),
                  ),
                  Wrap(
                    spacing: 8,
                    children: [
                      for (final tag in filtered.where(
                        (x) => x['category'] == category,
                      ))
                        FilterChip(
                          label: Text(tag[ru ? 'name_ru' : 'name_en']),
                          selected: selectedTags.contains(tag['id']),
                          onSelected: programId != null
                              ? null
                              : (v) => setState(
                                  () => v
                                      ? selectedTags.add(tag['id'])
                                      : selectedTags.remove(tag['id']),
                                ),
                        ),
                    ],
                  ),
                ],
                const SizedBox(height: 18),
                if (programId == null)
                  FilledButton.icon(
                    onPressed: saving ? null : _create,
                    icon: const Icon(Icons.auto_awesome),
                    label: Text(
                      saving
                          ? t('Готовим план…', 'Preparing plan…')
                          : t('Создать программу', 'Create program'),
                    ),
                  ),
                if (programId != null) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        onPressed: selected.isAfter(DateTime.now())
                            ? () {
                                setState(
                                  () => selected = selected.subtract(
                                    const Duration(days: 1),
                                  ),
                                );
                                _loadDay();
                              }
                            : null,
                        icon: const Icon(Icons.chevron_left),
                      ),
                      Text(iso),
                      IconButton(
                        onPressed: end != null && selected.isBefore(end!)
                            ? () {
                                setState(
                                  () => selected = selected.add(
                                    const Duration(days: 1),
                                  ),
                                );
                                _loadDay();
                              }
                            : null,
                        icon: const Icon(Icons.chevron_right),
                      ),
                    ],
                  ),
                  if (entries.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        t(
                          'На этот день нет позиций',
                          'No entries for this day',
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  for (final e in entries)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  e['meal_type'].toString().toUpperCase(),
                                  style: Theme.of(context).textTheme.labelSmall,
                                ),
                                const Spacer(),
                                const Chip(label: Text('Suggested by AI')),
                              ],
                            ),
                            Text(
                              e['name'],
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            Text(
                              '${e['portion_g']} g · ${e['calories'].round()} kcal',
                            ),
                            Text(
                              'P ${e['protein'].round()} · F ${e['fat'].round()} · C ${e['carbs'].round()}',
                            ),
                            Row(
                              children: [
                                TextButton(
                                  onPressed: () => _delete(e['id']),
                                  child: Text(t('Удалить', 'Delete')),
                                ),
                                TextButton(
                                  onPressed: () => _replace(e),
                                  child: Text(t('Заменить', 'Replace')),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ],
            ),
    );
  }
}
