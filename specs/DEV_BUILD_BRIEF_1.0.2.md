# KayFit 1.0.2+1 — Dev Build Brief

> Дата: 2026-05-12  
> Отправить разработчикам вместе с исходниками (не архивом).

---

## Что нужно сделать

Собрать и загрузить в App Store Connect сборку `1.0.2+1` приложения KayFit (`com.kayfit.app`).

---

## Требования к окружению

| Параметр | Значение |
|---|---|
| Flutter | 3.x stable |
| Xcode | 15+ |
| Apple Distribution cert | **Team MH4VYBU68D** ("Carb Counter App Store") |
| Provisioning profile | `Carb Counter App Store` — bundle `com.kayfit.app` |
| iOS Deployment Target | 16.0 |

Сертификат и профиль должны быть установлены на машине, где собирается сборка.

---

## Команда сборки

```bash
flutter pub get
flutter build ipa --release --export-options-plist=ios/ExportOptions.plist
```

IPA появится в `build/ios/ipa/`. Загрузить через Transporter или Xcode Organizer.

---

## ExportOptions.plist (уже в репозитории, менять не нужно)

```
method:              app-store-connect
teamID:              MH4VYBU68D
signingStyle:        manual
provisioningProfile: Carb Counter App Store (com.kayfit.app)
signingCertificate:  Apple Distribution
uploadSymbols:       true
```

---

## Что изменилось в 1.0.2+1 (KayFit 2.0)

- Полный KF2-редизайн (Journal / Chat / Recognition / Settings V2) — флаги `KF2_JOURNAL`, `KF2_CHAT`, `KF2_RECOG` включены по умолчанию
- BodyForm — новый шаг онбординга (выбор формы тела, вывод целевого веса)
- iOS preflight: исправлены entitlements, Info.plist, Podfile-макросы, бандл-ид в Debug-конфиге, deployment target 16.0
- FatSecret убран из UI (требование Guideline 5.2.1)
- Подписка (paywall) удалена — половинчатая реализация, риск Guideline 3.1.1
- Disclaimer в чате (WHO/USDA ссылки) — Guideline 1.4.1
- deleteAccount теперь бросает ошибку на сеть — Guideline 5.1.1(v)

Полный список: `specs/CHANGELOG_1.0.2.md`

---

## Preflight-проверка перед отправкой

```bash
# 1. Правильный бандл-ид
grep -r "PRODUCT_BUNDLE_IDENTIFIER" ios/Runner.xcodeproj/project.pbxproj | grep -v appp

# 2. Дистрибьюшн-энтайтлмент в бинаре (после сборки)
codesign -d --entitlements :- build/ios/ipa/*.ipa 2>/dev/null | grep -E "applesignin|aps-environment"

# 3. Версия
grep "^version:" pubspec.yaml   # должно быть 1.0.2+1

# 4. Deployment target
grep IPHONEOS_DEPLOYMENT_TARGET ios/Runner.xcodeproj/project.pbxproj | sort -u  # все = 16.0
```

---

## App Store Connect

- **Bundle ID:** `com.kayfit.app`
- **Version:** `1.0.2`
- **Build:** `1`
- **Promotional text:** можно обновить без ревью в любой момент
- **What's New EN/RU:** готов в `specs/CHANGELOG_1.0.2.md` в конце файла
- **Screenshots:** `specs/appstore_screenshots/ready/` — 12 файлов 1320×2868 (6.9" iPhone), готовы к загрузке

---

## Demo account для ревьюера Apple

```
Email:    review@carbcounter.online
Password: Review2026!
```

> Аккаунт должен иметь 15+ приёмов пищи за 2+ дня к моменту сабмита.  
> Убедиться, что аккаунт работает и сервер отвечает.
