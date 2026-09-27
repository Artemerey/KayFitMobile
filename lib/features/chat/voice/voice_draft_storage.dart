import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

const voiceDraftStorageKey = 'voice_draft_v1';

class VoiceDraft {
  const VoiceDraft({
    required this.operationId,
    required this.committedTranscript,
    required this.inputSource,
  });
  final String operationId;
  final String committedTranscript;
  final String inputSource;

  Map<String, Object?> toJson() => {
    'operation_id': operationId,
    'committed_transcript': committedTranscript,
    'input_source': inputSource,
  };
}

class VoiceDraftStorage {
  static Future<void> save(VoiceDraft draft) async {
    await (await SharedPreferences.getInstance()).setString(
      voiceDraftStorageKey,
      jsonEncode(draft.toJson()),
    );
  }

  static Future<VoiceDraft?> load() async {
    final raw = (await SharedPreferences.getInstance()).getString(
      voiceDraftStorageKey,
    );
    if (raw == null) return null;
    try {
      final json = Map<String, dynamic>.from(jsonDecode(raw) as Map);
      if (json['input_source'] != 'voice') return null;
      return VoiceDraft(
        operationId: json['operation_id'] as String,
        committedTranscript: json['committed_transcript'] as String? ?? '',
        inputSource: 'voice',
      );
    } on Object {
      return null;
    }
  }

  static Future<void> clear() async {
    await (await SharedPreferences.getInstance()).remove(voiceDraftStorageKey);
  }
}
