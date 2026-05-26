"""
app/llm/providers/qwen.py
Основной LLM провайдер — Qwen через DashScope (OpenAI-compatible).
Реализует LLMTextProvider и LLMVisionProvider (structural subtyping).
"""
import asyncio
import json
import logging

from openai import AsyncOpenAI, APITimeoutError, RateLimitError, APIStatusError

from app.llm.errors import (
    LLMInvalidSchema,
    LLMRateLimit,
    LLMTimeout,
    LLMUnavailable,
)

logger = logging.getLogger(__name__)

_RETRY_COUNT = 2
_RETRY_BASE_DELAY = 1.0  # секунды, удваивается при каждой попытке


class QwenProvider:
    """
    Провайдер Qwen. Создавай через router.get_qwen_provider() — не напрямую.
    """

    def __init__(self, api_key: str, base_url: str) -> None:
        self._client = AsyncOpenAI(
            api_key=api_key,
            base_url=base_url,
            timeout=30.0,
        )

    # ── internal ──────────────────────────────────────────────────────────

    async def _call(self, **kwargs) -> str:
        """
        Вызывает chat.completions.create с exponential-backoff retry.
        Возвращает строку-JSON. Raises LLM* при неудаче.
        """
        last_exc: Exception | None = None

        for attempt in range(_RETRY_COUNT + 1):
            try:
                response = await self._client.chat.completions.create(**kwargs)
                content = (response.choices[0].message.content or "").strip()

                if not content:
                    raise LLMInvalidSchema("Empty response from Qwen")

                json.loads(content)  # validate — raises if not JSON
                return content

            except (LLMInvalidSchema, json.JSONDecodeError) as exc:
                last_exc = LLMInvalidSchema(str(exc))
                if attempt < _RETRY_COUNT:
                    logger.warning("Qwen invalid schema attempt=%d: %s", attempt, exc)
                    await asyncio.sleep(_RETRY_BASE_DELAY * (2 ** attempt))
                else:
                    raise LLMInvalidSchema(str(exc)) from exc

            except APITimeoutError as exc:
                last_exc = LLMTimeout(str(exc))
                if attempt < _RETRY_COUNT:
                    logger.warning("Qwen timeout attempt=%d", attempt)
                    await asyncio.sleep(_RETRY_BASE_DELAY * (2 ** attempt))
                else:
                    raise LLMTimeout("Qwen timeout after retries") from exc

            except RateLimitError as exc:
                last_exc = LLMRateLimit(str(exc))
                if attempt < _RETRY_COUNT:
                    delay = _RETRY_BASE_DELAY * (2 ** attempt) * 3
                    logger.warning(
                        "Qwen rate limit attempt=%d, sleeping %.1fs", attempt, delay
                    )
                    await asyncio.sleep(delay)
                else:
                    raise LLMRateLimit("Qwen rate limit after retries") from exc

            except APIStatusError as exc:
                if exc.status_code >= 500 and attempt < _RETRY_COUNT:
                    last_exc = LLMUnavailable(str(exc))
                    await asyncio.sleep(_RETRY_BASE_DELAY * (2 ** attempt))
                else:
                    raise LLMUnavailable(
                        f"Qwen API error {exc.status_code}: {exc.message}"
                    ) from exc

            except Exception as exc:
                raise LLMUnavailable(f"Unexpected Qwen error: {exc}") from exc

        raise LLMUnavailable("Qwen unavailable after all retries") from last_exc

    # ── LLMTextProvider ───────────────────────────────────────────────────

    async def complete(
        self,
        system: str,
        user: str,
        *,
        model: str,
        max_tokens: int = 1000,
        temperature: float = 0.0,
    ) -> str:
        messages = []
        if system:
            messages.append({"role": "system", "content": system})
        messages.append({"role": "user", "content": user})

        return await self._call(
            model=model,
            messages=messages,
            max_tokens=max_tokens,
            temperature=temperature,
            response_format={"type": "json_object"},
        )

    # ── LLMVisionProvider ─────────────────────────────────────────────────

    async def complete_vision(
        self,
        system: str,
        user_text: str,
        image_b64: str,
        *,
        model: str,
        max_tokens: int = 1200,
        temperature: float = 0.0,
    ) -> str:
        """
        image_b64 — base64 JPEG после preprocess_image(), без data URI.
        """
        data_uri = f"data:image/jpeg;base64,{image_b64}"

        messages = []
        if system:
            messages.append({"role": "system", "content": system})
        messages.append({
            "role": "user",
            "content": [
                {"type": "image_url", "image_url": {"url": data_uri}},
                {"type": "text", "text": user_text},
            ],
        })

        return await self._call(
            model=model,
            messages=messages,
            max_tokens=max_tokens,
            temperature=temperature,
            response_format={"type": "json_object"},
        )
