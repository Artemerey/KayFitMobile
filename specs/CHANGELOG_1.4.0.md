# KayFit 1.4.0+17

- Операции сохранения еды идемпотентны: повтор или поздний callback не создаёт дубль.
- Инциденты доставляются через durable outbox после offline/reconnect без чувствительных payload.
- Android voice корректно обрабатывает длинный текст, паузы, restart и late callback.
- Auth handoff атомарно переносит план онбординга при входе и регистрации.
- Label recognition разделяет значения на 100 г и на порцию, учитывает кДж и запрашивает уточнение при неоднозначности.
- Chat delivery проходит receive, parse, durable receive и post-frame render acknowledgment; reload/resume восстанавливают ответ ровно один раз.
- Incident storage, Telegram, analytics и логи не получают текст чата, prompt, raw response, token, email, secret URL или stack trace.

## Verification

- Flutter full suite: 427 passed, 2 skipped.
- Backend full suite: 964 passed, 29 deselected, 10 subtests passed.
- Flutter analyze: 0 errors; 74 pre-existing info/warning diagnostics.
- Android debug APK и iOS no-codesign device build собраны успешно.
- iOS Simulator cold launch выполнен; физический iPhone и Apple Sign In на нём не проверялись.
