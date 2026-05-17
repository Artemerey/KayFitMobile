#!/usr/bin/env python3
"""
Генератор CHANGELOG.md для KayFit.

Использование:
  python scripts/generate_changelog.py --version 1.0.3+1

Что делает:
  1. Берёт git log с момента последнего тега
  2. Группирует коммиты по типу (feat/fix/chore/...)
  3. Просит Claude перевести и сформулировать по-русски
  4. Вставляет новую секцию в начало CHANGELOG.md

Требования:
  ANTHROPIC_API_KEY в .env или переменной окружения
"""

import argparse
import os
import re
import subprocess
import sys
from datetime import date
from pathlib import Path

import anthropic
from dotenv import load_dotenv

REPO_ROOT = Path(__file__).parent.parent
CHANGELOG_PATH = REPO_ROOT / "CHANGELOG.md"

COMMIT_TYPE_MAP = {
    "feat": "Добавлено",
    "fix": "Исправлено",
    "refactor": "Изменено",
    "style": "Изменено",
    "perf": "Изменено",
    "chore": "Служебное",
    "docs": "Документация",
    "test": "Тесты",
    "ci": "CI/CD",
    "revert": "Откат",
}

INCLUDE_TYPES = {"feat", "fix", "refactor", "style", "perf"}


def get_last_tag() -> str | None:
    result = subprocess.run(
        ["git", "describe", "--tags", "--abbrev=0"],
        capture_output=True, text=True, cwd=REPO_ROOT
    )
    return result.stdout.strip() if result.returncode == 0 else None


def get_commits_since(tag: str | None) -> list[dict]:
    ref = f"{tag}..HEAD" if tag else "HEAD"
    result = subprocess.run(
        ["git", "log", ref, "--pretty=format:%H|%s|%b", "--no-merges"],
        capture_output=True, text=True, cwd=REPO_ROOT
    )
    commits = []
    for line in result.stdout.strip().splitlines():
        if not line.strip():
            continue
        parts = line.split("|", 2)
        if len(parts) < 2:
            continue
        sha, subject = parts[0], parts[1]
        match = re.match(r"^(\w+)(?:\([\w/-]+\))?!?:\s*(.+)$", subject)
        if match:
            commits.append({
                "sha": sha[:8],
                "type": match.group(1),
                "description": match.group(2).strip(),
            })
        else:
            commits.append({"sha": sha[:8], "type": "other", "description": subject})
    return commits


def translate_commits(commits: list[dict], version: str) -> str:
    load_dotenv(REPO_ROOT.parent / ".env")
    load_dotenv(REPO_ROOT / ".env")

    api_key = os.environ.get("ANTHROPIC_API_KEY")
    if not api_key:
        sys.exit("ANTHROPIC_API_KEY не найден в .env")

    client = anthropic.Anthropic(api_key=api_key)

    grouped: dict[str, list[str]] = {}
    for c in commits:
        if c["type"] not in INCLUDE_TYPES:
            continue
        section = COMMIT_TYPE_MAP.get(c["type"], "Изменено")
        grouped.setdefault(section, []).append(c["description"])

    if not grouped:
        return ""

    commit_text = "\n".join(
        f"[{section}]\n" + "\n".join(f"- {d}" for d in descs)
        for section, descs in grouped.items()
    )

    prompt = f"""Ты — технический редактор приложения KayFit (трекер питания для iOS).

Список изменений для версии {version} на английском языке (сгруппированы по типу):

{commit_text}

Задача:
1. Переведи каждый пункт на русский язык — кратко и понятно для конечного пользователя или разработчика.
2. Если пункт технический (migrating, refactor, chore), перефразируй как улучшение, понятное человеку.
3. Сохрани группировку: [Добавлено], [Исправлено], [Изменено]. Не добавляй пустые секции.
4. Каждый пункт — одна строка, начинается с «- ».
5. Верни ТОЛЬКО готовый markdown-текст секций, без комментариев, заголовка версии и дат.

Пример вывода:
### Добавлено
- Кнопка повтора при ошибке распознавания фото

### Исправлено
- Фото в чате больше не зависало без ответа

ВАЖНО: заголовки секций пиши строго как «### Добавлено», «### Исправлено», «### Изменено» (с ###)."""

    message = client.messages.create(
        model="claude-haiku-4-5-20251001",
        max_tokens=1024,
        messages=[{"role": "user", "content": prompt}],
    )
    return message.content[0].text.strip()


def prepend_to_changelog(version: str, body: str) -> None:
    today = date.today().strftime("%Y-%m-%d")
    header = f"## [{version}] — {today}\n\n"
    new_section = header + body + "\n\n---\n\n"

    existing = CHANGELOG_PATH.read_text(encoding="utf-8") if CHANGELOG_PATH.exists() else ""

    # Вставить после первого H1 и пустой строки, перед первым H2
    if "## [" in existing:
        insert_at = existing.index("## [")
        updated = existing[:insert_at] + new_section + existing[insert_at:]
    else:
        updated = existing + "\n" + new_section

    CHANGELOG_PATH.write_text(updated, encoding="utf-8")
    print(f"✓ CHANGELOG.md обновлён — версия {version}")


def main():
    parser = argparse.ArgumentParser(description="Генератор CHANGELOG для KayFit")
    parser.add_argument("--version", required=True, help="Версия, например 1.0.3+1")
    parser.add_argument("--dry-run", action="store_true", help="Показать результат без записи в файл")
    args = parser.parse_args()

    last_tag = get_last_tag()
    print(f"Последний тег: {last_tag or '(нет)'}")

    commits = get_commits_since(last_tag)
    relevant = [c for c in commits if c["type"] in INCLUDE_TYPES]
    print(f"Коммитов для включения: {len(relevant)} из {len(commits)}")

    if not relevant:
        print("Нет feat/fix/refactor коммитов — CHANGELOG не обновлён.")
        return

    print("Переводим через Claude...")
    body = translate_commits(commits, args.version)

    if args.dry_run:
        print("\n--- Превью ---")
        print(f"## [{args.version}] — {date.today()}\n\n{body}")
        return

    prepend_to_changelog(args.version, body)


if __name__ == "__main__":
    main()
