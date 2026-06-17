/// Local i18n for the Recipes feature.
///
/// Mirrors the established feature-local pattern (see `BodyFormStrings`): we
/// keep strings here instead of touching `lib/core/i18n/app_*.arb`. Backend
/// copy (Ишка's recommendation line) is already localised server-side by the
/// user's profile language, so only UI chrome lives here.
abstract final class RecipesStrings {
  static String title(bool isRu) => isRu ? 'Рецепты' : 'Recipes';

  static String ishkaPicksHeader(bool isRu) =>
      isRu ? 'Персональные рекомендации' : 'Personal recommendations';

  static String addToDiary(bool isRu) =>
      isRu ? 'Добавить в дневник' : 'Add to diary';

  static String addedToDiary(bool isRu) =>
      isRu ? 'Добавлено в дневник' : 'Added to diary';

  static String ingredientsHeader(bool isRu) =>
      isRu ? 'Ингредиенты' : 'Ingredients';

  static String emptyTitle(bool isRu) =>
      isRu ? 'Пока нет рекомендаций' : 'No recommendations yet';

  static String emptyBody(bool isRu) => isRu
      ? 'Добавь несколько приёмов пищи в дневник — и Ишка подберёт рецепты под твой день.'
      : 'Log a few meals and Ishka will pick recipes that fit your day.';

  static String errorTitle(bool isRu) =>
      isRu ? 'Не удалось загрузить' : 'Failed to load';

  static String retry(bool isRu) => isRu ? 'Повторить' : 'Retry';

  /// "~420 ккал · 35 Б" macro summary line.
  static String macroSummary(bool isRu, int kcal, int proteinG) => isRu
      ? '$kcal ккал · $proteinGг белка'
      : '$kcal kcal · ${proteinG}g protein';

  static String kcal(bool isRu) => isRu ? 'ккал' : 'kcal';

  static String cookMinutes(bool isRu, int minutes) =>
      isRu ? '$minutes мин' : '$minutes min';

  /// Honest accuracy disclaimer required on AI-estimated macros (spec §2).
  static String macroDisclaimer(bool isRu) =>
      isRu ? 'КБЖУ ±15%, оценка AI' : 'Macros ±15%, AI estimate';
}
