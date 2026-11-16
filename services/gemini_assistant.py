"""Gemini API multimodal assistant for smart screenshot naming and note summarization."""

import base64
import json
import mimetypes
import os
import re
from typing import Iterable

from google import genai

DEFAULT_GEMINI_MODEL = "gemini-4-hydrogen"
MAX_IMAGES_PER_REQUEST = 12
MAX_TOTAL_INLINE_BYTES = 16 * 1024 * 1024


class GeminiAssistantError(Exception):
    """Domain error raised when Gemini assistant inputs or API calls fail."""

    def __init__(self, code: str, message: str = ""):
        super().__init__(message or code)
        self.code = code
        self.message = message or code


def resolve_api_key(config_key: str = "") -> tuple[str, str]:
    """Resolve effective Gemini API key and its source ('config', 'env', or 'none')."""
    cleaned_cfg = config_key.strip() if isinstance(config_key, str) else ""
    if cleaned_cfg:
        return cleaned_cfg, "config"
    env_key = os.environ.get("GEMINI_API_KEY", "").strip()
    if env_key:
        return env_key, "env"
    return "", "none"


def mask_api_key(api_key: str) -> str:
    """Return a masked hint for UI display without exposing the full secret."""
    if not api_key:
        return ""
    if len(api_key) <= 8:
        return "••••"
    return f"••••{api_key[-4:]}"


def sanitize_slug(raw_slug: str, fallback: str = "screenshot") -> str:
    """Normalize a model-generated topic into a safe lowercase ASCII filename slug."""
    if not isinstance(raw_slug, str):
        return fallback
    cleaned = raw_slug.strip().lower()
    cleaned = re.sub(r"\.[a-z0-9]+$", "", cleaned)
    cleaned = re.sub(r"[^a-z0-9]+", "_", cleaned)
    cleaned = re.sub(r"_+", "_", cleaned).strip("_")
    if not cleaned:
        return fallback
    return cleaned[:48].rstrip("_") or fallback


def _build_image_parts(folder: str, filenames: Iterable[str]) -> tuple[list[dict], list[str]]:
    """Load up to MAX_IMAGES_PER_REQUEST image files as inline base64 content blocks."""
    selected: list[str] = []
    parts: list[dict] = []
    total_bytes = 0

    for name in filenames:
        if len(selected) >= MAX_IMAGES_PER_REQUEST:
            break
        full_path = os.path.join(folder, name)
        if not os.path.isfile(full_path):
            continue
        size = os.path.getsize(full_path)
        if total_bytes + size > MAX_TOTAL_INLINE_BYTES:
            if selected:
                break
            raise GeminiAssistantError("payload_too_large", "Image file exceeds inline size limit")

        mime_type, _ = mimetypes.guess_type(full_path)
        if not mime_type or not mime_type.startswith("image/"):
            mime_type = "image/png"

        with open(full_path, "rb") as f:
            b64_data = base64.b64encode(f.read()).decode("ascii")

        total_bytes += size
        selected.append(name)
        parts.append({"type": "text", "text": f"Image #{len(selected)}: {name}"})
        parts.append({"type": "image", "data": b64_data, "mime_type": mime_type})

    if not selected:
        raise GeminiAssistantError("no_images", "No valid image files found")

    return parts, selected


def _create_client(api_key: str) -> genai.Client:
    """Create a Google GenAI SDK client with the resolved API key."""
    if not api_key:
        raise GeminiAssistantError("missing_api_key", "Gemini API key is not configured")
    return genai.Client(api_key=api_key)


