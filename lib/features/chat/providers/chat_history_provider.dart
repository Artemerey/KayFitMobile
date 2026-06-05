// Global in-memory chat history. NOT autoDispose — survives tab navigation.
// The screen reads from here instead of local State so messages are never
// lost when the user switches tabs and comes back.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/chat_message.dart';

class ChatHistoryNotifier extends Notifier<List<ChatMessage>> {
  @override
  List<ChatMessage> build() => const [];

  void setMessages(List<ChatMessage> messages) {
    state = List.unmodifiable(messages);
  }

  void add(ChatMessage msg) {
    state = [...state, msg];
  }

  /// Remove the last message (used to roll back an optimistic user message
  /// when the API call fails).
  void removeLast() {
    if (state.isEmpty) return;
    state = state.sublist(0, state.length - 1);
  }

  /// Remove all messages matching [test] (used to clear transient
  /// "photo analyzing…" placeholders).
  void removeWhere(bool Function(ChatMessage) test) {
    state = state.where((m) => !test(m)).toList();
  }

  bool get isEmpty => state.isEmpty;
}

final chatHistoryProvider =
    NotifierProvider<ChatHistoryNotifier, List<ChatMessage>>(
  ChatHistoryNotifier.new,
);
