"""
app/llm/errors.py
Кастомные исключения LLM-слоя.
"""


class LLMError(Exception):
    """Базовый класс ошибок LLM."""


class LLMTimeout(LLMError):
    """Провайдер не ответил за отведённое время."""


class LLMRateLimit(LLMError):
    """Превышен rate limit провайдера."""


class LLMInvalidSchema(LLMError):
    """Ответ провайдера не соответствует ожидаемой JSON-схеме."""


class LLMUnavailable(LLMError):
    """Провайдер недоступен после всех попыток."""
