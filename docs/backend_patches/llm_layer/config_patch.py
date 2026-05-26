"""
ПАТЧ: app/config.py
ДОБАВИТЬ эти переменные в существующий config.py.
Старые переменные (ANTHROPIC_API_KEY и т.д.) оставить — они нужны для fallback.
"""
import os

# ── Qwen / DashScope (основной провайдер) ─────────────────────────────────
DASHSCOPE_API_KEY: str = os.environ.get("DASHSCOPE_API_KEY", "")
DASHSCOPE_BASE_URL: str = os.environ.get(
    "DASHSCOPE_BASE_URL",
    "https://dashscope-intl.aliyuncs.com/compatible-mode/v1",
)
QWEN_VISION_MODEL: str = os.environ.get("QWEN_VISION_MODEL", "qwen3-vl-flash")
QWEN_VISION_MODEL_FALLBACK: str = os.environ.get(
    "QWEN_VISION_MODEL_FALLBACK", "qwen3-vl-plus"
)
QWEN_TEXT_MODEL: str = os.environ.get("QWEN_TEXT_MODEL", "qwen-turbo")

# ── Claude (только аварийный fallback) ───────────────────────────────────
# ANTHROPIC_API_KEY уже есть в config.py — не дублировать
LLM_FALLBACK_ENABLED: bool = (
    os.environ.get("LLM_FALLBACK_ENABLED", "false").lower() == "true"
)

# ── FatSecret Premier (Фаза 3 — КБЖУ lookup) ─────────────────────────────
FATSECRET_CONSUMER_KEY: str = os.environ.get("FATSECRET_CONSUMER_KEY", "")
FATSECRET_CONSUMER_SECRET: str = os.environ.get("FATSECRET_CONSUMER_SECRET", "")
