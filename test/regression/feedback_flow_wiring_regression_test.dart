import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kayfit/core/feedback/feedback_models.dart';
import 'package:kayfit/features/add_meal/screens/recognition_result_args.dart';
import 'package:kayfit/features/add_meal/screens/recognition_result_sheet_kf2.dart';
import 'package:kayfit/features/add_meal/screens/recognition_result_sheet_v2.dart';
import 'package:kayfit/features/chat/models/chat_message.dart';

String _source(String path) => File(path).readAsStringSync();

void main() {
  group('feedback source mapping', () {
    test('recognition hosts preserve their explicit source', () {
      const textHost = RecognitionResultSheetV2(
        dishName: 'text result',
        ingredients: [],
        feedbackSource: FeedbackSource.text,
      );
      const voiceHost = RecognitionResultSheetKF2(
        dishName: 'voice result',
        ingredients: [],
        feedbackSource: FeedbackSource.voice,
      );
      const routedPhoto = RecognitionResultArgs(
        dishName: 'photo result',
        items: [],
        feedbackSource: FeedbackSource.photo,
      );

      expect(textHost.feedbackSource, FeedbackSource.text);
      expect(voiceHost.feedbackSource, FeedbackSource.voice);
      expect(routedPhoto.feedbackSource, FeedbackSource.photo);
    });

    test('entry flows pass text, voice, photo and barcode explicitly', () {
      final addMeal = _source(
        'lib/features/add_meal/screens/add_meal_sheet.dart',
      );
      final barcode = _source(
        'lib/features/add_meal/screens/barcode_scanner_screen_v2.dart',
      );

      expect(addMeal, contains('FeedbackSource.text'));
      expect(addMeal, contains('FeedbackSource.voice'));
      expect(addMeal, contains('FeedbackSource.photo'));
      expect(barcode, contains('FeedbackSource.barcode'));
    });
  });

  group('flow-specific prompt wiring', () {
    test('photo, voice and text carry clarification into guarded save sheets', () {
      final addMeal = _source(
        'lib/features/add_meal/screens/add_meal_sheet.dart',
      );
      final queuedPhoto = _source(
        'lib/features/chat/providers/photo_recognition_provider.dart',
      );
      final v2Sheet = _source(
        'lib/features/add_meal/screens/recognition_result_sheet_v2.dart',
      );
      final kf2Sheet = _source(
        'lib/features/add_meal/screens/recognition_result_sheet_kf2.dart',
      );

      expect(addMeal, contains("resp.data['clarification']"));
      expect(addMeal, contains('clarification: clarification'));
      expect(queuedPhoto, contains("resp.data['clarification']"));
      for (final source in [v2Sheet, kf2Sheet]) {
        expect(source, contains('RecognitionClarificationCard('));
        expect(source, contains('!_clarificationConfirmed'));
      }
    });

    test('recognition sheets rate before save and never prompt after save', () {
      const paths = [
        'lib/features/add_meal/screens/recognition_result_sheet.dart',
        'lib/features/add_meal/screens/recognition_result_sheet_v2.dart',
        'lib/features/add_meal/screens/recognition_result_sheet_kf2.dart',
      ];

      for (final path in paths) {
        final source = _source(path);
        expect(source, contains('RecognitionFeedbackBar('), reason: path);
        expect(
          source,
          isNot(contains('popThenShowMealFeedbackPrompt')),
          reason: path,
        );
      }
    });

    test('chat pending meal card renders inline recognition feedback', () {
      final source = _source('lib/features/chat/screens/chat_v2_screen.dart');
      expect(source, contains('class _PendingMealCard'));
      expect(source, contains('RecognitionFeedbackBar('));
      expect(source, contains('feedbackSource: isVoice'));
      expect(
        source,
        contains('processingNotifier.state = false;'),
        reason: 'meal routing must clear the shared chat processing state',
      );
    });

    test('non-recognition save consumers keep additive response feedback', () {
      const paths = [
        'lib/features/chat/screens/chat_v2_screen.dart',
        'lib/features/recipes/screens/recipe_detail_screen.dart',
      ];

      final repository = _source(
        'lib/core/meal_logging/meal_log_operation_provider.dart',
      );
      expect(repository, contains("'/api/meals/add_selected'"));
      expect(repository, contains('MealSaveResult.fromJson'));

      for (final path in paths) {
        final source = _source(path);
        expect(source, contains('.saveSelected('), reason: path);
        expect(source, contains('canRequestFeedback'), reason: path);
        expect(source, contains('feedbackTargetId!'), reason: path);
      }
    });

    test('copy-batch uses partial-success parser and copy source', () {
      final source = _source(
        'lib/features/journal/screens/journal_v2_screen.dart',
      );

      expect(source, contains("'/api/meals/copy-batch'"));
      expect(source, contains('MealSaveResult.fromCopyBatchJson'));
      expect(source, contains('saveResult.canRequestFeedback'));
      expect(source, contains('FeedbackSource.copy'));
    });

    test(
      'legacy chat parses the server target and prompts only fresh reply',
      () {
        final message = ChatMessage.fromJson({
          'role': 'assistant',
          'content': 'Saved',
          'created_at': '2026-08-07T08:00:00Z',
          'meal_added': {
            'name': 'meal',
            'calories': 321,
            'protein': 20,
            'fat': 10,
            'carbs': 30,
            'meal_id': 42,
            'feedback_target_id': ' target-uuid ',
          },
        });
        final screen = _source('lib/features/chat/screens/chat_screen.dart');

        expect(message.mealAdded?.mealId, 42);
        expect(message.mealAdded?.feedbackTargetId, 'target-uuid');
        expect(screen, contains('final mealAdded = reply.mealAdded;'));
        expect(screen, contains('FeedbackSource.chat'));
        expect(screen, contains("'total_calories_rounded'"));
      },
    );

    test(
      'no active Flutter consumer exists for direct or copy-one endpoints',
      () {
        final dartFiles = Directory('lib')
            .listSync(recursive: true)
            .whereType<File>()
            .where((file) => file.path.endsWith('.dart'));
        final combined = dartFiles
            .map((file) => file.readAsStringSync())
            .join();

        expect(combined, isNot(contains("post('/api/meals'")));
        expect(combined, isNot(contains("/copy'")));
        expect(combined, contains("'/api/meals/copy-batch'"));
      },
    );
  });
}
