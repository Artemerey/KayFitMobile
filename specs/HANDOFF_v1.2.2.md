# Передача сборки KayFit 1.2.2 (6) в App Store

> Инструкция для коллеги с доступом к команде **`MH4VYBU68D`** и дистрибуционными ассетами.
> Дата подготовки: 2026-06-12.

## TL;DR

1. Собирать строго из тега **`v1.2.2`** (commit `ca2b0e7`) репозитория `Artemerey/KayFitMobile`.
2. Подпись уже зашита в проект — **ничего в Xcode/pbxproj менять не надо**: bundle `com.kayfit.app`, team `MH4VYBU68D`, профиль «Carb Counter App Store», cert «Apple Distribution».
3. Собрать IPA: `scripts/build_ios.sh` (или Xcode → Archive).
4. Залить в App Store Connect (Organizer → Distribute App, либо Transporter), заполнить What's New (текст ниже), отправить на ревью.

## 1. Откуда брать код

- **Репозиторий:** `ssh://git@ssh.github.com:443/Artemerey/KayFitMobile.git`
- **Тег:** `v1.2.2` → commit `ca2b0e794ec99613d0f541fc867121874f8ab6e8`
- **Версия:** `1.2.2+6` (Version 1.2.2, Build 6)

```bash
git clone ssh://git@ssh.github.com:443/Artemerey/KayFitMobile.git
cd KayFitMobile
git checkout v1.2.2          # именно тег, не свежий master HEAD
flutter pub get
```

> Собирайте из тега `v1.2.2`, а не из верхушки `master`: поверх релизного коммита может лежать только документация (например, этот файл), сама сборка от тега зафиксирована.

## 2. Требования к окружению

- Членство в команде Apple Developer **`MH4VYBU68D`**.
- Установленные в Keychain/Xcode: сертификат **«Apple Distribution»** и провиженинг-профиль **«Carb Counter App Store»** для `com.kayfit.app`.
- Xcode (актуальная стабильная версия) + Flutter SDK, `flutter pub get` выполнен.
- macOS с доступом в App Store Connect под аккаунтом, привязанным к команде.

## 3. Подпись (уже в репозитории — НЕ трогать)

Значения зафиксированы в `ios/Runner.xcodeproj/project.pbxproj` (Release) и `ios/ExportOptions.plist`:

| Параметр | Значение |
|---|---|
| `PRODUCT_BUNDLE_IDENTIFIER` | `com.kayfit.app` |
| `DEVELOPMENT_TEAM` / `teamID` | `MH4VYBU68D` |
| `CODE_SIGN_STYLE` / `signingStyle` | `Manual` |
| `CODE_SIGN_IDENTITY` / `signingCertificate` | `Apple Distribution` |
| `PROVISIONING_PROFILE_SPECIFIER` | `Carb Counter App Store` |
| `method` (ExportOptions) | `app-store-connect` |
| `uploadSymbols` | `true` (dSYM уходят в ASC) |
| Entitlements | `Runner/Runner.entitlements`: `aps-environment=production`, Sign in with Apple, keychain-group `com.kayfit.app` |

> ⚠️ Не переключайте bundle на `com.kayfit.app.dev` и не меняйте команду на `NRV3G463S5` — это конфигурация для локального dev-теста на устройстве, для App Store она не годится.

## 4. Сборка

**Вариант A — скрипт (рекомендуется):**

```bash
./scripts/build_ios.sh
```

Делает `flutter pub get` + `flutter build ipa --release --export-options-plist=ios/ExportOptions.plist`, складывает IPA и `КАК_ЗАГРУЗИТЬ.txt` в `build/appstore_release/<ДАТА>_v1.2.2+6/` и открывает папку в Finder.

**Вариант B — Xcode:**

```bash
open ios/Runner.xcworkspace
```

Product → Archive → дождаться, далее Organizer.

> Собирать **без** `--dart-define=BYPASS_PAYWALL=true` — paywall должен остаться активным (`kBypassPaywall` по умолчанию `false`, на прод не влияет).

## 5. Заливка в App Store Connect

- **Xcode Organizer:** Window → Organizer → Archives → выбрать архив → **Distribute App** → **App Store Connect** → Upload.
- **Альтернатива (Transporter / altool):**

  ```bash
  xcrun altool --upload-app -f build/appstore_release/<ДАТА>_v1.2.2+6/*.ipa \
    -t ios -u <apple_id> -p <app_specific_password>
  ```

