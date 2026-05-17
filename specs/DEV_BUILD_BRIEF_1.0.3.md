# KayFit 1.0.3+1 — Dev Build Brief

> Дата: 2026-05-17
> Отправить разработчикам вместе с исходниками.

---

## Что нужно сделать

Собрать и загрузить в App Store Connect сборку `1.0.3+1` приложения KayFit (`com.kayfit.app`).

---

## Требования к окружению

| Параметр | Значение |
|---|---|
| Flutter | 3.x stable |
| Xcode | 15+ |
| Apple Distribution cert | **Team MH4VYBU68D** ("Carb Counter App Store") |
| Provisioning profile | `Carb Counter App Store` — bundle `com.kayfit.app` |
| iOS Deployment Target | 16.0 |

---

## Команда сборки

```bash
flutter pub get
flutter build ipa --release --export-options-plist=ios/ExportOptions.plist
```

IPA появится в `build/ios/ipa/`. Загрузить через Transporter или Xcode Organizer.

---

## Что изменилось в 1.0.3+1

Патч-релиз: исправление критического бага «iOS разлогинивает после закрытия приложения».

### Изменённые файлы

| Файл | Что сделано |
|---|---|
| `lib/core/auth/auth_provider.dart` | `@Riverpod(keepAlive: true)` — сессия не уничтожается; исправлен catch-блок (таймаут ≠ logout) |
| `lib/core/auth/auth_provider.g.dart` | Перегенерирован — `NotifierProvider` вместо `AutoDisposeNotifierProvider` |
| `lib/core/auth/secure_token_storage.dart` | `KeychainUnavailableException` — недоступный Keychain не приравнивается к отсутствию токенов |
| `lib/core/api/api_client.dart` | Убран глобальный `_onLogout` callback и race condition |
| `lib/main.dart` | `WidgetsBindingObserver` — тихое обновление сессии при `AppLifecycleState.resumed` |

### Новые файлы (тесты — в сборку не попадают)

- `test/core/auth/auth_session_test.dart`
- `test/widget/app_lifecycle_resume_test.dart`
- `test/regression/` (4 файла регресс-тестов)

---

## Preflight-проверка перед отправкой

```bash
# 1. Версия
grep "^version:" pubspec.yaml   # должно быть 1.0.3+1

# 2. Правильный бандл-ид
grep -r "PRODUCT_BUNDLE_IDENTIFIER" ios/Runner.xcodeproj/project.pbxproj | grep -v appp

# 3. Deployment target
grep IPHONEOS_DEPLOYMENT_TARGET ios/Runner.xcodeproj/project.pbxproj | sort -u  # все = 16.0

# 4. Все тесты зелёные
flutter test --reporter=compact
```

---

## Полный список изменений

См. `CHANGELOG.md` → секция `[1.0.3+1]`.
