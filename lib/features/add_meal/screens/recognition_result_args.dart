import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/models/ingredient_v2.dart';

/// Holds the args for the result currently presented on `/kf2/result`.
///
/// The payload lives here — not only in GoRouter `extra` — so the route can be
/// rebuilt without losing it. When the app is backgrounded with the result
/// sheet open and the user returns, iOS re-delivers RouteInformation and
/// go_router rebuilds the route with `extra == null`. Reading the result from
/// this provider survives that refresh; the old hard cast of a now-null `extra`
/// threw a CastError and painted a permanent grey ErrorWidget.
///
/// Set right before pushing `/kf2/result`, cleared once the sheet pops.
final activeRecognitionResultProvider = StateProvider<RecognitionResultArgs?>(
  (ref) => null,
);

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
