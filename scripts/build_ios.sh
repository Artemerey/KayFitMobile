#!/usr/bin/env bash
# Сборка iOS IPA для App Store.
# Создаёт папку build/appstore_release/YYYY-MM-DD_vX.Y.Z+B/, собирает туда IPA,
# затем открывает папку в Finder.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Читаем версию из pubspec.yaml
VERSION=$(grep '^version:' "$PROJECT_ROOT/pubspec.yaml" | awk '{print $2}')
if [[ -z "$VERSION" ]]; then
  echo "❌ Не удалось прочитать версию из pubspec.yaml"
  exit 1
fi

DATE=$(date +%Y-%m-%d)
FOLDER_NAME="${DATE}_v${VERSION}"
OUTPUT_DIR="$PROJECT_ROOT/build/appstore_release/$FOLDER_NAME"

echo "▶ KayFit iOS build"
echo "  Версия : $VERSION"
echo "  Папка  : build/appstore_release/$FOLDER_NAME"
echo ""

# Создаём папку заранее — чтобы ExportOptions.plist мог писать туда
mkdir -p "$OUTPUT_DIR"

cd "$PROJECT_ROOT"

echo "▶ flutter pub get..."
flutter pub get

echo "▶ flutter build ipa..."
flutter build ipa \
  --release \
  --export-options-plist=ios/ExportOptions.plist

# Перекладываем артефакты из стандартного места в датированную папку
IPA_SRC="$PROJECT_ROOT/build/ios/ipa"
if [[ -d "$IPA_SRC" ]]; then
  cp -r "$IPA_SRC/"* "$OUTPUT_DIR/" 2>/dev/null || true
fi

# Копируем инструкцию по загрузке
BRIEF=$(ls "$PROJECT_ROOT/specs/DEV_BUILD_BRIEF_"*.md 2>/dev/null | sort | tail -1)
if [[ -n "$BRIEF" ]]; then
  cp "$BRIEF" "$OUTPUT_DIR/BUILD_BRIEF.md"
fi

# Создаём быстрый README с командой загрузки
cat > "$OUTPUT_DIR/КАК_ЗАГРУЗИТЬ.txt" <<EOF
KayFit — App Store Release Build
Версия : $VERSION
Дата   : $DATE

=== КАК ЗАГРУЗИТЬ ===

1. Открой Xcode → Window → Organizer → Archives
   ИЛИ дважды кликни на Kayfit.xcarchive если он лежит рядом.

2. Выбери архив → "Distribute App" → "App Store Connect" → Upload.

3. Сертификат и профиль: Team MH4VYBU68D / "Carb Counter App Store"

=== АЛЬТЕРНАТИВА — Transporter ===

  xcrun altool --upload-app -f *.ipa -t ios \
    -u <apple_id> -p <app_specific_password>

EOF

echo ""
echo "✅ Готово: build/appstore_release/$FOLDER_NAME"
echo ""

# Открываем папку в Finder
open "$OUTPUT_DIR"