def suggest_filenames(
    folder: str,
    filenames: list[str],
    start_num: int = 1,
    lang: str = "en",
    api_key: str = "",
    model: str = DEFAULT_GEMINI_MODEL,
) -> list[dict]:
    """Analyze screenshots with Gemini and return ordered, filesystem-safe filename suggestions."""
    client = _create_client(api_key)
    image_parts, selected = _build_image_parts(folder, filenames)

    lang_hint = (
        "Use concise English topic slugs (2-5 words, lowercase ASCII with underscores)."
        if lang != "vi"
        else "Create concise lowercase ASCII underscore slugs (2-5 words, unaccented or English) describing each screenshot's topic."
    )
    prompt = (
        "You are organizing a chronological sequence of screenshots (e.g. slides, book pages, docs, or UI screens). "
        "For each screenshot in the exact order provided, generate a short, descriptive topic slug based on its visual content "
        "(main heading, slide title, chapter name, or key subject). "
        f"{lang_hint} "
        "Return one entry per image matching its original_name."
    )

    schema = {
        "type": "object",
        "properties": {
            "suggestions": {
                "type": "array",
                "items": {
                    "type": "object",
                    "properties": {
                        "original_name": {"type": "string"},
                        "slug": {
                            "type": "string",
                            "description": "Short 2-5 word lowercase ASCII underscore slug without file extension.",
                        },
                    },
                    "required": ["original_name", "slug"],
                },
            }
        },
        "required": ["suggestions"],
    }

    try:
        interaction = client.interactions.create(
            model=model,
            input=[{"type": "text", "text": prompt}, *image_parts],
            response_format={
                "type": "text",
                "mime_type": "application/json",
                "schema": schema,
            },
        )
    except Exception as exc:
        raise GeminiAssistantError("api_error", str(exc)) from exc

    raw_text = (interaction.output_text or "").strip()
    try:
        parsed = json.loads(raw_text)
    except json.JSONDecodeError as exc:
        raise GeminiAssistantError("invalid_response", f"Invalid JSON from Gemini: {exc}") from exc

    raw_items = parsed.get("suggestions") if isinstance(parsed, dict) else None
    if not isinstance(raw_items, list):
        raise GeminiAssistantError("invalid_response", "Missing suggestions list in Gemini response")

    slug_by_name: dict[str, str] = {}
    ordered_slugs: list[str] = []
    for item in raw_items:
        if not isinstance(item, dict):
            continue
        slug = sanitize_slug(item.get("slug", ""))
        ordered_slugs.append(slug)
        orig = item.get("original_name")
        if isinstance(orig, str) and orig:
            slug_by_name[orig] = slug

    pad_width = max(2, len(str(max(0, start_num + len(selected) - 1))))
    used_names: set[str] = set()
    results: list[dict] = []

    for idx, orig_name in enumerate(selected):
        num = start_num + idx
        slug = slug_by_name.get(orig_name)
        if not slug:
            slug = ordered_slugs[idx] if idx < len(ordered_slugs) else "screenshot"

        candidate = f"{num:0{pad_width}d}_{slug}.png"
        if candidate in used_names:
            candidate = f"{num:0{pad_width}d}_{slug}_{idx + 1}.png"
        used_names.add(candidate)

        results.append({
            "index": idx + 1,
            "original_name": orig_name,
            "new_name": candidate,
        })

    return results


def summarize_screenshots(
    folder: str,
    filenames: list[str],
    lang: str = "en",
    api_key: str = "",
    model: str = DEFAULT_GEMINI_MODEL,
) -> tuple[str, int]:
    """Summarize key points / OCR text from screenshots into concise Markdown notes."""
    client = _create_client(api_key)
    image_parts, selected = _build_image_parts(folder, filenames)

    if lang == "vi":
        prompt = (
            "Hãy đọc các ảnh chụp màn hình theo đúng thứ tự và tóm tắt thành ghi chú học tập/công việc ngắn gọn bằng tiếng Việt "
            "(dùng Markdown rõ ràng với tiêu đề theo từng ảnh, gạch đầu dòng các ý chính, định nghĩa, công thức hoặc thông tin quan trọng)."
        )
    else:
        prompt = (
            "Read these screenshots in order and summarize them into concise, structured Markdown study/reference notes in English "
            "(include a short heading per screenshot/page and bullet points for key concepts, definitions, or extracted text)."
        )

    try:
        interaction = client.interactions.create(
            model=model,
            input=[{"type": "text", "text": prompt}, *image_parts],
        )
    except Exception as exc:
        raise GeminiAssistantError("api_error", str(exc)) from exc

    summary = (interaction.output_text or "").strip()
    if not summary:
        raise GeminiAssistantError("invalid_response", "Empty summary returned by Gemini")

    return summary, len(selected)
