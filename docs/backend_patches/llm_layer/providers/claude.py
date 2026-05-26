"""
app/llm/providers/claude.py
Аварийный fallback провайдер.
Используется ТОЛЬКО при LLM_FALLBACK_ENABLED=true и недоступности Qwen.
Реализует только LLMTextProvider (vision fallback не нужен).
"""
import json
import logging
import re

import anthropic

from app.llm.errors import LLMUnavailable

logger = logging.getLogger(__name__)


class ClaudeProvider:
    def __init__(self, api_key: str) -> None:
        # AsyncAnthropic — non-blocking, safe inside FastAPI async event loop
        self._client = anthropic.AsyncAnthropic(api_key=api_key)

    async def complete(
        self,
        system: str,
        user: str,
        *,
        model: str = "claude-haiku-4-5-20251001",
        max_tokens: int = 1000,
        temperature: float = 0.0,
    ) -> str:
        try:
            resp = await self._client.messages.create(
                model=model,
                max_tokens=max_tokens,
                system=system or "You are a helpful assistant.",
                messages=[{"role": "user", "content": user}],
            )
            content = (resp.content[0].text or "").strip()

            # Claude не поддерживает json_object mode — снимаем markdown
            if content.startswith("```"):
                content = re.sub(r"^```\w*\n?", "", content)
                content = re.sub(r"\n?```\s*$", "", content)

            json.loads(content)  # validate
            return content

        except Exception as exc:
            logger.error("Claude fallback error: %s", exc)
            raise LLMUnavailable(f"Claude fallback failed: {exc}") from exc
