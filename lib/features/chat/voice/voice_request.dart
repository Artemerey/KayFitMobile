Map<String, Object?> mealParseRequestData({
  required String text,
  required String language,
  required bool voiceProvenance,
}) => <String, Object?>{
  'text': text,
  'language': language,
  'input_source': voiceProvenance ? 'voice' : 'text',
  'is_voice': voiceProvenance,
};
