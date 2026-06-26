# Фикс: голосовой ввод обрывается на паузе (пишется только половина)

> Инструкция для нового окна Claude Code. Самодостаточна — читать целиком перед началом.
> Проект: **KayFit / Carb Counter**, Flutter. Репозиторий: `/Users/user/Desktop/КУРСОР/mobileKayfit`, ветка `master`.
> Текущая версия в pubspec: `1.2.2+9`. Последний билд под App Store review: `1.2.2+8`.

---

## 1. Симптом (со слов пользователя)

Включаешь голосовой ввод (микрофон в чате), говоришь — как только делаешь небольшую паузу, запись прерывается. В итоге транскрибируется только первая половина сказанного.

## 2. Корень проблемы (уже локализован)

Весь голосовой ввод — в одном файле: **`lib/features/chat/screens/chat_v2_screen.dart`**.
Используется пакет `speech_to_text: ^7.0.0` (на iOS это нативный `SFSpeechRecognizer`).

Поле движка: `final _speech = SpeechToText();` (~строка 137).

Виновник — параметры `listen()` (~строки 1350–1369):

```dart
await _speech.listen(
  onResult: (result) {
    if (!mounted) return;
    final words = result.recognizedWords;
    setState(() {
      _textController.text = words;            // ← ПЕРЕЗАПИСЫВАЕТ, не дописывает
      _textController.selection = TextSelection.fromPosition(
        TextPosition(offset: words.length),
      );
      if (result.finalResult) _fromVoice = true;
    });
  },
  localeId: localeId,
  listenOptions: SpeechListenOptions(
    partialResults: true,
    listenMode: ListenMode.dictation,
    listenFor: const Duration(seconds: 30),    // ← жёсткий потолок 30 сек
    pauseFor: const Duration(seconds: 3),      // ← ОБРЫВ на 3 сек тишины
  ),
);
```

И обработчик статуса в `_ensureSpeechReady()` (~строка 1276–1283):

```dart
onStatus: (status) {
  if ((status == SpeechToText.doneStatus ||
          status == SpeechToText.notListeningStatus) &&
      mounted) {
    setState(() => _voiceState = _VoiceState.idle);   // ← гасит запись при любом done
  }
},
```

Три причины обрыва, все надо устранить:
1. **`pauseFor: 3s`** — движок сам завершает сессию после 3 сек тишины (это и есть «обрыв на паузе»).
2. **`listenFor: 30s`** — даже без пауз запись жёстко режется на 30 секундах.
3. **`onStatus` → `idle`** при `done/notListening` — нет авто-перезапуска, любое завершение сессии гасит UI в простой.

Важно знать про iOS: даже если убрать `pauseFor`/`listenFor`, нативный `SFSpeechRecognizer` **всё равно** останавливается на тишине и имеет собственный лимит сессии (~60 сек). Поэтому «писать без ограничений до тапа» нельзя одними параметрами — **нужен авто-перезапуск сессии с накоплением текста**.

## 3. Требуемое поведение (согласовано с пользователем)

- **Остановка только по тапу** на микрофон. Паузы в речи запись НЕ прерывают.
- **Без лимита по времени** — пишем, пока пользователь сам не остановит.
- Платформа теста: **iOS (iPhone)**. (Android трогать не требуется, но не сломать.)
- Подход: **остаёмся на on-device `speech_to_text`** (без записи аудио и отправки на бэкенд).

## 4. Что реализовать (паттерн «restart + accumulate»)

Идея: одна логическая «запись» = серия нативных сессий `listen()`, которые мы сами перезапускаем, пока пользователь не нажал стоп. Финализированный текст каждой сессии копим в буфер, новые частичные результаты дописываем к буферу (а не перезаписываем поле).

Конкретно:

1. **Флаг намеренной остановки.** Добавить поле, напр. `bool _userStoppedVoice = false;`.
   - В `_startListening()` перед стартом: `_userStoppedVoice = false;`.
   - В `_stopListening()` **первым делом**: `_userStoppedVoice = true;` затем `await _speech.stop();` → `idle`.

2. **Буфер накопленного текста.** Напр. `String _committedTranscript = '';`.
   - В `onResult`: показывать в поле `(_committedTranscript + ' ' + result.recognizedWords).trim()`,
     а НЕ голый `result.recognizedWords`.
   - Когда сессия завершилась (по `finalResult` или при перезапуске): дописать распознанное в `_committedTranscript` и очистить «текущую» часть, чтобы следующая сессия не затёрла предыдущую.
   - В начале новой записи (`_startListening`) обнулять `_committedTranscript = '';`.

3. **Авто-перезапуск.** Логику завершения сессии вынести в отдельный метод, напр. `_onSessionEnded()`, который вызывается из `onStatus` (`done`/`notListening`) и из `onError` для штатных таймаутов (`error_speech_timeout`, `error_no_match`):
   - если `_userStoppedVoice == true` → реально уходим в `idle` (это был тап пользователя);
   - иначе (тишина / iOS-лимит) → НЕ гасим UI, остаёмся в `_VoiceState.recording`, коммитим текущий текст в буфер и **вызываем `listen()` заново** (с маленькой задержкой ~50–150 мс, чтобы нативный движок успел освободиться).

