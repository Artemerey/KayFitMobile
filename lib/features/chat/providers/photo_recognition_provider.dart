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

// ── Status enum ───────────────────────────────────────────────────────────────

enum PhotoRecognitionStatus { idle, analyzing, done, error, notFood }

// ── State ─────────────────────────────────────────────────────────────────────

@immutable
class PhotoRecognitionState {
  const PhotoRecognitionState({
    this.status = PhotoRecognitionStatus.idle,
    this.photoPath,
    this.stageIndex = 0,
    this.result,
    this.errorMessage,
    this.langCode = 'en',
  });

  final PhotoRecognitionStatus status;
  final String? photoPath;
  final int stageIndex;
  final RecognitionResult? result;
  final String? errorMessage;
  final String langCode;

  bool get isAnalyzing => status == PhotoRecognitionStatus.analyzing;
  bool get isDone => status == PhotoRecognitionStatus.done;
  bool get isError => status == PhotoRecognitionStatus.error;
  bool get isNotFood => status == PhotoRecognitionStatus.notFood;

  static const Object _sentinel = Object();

  PhotoRecognitionState copyWith({
    PhotoRecognitionStatus? status,
    Object? photoPath = _sentinel,
    int? stageIndex,
    Object? result = _sentinel,
    Object? errorMessage = _sentinel,
    String? langCode,
  }) {
    return PhotoRecognitionState(
      status: status ?? this.status,
      photoPath: identical(photoPath, _sentinel)
          ? this.photoPath
          : photoPath as String?,
      stageIndex: stageIndex ?? this.stageIndex,
      result: identical(result, _sentinel)
          ? this.result
          : result as RecognitionResult?,
      errorMessage: identical(errorMessage, _sentinel)
          ? this.errorMessage
          : errorMessage as String?,
      langCode: langCode ?? this.langCode,
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

// ── Notifier ──────────────────────────────────────────────────────────────────

class PhotoRecognitionNotifier extends Notifier<PhotoRecognitionState> {
  Timer? _stageTimer;

  // Generation counter — incremented on each startRecognition call so that
  // a superseded in-flight _doRecognize never writes back to state.
  int _gen = 0;

  @override
  PhotoRecognitionState build() => const PhotoRecognitionState();

  Future<void> startRecognition(XFile photo, String lang) async {
    _stageTimer?.cancel();
    _gen++;
    final gen = _gen;

    state = PhotoRecognitionState(
      status: PhotoRecognitionStatus.analyzing,
      photoPath: photo.path,
      stageIndex: 0,
      langCode: lang,
    );

    final stages = photoRecognitionStages(lang);

    // Advance stage every 4 s, capped at the last stage index.
    _stageTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (state.status != PhotoRecognitionStatus.analyzing) return;
      state = state.copyWith(
        stageIndex: math.min(state.stageIndex + 1, stages.length - 1),
      );
    });

    try {
      final result = await _doRecognize(photo, lang);
      _stageTimer?.cancel();
      if (gen != _gen) return; // superseded by a newer call

      state = state.copyWith(
        status: PhotoRecognitionStatus.done,
        result: result,
      );

      final kcal = result.items
          .fold<double>(0, (s, i) => s + i.nutrientsTotal.calories);
      await NotificationService.showMealRecognized(
        dishName: result.dishName,
        kcal: kcal,
        isRu: lang == 'ru',
      );
    } on _NotFoodException {
      _stageTimer?.cancel();
      if (gen != _gen) return;
      state = state.copyWith(status: PhotoRecognitionStatus.notFood);
    } on Exception catch (e) {
      _stageTimer?.cancel();
      if (gen != _gen) return;
      state = state.copyWith(
        status: PhotoRecognitionStatus.error,
        errorMessage: e.toString(),
      );
    }
  }

  void clear() {
    _stageTimer?.cancel();
    state = const PhotoRecognitionState();
  }

  // ── Private recognition logic ────────────────────────────────────────────────

  Future<RecognitionResult> _doRecognize(XFile photo, String lang) async {
    final originalBytes = await photo.readAsBytes();
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
