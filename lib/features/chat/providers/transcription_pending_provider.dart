import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Holds a transcription result that was completed while ChatV2Screen was not
/// mounted (user navigated away during the HTTP /api/transcribe call).
///
/// NOT autoDispose — survives tab navigation just like chatHistoryProvider.
/// ChatV2Screen reads this on mount and pre-fills the text input, then clears.
final transcriptionPendingProvider = StateProvider<String?>((ref) => null);

/// True while a background /api/transcribe HTTP call is in flight.
/// NOT autoDispose — survives tab navigation so ChatV2Screen can restore the
/// spinner when the user returns to chat before transcription finishes.
final transcriptionInProgressProvider = StateProvider<bool>((ref) => false);

/// True while /api/chat/send HTTP call is in flight.
/// NOT autoDispose — survives tab navigation so ChatV2Screen can restore the
/// thinking bubble when the user returns to chat before AI responds.
final chatProcessingProvider = StateProvider<bool>((ref) => false);
