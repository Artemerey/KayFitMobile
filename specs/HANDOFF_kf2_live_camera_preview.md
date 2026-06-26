# Хэндофф: живое превью камеры на экране распознавания фото (KF2)

> Инструкция для НОВОГО окна Claude Code. Самодостаточна — читать целиком перед началом.
> Проект: **KayFit / Carb Counter**, Flutter. Репозиторий: `/Users/user/Desktop/КУРСОР/mobileKayfit`.

## Роль
Ты — релиз-инженер на KayFit. Делаешь один UX-фикс, тестируешь его на реальном iPhone, коммитишь в ветку. Финальный мерж в master и App Store-сборку делает владелец после твоей проверки.

## Задача (со слов пользователя)
Когда открываешь распознавание еды по фото — открывается **чёрный экран** с иконкой камеры и подписью «TAP TO CAPTURE». Живого изображения с камеры нет. Людям непонятно, что это камера и что надо нажать белую кнопку — шаг получается сложным.

Нужно: **вместо чёрного плейсхолдера показывать живое превью камеры** (чтобы было видно, что камера снимает), сохранив кнопку загрузки из галереи. Допустимая альтернатива, если живое превью окажется нерабочим на этом устройстве, — сделать так, чтобы шаг был очевидным: либо сразу открывать системную камеру, либо явная крупная кнопка «Загрузить фото». **Приоритет — живое превью.**

## Что это за экран (текущее состояние)
- Файл: **`lib/features/add_meal/screens/kf2_capture_screen.dart`** — виджет `Kf2CaptureScreen`, роут **`/kf2/capture`**.
- Открывается из чата: `lib/features/chat/screens/chat_v2_screen.dart`, метод `_handleCamera()` →
  `final photo = await context.push<XFile>('/kf2/capture');` затем добавляет «аналайзинг-бабл» и кладёт фото в очередь распознавания (`photoRecognitionProvider.enqueue`).
- **Сейчас живого превью НЕТ.** Экран — это заглушка: чёрный фон (`K2Theme.dark`), пульсирующая иконка камеры, рамки-уголки viewfinder, подписи «aim at your plate / TAP TO CAPTURE», кнопка галереи и белая кнопка-затвор. По тапу затвора вызывается `image_picker` (`ImagePicker().pickImage(source: ImageSource.camera)`) — открывается **системная** камера. По тапу галереи — `ImageSource.gallery`.
- Возврат результата: **строго `context.pop(file)`** (go_router), НЕ `Navigator.pop` — иначе с go_router 14 значение `Future<XFile>` молча теряется (см. комментарий в файле, строки ~110-114). Это контракт с чатом — не ломать.

## Жёсткие требования к фиксу
1. **Контракт не менять:** экран по-прежнему возвращает `XFile` через `context.pop(file)`, `null` при отмене. Весь downstream (очередь `photoRecognitionProvider`, `_drainOutcomes`, карточка `/kf2/result`) ждёт `XFile` — его не трогать.
2. **Кнопка «галерея» (загрузка из фото) остаётся** и работает (`image_picker` source: gallery).
3. **Сохранить дизайн KF2:** тёмная тема, акцент `#007AFF`, рамки-уголки viewfinder. Живое превью идёт ФОНОМ под уголками.
4. **Lifecycle камеры (ГЛАВНЫЙ риск):** `CameraController` обязательно
   - dispose при уходе с экрана;
   - pause/dispose при сворачивании приложения и переинициализация при возврате (`WidgetsBindingObserver.didChangeAppLifecycleState`) — иначе превью «замораживается» после background/resume.
5. **Первый тап (регресс Бага №1):** исторический баг «первое фото не срабатывает, второе да» был из-за гонки разрешения камеры и пикера (фикс `_pickImageWithRetry` в текущем файле). С `camera`-контроллером гонка меняет форму (инициализация контроллера сама ждёт разрешение), но **надёжность первого кадра проверить обязательно** — первый тап по затвору должен снимать.
6. **Разрешения:** уже есть `permission_handler: ^11.3.0` и `NSCameraUsageDescription` в `ios/Runner/Info.plist`. Свести к одному чистому запросу разрешения (не два диалога подряд). Если доступ не выдан — внятное сообщение + кнопка в Настройки (как сейчас).
7. **Зависимости:** пакета `camera` в проекте НЕТ. Добавить `camera` в `pubspec.yaml` → `flutter pub get` → `cd ios && pod install`. `image_picker: ^1.1.0` остаётся для галереи.

