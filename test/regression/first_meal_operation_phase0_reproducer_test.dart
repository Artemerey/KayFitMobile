import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('phase 0 first meal operation trace', () {
    test('text and voice converge on the pending-meal save handler', () {
      final sourceCode = File(
        'lib/features/chat/screens/chat_v2_screen.dart',
      ).readAsStringSync();

      expect(sourceCode, contains('final isVoice = _fromVoice;'));
      expect(
        sourceCode,
        contains(
          'feedbackSource: isVoice ? FeedbackSource.voice : '
          'FeedbackSource.text',
        ),
      );
      expect(sourceCode, contains('onAdd: _confirmAddPendingMeal'));
    });

    const sources = ['text', 'voice'];

    for (final source in sources) {
      test('$source first confirmation reaches save_started', () {
        final sourceCode = File(
          'lib/features/chat/screens/chat_v2_screen.dart',
        ).readAsStringSync();
        final handlerStart = sourceCode.indexOf(
          'Future<void> _confirmAddPendingMeal() async {',
        );
        final handlerEnd = sourceCode.indexOf(
          'void _onPendingItemWeightChange',
          handlerStart,
        );
        final handler = sourceCode.substring(handlerStart, handlerEnd);

        final silentCooldownReturn = handler.indexOf(
          'if (elapsed < const Duration(milliseconds: 700)) return;',
        );
        final saveStarted = handler.indexOf(
          'ref.read(pendingMealProvider.notifier).setAdding(true);',
        );
        final saveRequest = handler.indexOf("'/api/meals/add_selected'");

        expect(handlerStart, greaterThanOrEqualTo(0));
        expect(saveStarted, greaterThanOrEqualTo(0));
        expect(saveRequest, greaterThan(saveStarted));
        expect(
          silentCooldownReturn,
          anyOf(lessThan(0), greaterThan(saveStarted)),
          reason:
              '$source reaches the same pending-meal confirmation handler. '
              'Its first valid tap must not terminate before save_started.',
        );
      });
    }

    test('photo result save has no pre-save silent cooldown', () {
      for (final path in [
        'lib/features/add_meal/screens/recognition_result_sheet.dart',
        'lib/features/add_meal/screens/recognition_result_sheet_v2.dart',
        'lib/features/add_meal/screens/recognition_result_sheet_kf2.dart',
      ]) {
        final sourceCode = File(path).readAsStringSync();
        final saveStart = sourceCode.indexOf('Future<void> _save() async {');
        final saveRequest = sourceCode.indexOf(
          "'/api/meals/add_selected'",
          saveStart,
        );
        final saveFlow = sourceCode.substring(saveStart, saveRequest);

        expect(saveStart, greaterThanOrEqualTo(0), reason: path);
        expect(saveRequest, greaterThan(saveStart), reason: path);
        expect(
          saveFlow,
          isNot(contains('Duration(milliseconds: 700)')),
          reason: path,
        );
      }
    });

    test('photo result save owns the stable operation identity it persists', () {
      for (final path in [
        'lib/features/add_meal/screens/recognition_result_sheet_v2.dart',
        'lib/features/add_meal/screens/recognition_result_sheet_kf2.dart',
      ]) {
        final sourceCode = File(path).readAsStringSync();
        final saveStart = sourceCode.indexOf('Future<void> _save() async {');
        final saveRequest = sourceCode.indexOf(
          '.saveSelected(',
          saveStart,
        );
        final saveFlow = sourceCode.substring(saveStart, saveRequest);

        expect(saveStart, greaterThanOrEqualTo(0), reason: path);
        expect(saveRequest, greaterThan(saveStart), reason: path);
        expect(
          saveFlow,
          contains('final operationId = _ensureOperation();'),
          reason: '$path must resolve the operation inside the save flow',
        );
      }
    });
  });
}
