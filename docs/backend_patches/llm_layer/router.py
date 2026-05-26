"""
app/llm/router.py
Фабрика провайдеров. Читает env vars, создаёт синглтоны.
Все остальные модули импортируют провайдеров только отсюда.
"""
import logging
import os
from functools import lru_cache

from app.llm.errors import LLMUnavailable
from app.llm.providers.qwen import QwenProvider

logger = logging.getLogger(__name__)


@lru_cache(maxsize=1)
def _qwen() -> QwenProvider:
    key = os.environ.get("DASHSCOPE_API_KEY", "")
    base_url = os.environ.get(
        "DASHSCOPE_BASE_URL",
        "https://dashscope-intl.aliyuncs.com/compatible-mode/v1",
    )
    if not key:
        raise LLMUnavailable("DASHSCOPE_API_KEY is not set")
    return QwenProvider(api_key=key, base_url=base_url)


def get_vision_provider() -> QwenProvider:
    """Провайдер для vision-запросов. Всегда Qwen."""
    return _qwen()


def get_text_provider():
    """
    Провайдер для текстовых запросов.
    При LLM_FALLBACK_ENABLED=true и отсутствии Qwen — пробует Claude.
    """
    try:
        return _qwen()
    except LLMUnavailable:
        if os.environ.get("LLM_FALLBACK_ENABLED", "false").lower() == "true":
            from app.llm.providers.claude import ClaudeProvider
            key = os.environ.get("ANTHROPIC_API_KEY", "")
            if key:
                logger.warning("Qwen unavailable — falling back to Claude")
                return ClaudeProvider(api_key=key)
        raise


# ── Модели ────────────────────────────────────────────────────────────────

def vision_model() -> str:
    return os.environ.get("QWEN_VISION_MODEL", "qwen3-vl-flash")


def vision_model_fallback() -> str:
    return os.environ.get("QWEN_VISION_MODEL_FALLBACK", "qwen3-vl-plus")


def text_model() -> str:
    return os.environ.get("QWEN_TEXT_MODEL", "qwen-turbo")
