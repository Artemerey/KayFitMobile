"""
app/llm/base.py
Protocol-интерфейсы провайдеров. Используй structural subtyping — не наследуйся.
"""
from typing import Protocol, runtime_checkable


@runtime_checkable
class LLMTextProvider(Protocol):
    async def complete(
        self,
        system: str,
        user: str,
        *,
        model: str,
        max_tokens: int = 1000,
        temperature: float = 0.0,
    ) -> str:
        """
        Возвращает строку с валидным JSON (response_format=json_object).
        Raises: LLMTimeout, LLMRateLimit, LLMInvalidSchema, LLMUnavailable.
        """
        ...


@runtime_checkable
class LLMVisionProvider(Protocol):
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
        image_b64 — base64 JPEG (после preprocess_image).
        Возвращает строку с валидным JSON.
        Raises: LLMTimeout, LLMRateLimit, LLMInvalidSchema, LLMUnavailable.
        """
        ...
