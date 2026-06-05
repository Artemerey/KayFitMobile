import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Holds a transcription result that was completed while ChatV2Screen was not
/// mounted (user navigated away during the HTTP /api/transcribe call).
///
/// NOT autoDispose — survives tab navigation just like chatHistoryProvider.
/// ChatV2Screen reads this on mount and pre-fills the text input, then clears.
final transcriptionPendingProvider = StateProvider<String?>((ref) => null);
