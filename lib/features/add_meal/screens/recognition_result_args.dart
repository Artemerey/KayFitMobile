import '../../../shared/models/ingredient_v2.dart';

/// Payload passed via GoRouter `extra` to the `/kf2/result` route.
///
/// The recognition result sheet is presented as a real GoRouter page (not an
/// imperative `Navigator.push`) so its `Navigator.pop` stays in sync with the
/// router — mixing the two APIs on the same navigator silently breaks pop and
/// freezes the sheet buttons.
class RecognitionResultArgs {
  const RecognitionResultArgs({
    required this.dishName,
    required this.items,
    this.onSaved,
  });

  final String dishName;
  final List<IngredientV2> items;

  /// Fired with the dish name immediately before the sheet pops on save.
  final void Function(String dishName)? onSaved;
}