4. **Параметры `listen()`** изменить так, чтобы один проход был максимально длинным:
   - `pauseFor` — убрать или поставить очень большим (напр. 60+ сек); основную «бесконечность» обеспечивает перезапуск, а не этот параметр.
   - `listenFor` — убрать (или 60 сек, под нативный лимит) и полагаться на перезапуск.
   - `partialResults: true` и `listenMode: ListenMode.dictation` оставить.

5. **UI не должен мигать.** Между перезапусками `_voiceState` обязан оставаться `recording` (индикатор/гаптика не сбрасываются). В `idle` уходим только при намеренном стопе или фатальной ошибке.

## 5. Подводные камни (обязательно учесть)

- **`recognizedWords` обнуляется на каждой новой сессии** — отсюда требование копить буфер, иначе перезапуск затрёт сказанное (тот же баг, но наоборот).
- **`onError` сейчас гасит в `idle`** для всех ошибок кроме показа снэкбара (~строки 1284–1305). `error_speech_timeout` и `error_no_match` при не-намеренной остановке должны вести к **перезапуску**, а не к `idle`. Реальные ошибки (нет разрешений и т.п.) — по-прежнему в `idle` + снэкбар.
- **Гонки/циклы.** Защититься от бесконечного быстрого рестарта при мгновенных ошибках: дебаунс перед `listen()` и/или счётчик подряд пустых сессий с мягким выходом. Не делать tight-loop.
- **`mounted` / dispose.** При уходе с экрана или `dispose()` — `_userStoppedVoice = true` и `_speech.stop()/cancel()`, иначе движок продолжит крутиться в фоне. Проверять `context.mounted` после каждого `await`.
- **Разрешения iOS** уже должны быть в `ios/Runner/Info.plist` (`NSSpeechRecognitionUsageDescription`, `NSMicrophoneUsageDescription`) — проверить, фича уже в проде.
- **Тёплый старт движка.** В коде есть намеренная задержка 300 мс после `initialize()` («без неё первый listen ничего не пишет») — не выкидывать её.
- **Стиль (правила проекта Dart):** `dart format`, строки ≤80, trailing commas, без `late`/`!` без нужды, `const` где можно, проверять `context.mounted` после await.

## 6. Проверка (по правилу «деплой ПЕРЕД тестом» из CLAUDE.md)

> Порядок железный: тесты → установка на iPhone → сам убедись → потом отдавать пользователю.

1. **Статика/тесты:**
   ```bash
   cd /Users/user/Desktop/КУРСОР/mobileKayfit
   dart format lib/features/chat/screens/chat_v2_screen.dart
   dart analyze
   flutter test
   ```
2. **Установка на iPhone — ОБЯЗАТЕЛЬНО.** Сначала прочитать память `project_kayfit_release.md` целиком и запустить **скилл `kayfit-release`** (он знает про bundle-id swap, team MH4VYBU68D, Debug vs Profile, UDID). НЕ запускать `flutter run --release/--profile` вслепую. Не коммитить `BYPASS_PAYWALL`.
3. **Smoke-тест самому** на устройстве: включить микрофон, говорить с несколькими паузами по 4–6 сек, убедиться что:
   - запись НЕ обрывается на паузах;
   - текст накапливается (не затирается), а не теряется;
   - запись идёт дольше 30 сек;
   - останавливается ровно по повторному тапу.
4. **Чёткий чек-лист пользователю** что нажать/сказать — только после того как сам увидел, что работает на телефоне.

## 7. Коммит / версия

- По правилу проекта: коммит по завершении фазы (conventional commits, тип `fix`), без подписи Claude.
- Если планируется новая App Store сабмиссия — бампнуть build в `pubspec.yaml` и обновить `ios/Runner/whatsnew.txt`. (Сейчас `1.2.2+9`.)

## 8. Полезные ссылки в памяти

- `project_kayfit_release.md` + скилл `kayfit-release` — установка на iPhone (читать ПЕРЕД build/install).
- `project_kayfit_versions.md` — правила версий и веток.
- `project_kayfit_paywall_bypass.md` — `BYPASS_PAYWALL`, не коммитить в master.
- `feedback_always_install_on_phone.md`, `feedback_deploy_before_test.md` — правило «деплой перед тестом».

## 9. Ключевые якоря в коде (могут сдвинуться — проверить grep'ом)

- `lib/features/chat/screens/chat_v2_screen.dart`
  - `final _speech = SpeechToText();` — ~137
  - `_ensureSpeechReady()` / `onStatus` / `onError` — ~1272–1315
  - `_startListening()` + `_speech.listen(...)` — ~1317–1370
  - `_stopListening()` — ~1372–1375
  - `_handleMic()` — ~1255–1265
- Связанное: `lib/features/chat/providers/transcription_pending_provider.dart`.
