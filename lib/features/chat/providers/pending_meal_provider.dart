// Pending-meal state lifted into a Riverpod provider so the "Add to journal?"
// card survives when the user navigates away from the chat screen (e.g. to
// the journal tab) and comes back. Previously this state lived in the chat
// screen's local State, so any navigation away discarded it.
//
// In-memory only — app kill still clears it. Disk persistence can be added
// later via SharedPreferences if needed; for now the requirement is just
// surviving tab switches inside a session.

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/models/ingredient_v2.dart';

/// Snapshot of the "pending meal confirm" UI shown at the bottom of the chat.
///
/// `items == null` means there's no pending meal (card hidden). Treat the
/// `isAdding` flag as authoritative for the "Add" button's disabled state —
/// it tracks the in-flight POST /api/meals/add_selected request.
@immutable
class PendingMealState {
  const PendingMealState({
    this.items,
    this.mealType = 'snack',
    this.isAdding = false,
  });

  final List<IngredientV2>? items;
  final String mealType;
  final bool isAdding;

  bool get isActive => items != null && items!.isNotEmpty;

  PendingMealState copyWith({
    Object? items = _sentinel,
    String? mealType,
    bool? isAdding,
  }) {
    return PendingMealState(
      items: identical(items, _sentinel)
          ? this.items
          : items as List<IngredientV2>?,
      mealType: mealType ?? this.mealType,
      isAdding: isAdding ?? this.isAdding,
    );
  }

  // Sentinel value lets `copyWith(items: null)` actually clear, while
  // omitting `items` keeps the current list.
  static const Object _sentinel = Object();
}

class PendingMealNotifier extends Notifier<PendingMealState> {
  @override
  PendingMealState build() => const PendingMealState();

  void setMeal(List<IngredientV2> items, String mealType) {
    state = state.copyWith(
      items: items,
      mealType: mealType,
      isAdding: false,
    );
  }

  void clear() {
    state = state.copyWith(items: null, isAdding: false);
  }

  void setMealType(String mealType) {
    state = state.copyWith(mealType: mealType);
  }

  void setAdding(bool v) {
    state = state.copyWith(isAdding: v);
  }

  /// Replace the item at [index] with [newItem]. No-op if there's no pending
  /// list yet or the index is out of range. Used by the per-item "edit"
  /// flow in the chat pending meal card.
  void replaceItem(int index, IngredientV2 newItem) {
    final cur = state.items;
    if (cur == null || index < 0 || index >= cur.length) return;
    final next = List<IngredientV2>.from(cur);
    next[index] = newItem;
    state = state.copyWith(items: next);
  }
}

final pendingMealProvider =
    NotifierProvider<PendingMealNotifier, PendingMealState>(
  PendingMealNotifier.new,
);
