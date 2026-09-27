# Хэндофф тимлиду: KF2 photo recognition + resume

## Роль и цель
Ты — тимлид/релиз-инженер на проекте **KayFit (Carb Counter)**, Flutter.
Репозиторий: `/Users/user/Desktop/КУРСОР/mobileKayfit`.
Текущая ветка с фиксами: **`fix/kf2-recognition-resume`** (коммит `f43c6f8`),
ответвлена от `master` (= сборка `1.2.2+9`, что уходит в App Store на ревью).

Задача (выполни по порядку, в конце дай мне **читаемый отчёт**):
1. Изучи все три бага, которые были пофикшены (детали ниже + `git log`/`git diff master...fix/kf2-recognition-resume`).
2. Собери **единую сборку** из этой ветки (dev-install на iPhone — процедура ниже).
3. Прогони **регрессионное тестирование** (юнит/виджет + ручной чек-лист на устройстве).
4. **Глубокий deep-регресс** всего флоу распознавания фото и lifecycle (background/resume, многократные фото, переключение вкладок, ru/en).
5. Почини всё, что найдётся, с тестами.
6. Дай мне прочитать итоговый отчёт: что проверено, что нашёл, что починил, что осталось.

## Три бага (что чинили и почему)

Все три — в KF2-флоу распознавания фото, проявляются когда приложение сворачивают,
**пока фото распознаётся или открыта карточка результата** (`/kf2/result`).

**Баг №1 — первый тап по камере (фикс из прошлой сессии).**
При самой первой выдаче разрешения камеры первый тап «проглатывался» (камера
не открывалась, «срабатывает только со второго раза»). Фикс — в
`lib/features/add_meal/screens/kf2_capture_screen.dart` (`_pickImageWithRetry`,
ретрай picker после свежего гранта). Проверь, что регресс не вернул баг.

**Баг №2 — серый экран навсегда при возврате (эта сессия).**
Свернул во время распознавания/при открытой карточке → вернулся → серый экран,
спасал только force-quit. Корень: роут `/kf2/result` делал жёсткий каст
`state.extra as RecognitionResultArgs`, а `extra` теряется/пересобирается при
resume. Фикс: payload кладётся в Riverpod-провайдер
`activeRecognitionResultProvider`; роут (`Kf2ResultPage`) читает его оттуда,
fallback на `extra`, и при реально потерянном payload уводит в `/chat-v2`
вместо краша. (Диагностикой на устройстве подтверждено, что это НЕ build-краш —
серый был следствием связки провайдер/каст, а не одного CastError.)

**Баг №3 — карточка всплывает повторно после сохранения → дубль в журнале (эта сессия).**
После сохранения и навигации (в Дневник и обратно) лист распознавания
показывался снова, и один приём добавлялся дважды. Корень: outcome из FIFO-очереди
`photoRecognitionProvider` consume-ился в `.then()` push-future, а `.then()`
ненадёжен, если чат-экран пересоздаётся (навигация по вкладкам / OS resume) или
ловит `!mounted`. Фикс: outcome consume-ится **в момент показа** карточки (push),
а не закрытия → ровно один показ, независимо от lifecycle чат-экрана.

> Примечание: в ходе сессии была попытка «self-heal» в `_drainOutcomes`
> (сброс `_resultSheetOpen` по `isCurrent`) — она вызывала зацикливание
> переоткрытия на Save и была удалена. Не возвращай её.

## Изменённые файлы (diff против master)
- `lib/features/add_meal/screens/recognition_result_args.dart` — новый `activeRecognitionResultProvider`.
- `lib/features/add_meal/screens/kf2_result_page.dart` — **новый** виджет роута `/kf2/result`.
- `lib/router.dart` — `/kf2/result` использует `Kf2ResultPage`.
- `lib/features/chat/screens/chat_v2_screen.dart` — provider-stash + consume-at-push в `_drainOutcomes`.
- `test/regression/kf2_result_route_refresh_regression_test.dart` — новые тесты.

Вся диагностика (ErrorWidget.builder, FlutterError.onError, зелёный оверлей,
`lib/core/diag.dart`) уже снята — в ветке её быть не должно (проверь `grep -rn DIAG lib/`).

## Команды

Анализ + тесты:
```bash
cd /Users/user/Desktop/КУРСОР/mobileKayfit
export PATH="$PATH:$HOME/development/flutter/bin"
dart analyze lib/
env -u HTTP_PROXY -u HTTPS_PROXY flutter test            # сейчас 300 passed, 2 skipped
```
> Тестам нужен снятый прокси (`env -u HTTP_PROXY -u HTTPS_PROXY`), иначе
> websocket-листенер тестера падает с 403 на localhost.

Dev-install на iPhone (iOS 26.1 — `flutter run` НЕ работает, только build+devicectl).
Прочитай скилл `kayfit-release` и память `project_kayfit_release.md` целиком.
Кратко — Procedure B (Profile, standalone, тапается с домашнего экрана):
1. Создать `ios/Runner/RunnerDebug.entitlements` (только `keychain-access-groups` для `com.kayfit.app.dev`).
2. В блоке Profile `project.pbxproj`: ENTITLEMENTS→RunnerDebug, IDENTITY→"Apple Development",
   STYLE→Automatic, TEAM→`NRV3G463S5`, BUNDLE→`com.kayfit.app.dev`, убрать PROVISIONING_PROFILE_SPECIFIER.
3. `flutter build ios --profile --no-pub`
4. `xcrun devicectl device install app --device 87647915-87F1-505F-81B0-1E6C7ECFDFCD build/ios/iphoneos/Runner.app`
5. **Откатить** pbxproj (`git checkout`) и удалить `RunnerDebug.entitlements` (в коммит НЕ должны попасть).
6. Запуск: `xcrun devicectl device process launch --device 87647915-... com.kayfit.app.dev`.
   После переустановки iOS может сбросить доверие серту → попросить юзера:
   Настройки → Основные → VPN и управление устройством → довериться разработчику.

## Ручной чек-лист на устройстве (deep regress)
Каждый — на **ru и en** (язык устройства).
1. Холодный старт, первая выдача разрешения камеры → **первый** тап открывает камеру (Баг №1).
2. Сфоткай → сверни → подожди ~10 сек → вернись: карточка открывается, серого нет (Баг №2).
3. Карточка открыта → сохрани → перейди в Дневник → вернись в чат: **карточки нет**, дубля в журнале нет (Баг №3).
4. Сфоткай → дождись карточки → сверни/вернись → Сохранить: сохраняется **один раз**.
5. Сфоткай → мгновенно сверни/вернись.
6. Несколько фото подряд (очередь): карточки показываются по одной, без пропусков и без дублей.
7. «Не еда» и сетевая ошибка распознавания: корректное сообщение в чат, без зависаний.
8. Закрыть карточку без сохранения (крестик): в журнал ничего не попало, следующий результат показывается.

## Важные ограничения
- `master` = сборка на ревью в App Store. Пуш/мердж в master — по согласованию (это твоё решение как тимлида/по договорённости с владельцем).
- НЕ коммить `RunnerDebug.entitlements` и патч pbxproj.
- Локальный подписанный App Store IPA на этой машине НЕ собирается (нет команды `MH4VYBU68D`); релизный хэндофф = SOURCE-папка (см. `project_kayfit_release.md`).

## Итог
Дай мне отчёт: ✅/❌ по каждому пункту чек-листа, найденные проблемы, что починил (с коммитами в ветке), статус тестов и аналайзера, и готова ли ветка к мерджу в master.
