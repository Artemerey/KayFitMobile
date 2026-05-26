"""
app/llm/image_utils.py
Препроцессинг изображений перед отправкой в vision-модель.
Уменьшает размер и стоимость вызова в 2-3x без потери качества.
"""
import base64
import io

from PIL import Image

MAX_SIDE = 1024
JPEG_QUALITY = 85


def preprocess_image(image_data: bytes) -> str:
    """
    1. Открывает изображение любого формата (JPEG, PNG, WEBP, HEIC).
    2. Конвертирует в RGB если нужно.
    3. Ресайзит до MAX_SIDE по длинной стороне с сохранением пропорций.
    4. Сохраняет как JPEG quality=85.
    5. Возвращает base64-строку (без data URI префикса).
    """
    img = Image.open(io.BytesIO(image_data))

    # EXIF rotation
    try:
        from PIL import ImageOps
        img = ImageOps.exif_transpose(img)
    except Exception:
        pass

    if img.mode not in ("RGB", "L"):
        img = img.convert("RGB")

    w, h = img.size
    if max(w, h) > MAX_SIDE:
        scale = MAX_SIDE / max(w, h)
        new_w, new_h = int(w * scale), int(h * scale)
        img = img.resize((new_w, new_h), Image.LANCZOS)

    buf = io.BytesIO()
    img.save(buf, format="JPEG", quality=JPEG_QUALITY, optimize=True)
    return base64.standard_b64encode(buf.getvalue()).decode("ascii")