После заливки выбрать билд **1.2.2 (6)** в нужной версии приложения в ASC.

## 6. What's New (для карточки версии в App Store Connect)

**English:**

```
Kayfit 2.0

Redesigned from scratch:
• New journal — calendar strip, macro rings, meal rows, swipe to delete
• New chat — thinking-step bubbles, attach toolbar (camera / voice / barcode), add meal directly from chat
• New food recognition — full-screen capture, results sheet in the new design
• New settings screen in the KF2 style

Body shape goal:
• Pick your current and desired body shape during onboarding
• App calculates a personalised target weight automatically

Improvements:
• Voice input wired into the new chat
• Macro goal changes immediately update the journal rings
• Stats refresh correctly after saving weight or macro goals
• Onboarding progress is saved — resume after closing the app

Language & localisation:
• Russian language fully supported — switch in Settings
• App opens in English by default regardless of system language
• All macro labels, consent messages, and errors respect the selected language
• Privacy Policy and Terms of Service available in Russian

Privacy & security:
• Auth tokens moved to iOS Keychain
• AI feature consent gate — review or change in Settings at any time
• Privacy manifest (PrivacyInfo.xcprivacy) added per Apple requirements
```

**Русский:**

```
Kayfit 2.0

Полный редизайн:
• Новый дневник — лента календаря, кольца макронутриентов, карточки приёмов пищи, удаление свайпом
• Новый чат — пузыри с шагами обработки, панель вложений (камера / голос / штрихкод), добавление еды прямо из чата
• Новый экран распознавания — полноэкранная камера, карточка результата в новом дизайне
• Новый экран настроек в стиле KF2

Цель по форме тела:
• Выбери текущую и желаемую форму тела в онбординге
• Приложение рассчитывает персональный целевой вес автоматически

Улучшения:
• Голосовой ввод подключён к новому чату
• Изменение нормы КБЖУ мгновенно отображается в кольцах дневника
• Статистика корректно обновляется после сохранения веса или нормы КБЖУ
• Прогресс онбординга сохраняется — можно вернуться после закрытия приложения

Язык и локализация:
• Полная поддержка русского языка — переключение в Настройках
• Приложение открывается на английском по умолчанию, независимо от языка системы
• Названия макронутриентов, сообщения о согласии и ошибки учитывают выбранный язык
• Политика конфиденциальности и Условия использования доступны на русском языке

Конфиденциальность и безопасность:
• Токены авторизации перенесены в iOS Keychain
• Запрос согласия перед использованием ИИ-функций — можно изменить в Настройках
• Добавлен манифест конфиденциальности (PrivacyInfo.xcprivacy) по требованию Apple
```

Полный текст также лежит в `specs/whatsnew.txt`.

## 7. Что изменилось в 1.2.2 (для контекста)

Точечный патч поверх 2.0-релиза (полный разбор — `specs/CHANGELOG_1.2.2.md`):

- **Фикс спонтанного разлогина** — устранена гонка refresh-токенов между `checkSession()` и `_AuthInterceptor`, из-за которой бэкенд отзывал все сессии.
- **Фикс «вечной загрузки» после экрана плана в онбординге** — петля редиректа `/login → /journal-v2 → /onboarding`; теперь перед входом делается `logout()`.
- **Экран «Месяц Premium в подарок»** (review-prompt) теперь показывается и при входе через **Apple** (раньше — только email); проставляется `onboarding_done`.
- **Брендовый splash-экран** на старте.

## 8. Чек-лист коллеги

- [ ] `git checkout v1.2.2`, `flutter pub get` выполнены.
- [ ] Сертификат «Apple Distribution» и профиль «Carb Counter App Store» подхватились (нет ошибок подписи).
- [ ] `scripts/build_ios.sh` (или Archive) завершился без ошибок, IPA получен.
- [ ] Билд **1.2.2 (6)** залит в App Store Connect.
- [ ] What's New заполнен (EN + RU).
- [ ] Версия отправлена на ревью.

## 9. Возможные грабли

- **Нет профиля «Carb Counter App Store» / истёк** — создать/обновить в Apple Developer Portal (Profiles → App Store, app id `com.kayfit.app`), затем перекачать в Xcode.
- **dSYM/символы** — заливаются автоматически (`uploadSymbols=true`); отдельно ничего делать не нужно.
- **Ошибка подписи про команду `MH4VYBU68D` или `NRV3G463S5`** — собираете не под тем аккаунтом; нужен аккаунт-член команды `MH4VYBU68D`.