## ⚠️ Контекст репозитория — важно
- **master СЛОМАН и НЕ компилируется** (HEAD `ca2150d`: ссылка на неопределённый `activeRecognitionResultProvider`, 3 ошибки `undefined_identifier`). Ответвляться от master НЕЛЬЗЯ.
- Вся актуальная работа — на ветке **`fix/kf2-recognition-resume`** (HEAD `1c27035`, +4 коммита над master): recognition resume (Баги №1-3), рефактор голоса в `VoiceSessionMachine` + тесты, фикс автоскролла (чат открывается на последнем сообщении), фикс «вечного распознавания» после мгновенного сворачивания.
- **Ответвляйся от `fix/kf2-recognition-resume`.** Рекомендуется новая ветка `feat/kf2-live-camera` от неё (изолирует рискованную camera-зависимость), либо коммить прямо в `fix/kf2-recognition-resume` — на усмотрение, но базируйся именно на ней.

## Команды: анализ + тесты
```bash
cd /Users/user/Desktop/КУРСОР/mobileKayfit
export PATH="$PATH:$HOME/development/flutter/bin"
dart analyze lib/                                  # ок: только info-линты, 0 error/warning
env -u HTTP_PROXY -u HTTPS_PROXY flutter test --no-pub   # БАЗЛАЙН: 310 passed, 2 skipped
```
> Тестам нужен снятый прокси (`env -u HTTP_PROXY -u HTTPS_PROXY`), иначе websocket-листенер тестера падает 403 на localhost.

## Деплой на iPhone (ОБЯЗАТЕЛЬНО перед тем, как отдавать на проверку)
**Сначала прочитай скилл `kayfit-release` и память `project_kayfit_release.md` целиком.** Кратко (Procedure B, устройство на iOS 26.1 beta — `flutter run` НЕ работает, только build + devicectl):

- Устройство (devicectl id): **`87647915-87F1-505F-81B0-1E6C7ECFDFCD`** (iPhone 12). Бывает «Connection reset by peer» — повтори install 2-4 раза.
1. `cp ios/Runner.xcodeproj/project.pbxproj ios/Runner.xcodeproj/project.pbxproj.bak`
2. Создать `ios/Runner/RunnerDebug.entitlements` (только `keychain-access-groups` для `com.kayfit.app.dev`).
3. В Profile-блоке `project.pbxproj` (id `249021D4217E4FDB00AE95B9`, строки ~495-515): `CODE_SIGN_ENTITLEMENTS`→`Runner/RunnerDebug.entitlements`, `CODE_SIGN_IDENTITY`→`"Apple Development"`, `CODE_SIGN_STYLE`→`Automatic`, `DEVELOPMENT_TEAM`→`NRV3G463S5`, `PRODUCT_BUNDLE_IDENTIFIER`→`com.kayfit.app.dev`, убрать строку `PROVISIONING_PROFILE_SPECIFIER`.
4. `env -u HTTP_PROXY -u HTTPS_PROXY flutter build ios --profile --no-pub`
5. `xcrun devicectl device install app --device 87647915-87F1-505F-81B0-1E6C7ECFDFCD build/ios/iphoneos/Runner.app`
6. **Откатить:** `git checkout -- ios/Runner.xcodeproj/project.pbxproj` + `rm ios/Runner.xcodeproj/project.pbxproj.bak ios/Runner/RunnerDebug.entitlements`. **pbxproj и RunnerDebug.entitlements в коммит НЕ должны попасть.**
7. Запуск: `xcrun devicectl device process launch --terminate-existing --device 87647915-... com.kayfit.app.dev`.
   Если ошибка `Locked` — это НЕ дефект сборки, телефон заблокирован: попросить пользователя разблокировать и тапнуть иконку `Kayfit.dev`. После переустановки iOS может попросить довериться серту: Настройки → Основные → VPN и управление устройством → довериться разработчику.

> Побочка `com.kayfit.app.dev`: push-уведомления молчат, аналитика уходит под другим bundle — для UI-теста камеры неважно.

## Ручной чек-лист на устройстве (ru и en)
1. Открыть чат → камера/распознавание фото → **видно живое изображение с камеры** (не чёрный экран).
2. **Первый** тап по затвору после первой выдачи разрешения — снимает фото (регресс Бага №1).
3. Снятое фото уходит в распознавание, карточка результата показывается как раньше.
4. Кнопка галереи — открывает выбор из фото, тоже уходит в распознавание.
5. Свернуть приложение на экране камеры → вернуться: превью снова живое (не зависло).
6. Отказать в разрешении камеры → внятное сообщение + путь в Настройки; галерея при этом доступна.
7. Крестик закрывает экран без фото, чат не сломан.

## Итог (что отдать пользователю)
Отчёт: что сделал, статус тестов/аналайзера (база была 310/2), что проверил на устройстве по чек-листу, какие коммиты в ветке, готово ли к мержу. **Не делать App Store-сборку/IPA локально** (на этой машине подпись под team `MH4VYBU68D` не собирается — релиз отдаётся коллеге исходником; см. `project_kayfit_release.md`).
