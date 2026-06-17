import 'dart:async';
import 'dart:math' as math;

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/notifications/notification_service.dart';
import '../../../shared/models/ingredient_v2.dart';
import '../../../shared/utils/nutrient_parser.dart';

// ── Result type ───────────────────────────────────────────────────────────────

@immutable
class RecognitionResult {
  const RecognitionResult({required this.dishName, required this.items});
  final String dishName;
  final List<IngredientV2> items;
}

// ── Outcome types ─────────────────────────────────────────────────────────────
//
// Each queued photo produces exactly one outcome (success / not-food / failure),
// appended to [PhotoRecognitionState.outcomes] in the order recognition
// finishes. The chat screen drains this FIFO one sheet at a time. Every outcome
// carries [photoPath] so the UI can match it to the right analyzing bubble.

@immutable
sealed class RecogOutcome {
  const RecogOutcome({required this.photoPath, required this.langCode});
  final String photoPath;
  final String langCode;
}

final class RecogSuccess extends RecogOutcome {
  const RecogSuccess({
    required super.photoPath,
    required super.langCode,
    required this.result,
  });
  final RecognitionResult result;
}

final class RecogNotFood extends RecogOutcome {
  const RecogNotFood({required super.photoPath, required super.langCode});
}

final class RecogFailure extends RecogOutcome {
  const RecogFailure({
    required super.photoPath,
    required super.langCode,
    required this.message,
  });
  final String message;
}

// ── State ─────────────────────────────────────────────────────────────────────

@immutable
class PhotoRecognitionState {
  const PhotoRecognitionState({
    this.analyzingPath,
    this.stageIndex = 0,
    this.langCode = 'en',
    this.queuedCount = 0,
    this.outcomes = const [],
  });

  /// Path of the photo currently being recognized, or null when idle.
  final String? analyzingPath;
  final int stageIndex;
  final String langCode;

  /// Photos waiting in the queue behind the in-flight one.
  final int queuedCount;

  /// Completed outcomes awaiting consumption by the UI, oldest first.
  final List<RecogOutcome> outcomes;

  bool get isAnalyzing => analyzingPath != null;

  static const Object _sentinel = Object();

  PhotoRecognitionState copyWith({
    Object? analyzingPath = _sentinel,
    int? stageIndex,
    String? langCode,
    int? queuedCount,
    List<RecogOutcome>? outcomes,
  }) {
    return PhotoRecognitionState(
      analyzingPath: identical(analyzingPath, _sentinel)
          ? this.analyzingPath
          : analyzingPath as String?,
      stageIndex: stageIndex ?? this.stageIndex,
      langCode: langCode ?? this.langCode,
      queuedCount: queuedCount ?? this.queuedCount,
      outcomes: outcomes ?? this.outcomes,
    );
  }
}

// ── Stage labels ──────────────────────────────────────────────────────────────

const _kStagesRu = [
  'Ваше фото обрабатывается…',
  'Распознавание блюд',
  'Определение нутриентов',
  'Поиск в базе данных',
  'Подготовка ответа',
];

const _kStagesEn = [
  'Processing your photo…',
  'Identifying dishes',
  'Analyzing nutrients',
  'Searching database',
  'Preparing results',
];

/// Returns the stage labels for the given locale code.
List<String> photoRecognitionStages(String langCode) =>
    langCode == 'ru' ? _kStagesRu : _kStagesEn;

// ── Queued photo ──────────────────────────────────────────────────────────────

class _QueuedPhoto {
  const _QueuedPhoto(this.photo, this.lang);
  final XFile photo;
  final String lang;
}

// ── Notifier ──────────────────────────────────────────────────────────────────

class PhotoRecognitionNotifier extends Notifier<PhotoRecognitionState> {
  Timer? _stageTimer;

  // Photos waiting to be recognized (excludes the in-flight one).
  final List<_QueuedPhoto> _pending = [];

  // True while a recognition HTTP call is in flight.
  bool _busy = false;

  // Generation counter — bumped by [clear] so an in-flight recognition that
  // resolves after a clear() never writes its outcome back to fresh state.
  int _gen = 0;

  @override
  PhotoRecognitionState build() => const PhotoRecognitionState();

  /// Adds a photo to the recognition queue and kicks the processor.
  /// Photos are recognized strictly one at a time, in FIFO order.
  void enqueue(XFile photo, String lang) {
    _pending.add(_QueuedPhoto(photo, lang));
    state = state.copyWith(queuedCount: _pending.length);
    unawaited(_kick());
  }

  /// Removes the first (oldest) outcome — called by the UI once it has been
  /// shown to the user (sheet dismissed, or error message injected).
  void consumeFirstOutcome() {
    if (state.outcomes.isEmpty) return;
    state = state.copyWith(outcomes: state.outcomes.sublist(1));
  }

  /// Resets everything: cancels timers, drops the queue and outcomes, and
  /// invalidates any in-flight recognition via the generation counter.
  void clear() {
    _gen++;
    _stageTimer?.cancel();
    _pending.clear();
    _busy = false;
    state = const PhotoRecognitionState();
  }

  // ── Queue processor ──────────────────────────────────────────────────────────

  Future<void> _kick() async {
    if (_busy) return;
    if (_pending.isEmpty) {
      _stageTimer?.cancel();
      if (state.analyzingPath != null || state.queuedCount != 0) {
        state = state.copyWith(analyzingPath: null, queuedCount: 0);
      }
      return;
    }

    _busy = true;
    final gen = _gen;
    final item = _pending.removeAt(0);

    state = state.copyWith(
      analyzingPath: item.photo.path,
      stageIndex: 0,
      langCode: item.lang,
      queuedCount: _pending.length,
    );

    final stages = photoRecognitionStages(item.lang);
    _stageTimer?.cancel();
    _stageTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (gen != _gen || state.analyzingPath != item.photo.path) return;
      state = state.copyWith(
        stageIndex: math.min(state.stageIndex + 1, stages.length - 1),
      );
    });

    RecogOutcome outcome;
    try {
      final result = await _doRecognize(item.photo, item.lang);
      outcome = RecogSuccess(
        photoPath: item.photo.path,
        langCode: item.lang,
        result: result,
      );
      final kcal =
          result.items.fold<double>(0, (s, i) => s + i.nutrientsTotal.calories);
      await NotificationService.showMealRecognized(
        dishName: result.dishName,
        kcal: kcal,
        isRu: item.lang == 'ru',
      );
    } on _NotFoodException {
      outcome = RecogNotFood(photoPath: item.photo.path, langCode: item.lang);
    } on Exception catch (e) {
      outcome = RecogFailure(
        photoPath: item.photo.path,
        langCode: item.lang,
        message: e.toString(),
      );
    }

    _stageTimer?.cancel();

    // Superseded by clear() while in flight — drop the outcome silently.
    if (gen != _gen) {
      _busy = false;
      return;
    }

    state = state.copyWith(
      analyzingPath: null,
      outcomes: [...state.outcomes, outcome],
    );
    _busy = false;
    unawaited(_kick());
  }

  // ── Private recognition logic ────────────────────────────────────────────────

  Future<RecognitionResult> _doRecognize(XFile photo, String lang) async {
    // The captured temp file can still be flushing to disk on the first read
    // right after capture — a first read may come back empty. Retry once after
    // a short beat before giving up, so the first photo isn't silently dropped.
    var originalBytes = await photo.readAsBytes();
    if (originalBytes.isEmpty) {
      debugPrint('RECOG: first read empty, retrying after 300ms');
      await Future<void>.delayed(const Duration(milliseconds: 300));
      originalBytes = await photo.readAsBytes();
    }
    if (originalBytes.isEmpty) {
      throw Exception('empty image bytes');
    }
    debugPrint('RECOG: original ${originalBytes.length ~/ 1024} KB');

    final compressed = await FlutterImageCompress.compressWithList(
      originalBytes,
      minWidth: 1280,
      minHeight: 1280,
      quality: 75,
      format: CompressFormat.jpeg,
    );

    final bytes = compressed.isNotEmpty ? compressed : originalBytes;
    debugPrint('RECOG: sending ${bytes.length ~/ 1024} KB');

    final multipart = MultipartFile.fromBytes(
      bytes,
      filename: 'photo.jpg',
      contentType: DioMediaType('image', 'jpeg'),
    );

    final resp = await apiDio.post(
      '/api/v2/recognize_photo?language=$lang',
      data: FormData.fromMap({'image': multipart}),
      options: Options(
        receiveTimeout: const Duration(seconds: 120),
        sendTimeout: const Duration(seconds: 60),
      ),
    );

    final error = resp.data['error'] as String?;
    if (error != null && error.isNotEmpty) throw Exception(error);

    final isFood = resp.data['is_food'] as bool?;
    final notFoodReason = resp.data['not_food_reason'] as String?;
    final rawItems = resp.data['items'] as List<dynamic>?;

    if (isFood == false ||
        notFoodReason == 'not_food' ||
        rawItems == null ||
        rawItems.isEmpty) {
      throw const _NotFoodException();
    }

    final items = rawItems
        .map((e) => ingredientV2FromJson(e as Map<String, dynamic>))
        .toList();

    final dishName = resp.data['dish_name'] as String? ??
        rawItems
            .map(
              (e) =>
                  (e as Map<String, dynamic>)['name'] as String? ?? '',
            )
            .where((n) => n.isNotEmpty)
            .join(', ');

    return RecognitionResult(dishName: dishName, items: items);
  }
}

class _NotFoodException implements Exception {
  const _NotFoodException();
}

// ── Provider ──────────────────────────────────────────────────────────────────

final photoRecognitionProvider =
    NotifierProvider<PhotoRecognitionNotifier, PhotoRecognitionState>(
  PhotoRecognitionNotifier.new,
);
