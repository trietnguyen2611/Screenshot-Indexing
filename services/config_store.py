"""Persistent JSON configuration storage for Screenshot Indexing."""

import copy
import json
import math
import os
import tempfile
import threading

DEFAULT_CONFIG = {
    "save_folder": "",
    "region": {"x": 100, "y": 100, "width": 800, "height": 600},
    "interval_sec": 3,
    "max_shots": 0,
    "countdown_sec": 3,
    "page_turn": {
        "enabled": True,
        "mode": "keyboard",
        "key_name": "ArrowRight",
        "key_code": 124,
        "click_x": 500,
        "click_y": 500,
    },
    "sound_enabled": True,
}

_CONFIG_LOCK = threading.Lock()


def get_config_path() -> str:
    """Return the persistent JSON config file path, honoring test env override."""
    override = os.environ.get("SCREENSHOT_INDEXING_CONFIG_PATH", "").strip()
    if override:
        return os.path.expanduser(override)
    return os.path.join(
        os.path.expanduser("~"),
        "Library",
        "Application Support",
        "Screenshot Indexing",
        "config.json",
    )


def _coerce_int(
    value,
    default: int,
    min_val: int | None = None,
    max_val: int | None = None,
) -> int:
    """Safely coerce a value to int and clamp within optional bounds."""
    if value is None or isinstance(value, bool):
        result = default
    else:
        try:
            num = float(value)
            if not math.isfinite(num):
                result = default
            else:
                result = int(round(num))
        except (TypeError, ValueError):
            result = default

    if min_val is not None and result < min_val:
        result = min_val
    if max_val is not None and result > max_val:
        result = max_val
    return result


def _coerce_bool(value, default: bool) -> bool:
    """Safely coerce a value to bool with fallback to default."""
    if isinstance(value, bool):
        return value
    if isinstance(value, (int, float)):
        return bool(value)
    if isinstance(value, str):
        lowered = value.strip().lower()
        if lowered in ("true", "1", "yes", "on"):
            return True
        if lowered in ("false", "0", "no", "off"):
            return False
    return default


def normalize_config(raw: dict) -> dict:
    """Normalize and clamp raw configuration dictionary against DEFAULT_CONFIG."""
    src = raw if isinstance(raw, dict) else {}
    cfg = copy.deepcopy(DEFAULT_CONFIG)

    raw_folder = src.get("save_folder", DEFAULT_CONFIG["save_folder"])
    if isinstance(raw_folder, str):
        cleaned_folder = raw_folder.strip()
        cfg["save_folder"] = os.path.expanduser(cleaned_folder) if cleaned_folder else ""
    else:
        cfg["save_folder"] = ""

    raw_region = src.get("region")
    reg = raw_region if isinstance(raw_region, dict) else {}
    default_reg = DEFAULT_CONFIG["region"]
    cfg["region"] = {
        "x": _coerce_int(reg.get("x"), default_reg["x"]),
        "y": _coerce_int(reg.get("y"), default_reg["y"]),
        "width": _coerce_int(reg.get("width"), default_reg["width"], min_val=10),
        "height": _coerce_int(reg.get("height"), default_reg["height"], min_val=10),
    }

    cfg["interval_sec"] = _coerce_int(
        src.get("interval_sec"),
        DEFAULT_CONFIG["interval_sec"],
        min_val=1,
        max_val=10,
    )
    cfg["max_shots"] = _coerce_int(
        src.get("max_shots"),
        DEFAULT_CONFIG["max_shots"],
        min_val=0,
    )
    cfg["countdown_sec"] = _coerce_int(
        src.get("countdown_sec"),
        DEFAULT_CONFIG["countdown_sec"],
        min_val=0,
        max_val=10,
    )

    raw_pt = src.get("page_turn")
    pt = raw_pt if isinstance(raw_pt, dict) else {}
    default_pt = DEFAULT_CONFIG["page_turn"]

    mode = pt.get("mode", default_pt["mode"])
    if mode not in ("keyboard", "click"):
        mode = default_pt["mode"]

    raw_key_name = pt.get("key_name", default_pt["key_name"])
    if isinstance(raw_key_name, str):
        if raw_key_name == " ":
            key_name = " "
        else:
            key_name = raw_key_name.strip() or default_pt["key_name"]
    else:
        key_name = default_pt["key_name"]

    cfg["page_turn"] = {
        "enabled": _coerce_bool(pt.get("enabled"), default_pt["enabled"]),
        "mode": mode,
        "key_name": key_name,
        "key_code": _coerce_int(pt.get("key_code"), default_pt["key_code"], min_val=0),
        "click_x": _coerce_int(pt.get("click_x"), default_pt["click_x"]),
        "click_y": _coerce_int(pt.get("click_y"), default_pt["click_y"]),
    }

    cfg["sound_enabled"] = _coerce_bool(
        src.get("sound_enabled"),
        DEFAULT_CONFIG["sound_enabled"],
    )

    return cfg


def _load_unlocked() -> dict:
    path = get_config_path()
    if not os.path.isfile(path):
        return normalize_config({})
    try:
        with open(path, "r", encoding="utf-8") as f:
            raw = json.load(f)
    except (OSError, json.JSONDecodeError, ValueError):
        return normalize_config({})
    return normalize_config(raw)


def load_config() -> dict:
    """Load and normalize the persisted configuration from disk."""
    with _CONFIG_LOCK:
        return _load_unlocked()


def save_config(new_data: dict) -> dict:
    """Deep-merge new_data with stored config, normalize, and write atomically."""
    updates = new_data if isinstance(new_data, dict) else {}
    with _CONFIG_LOCK:
        current = _load_unlocked()
        merged = copy.deepcopy(current)

        for key in (
            "save_folder",
            "interval_sec",
            "max_shots",
            "countdown_sec",
            "sound_enabled",
        ):
            if key in updates:
                merged[key] = updates[key]

        if isinstance(updates.get("region"), dict):
            merged["region"] = {**merged["region"], **updates["region"]}

        if isinstance(updates.get("page_turn"), dict):
            merged["page_turn"] = {**merged["page_turn"], **updates["page_turn"]}

        normalized = normalize_config(merged)
        config_path = get_config_path()
        config_dir = os.path.dirname(os.path.abspath(config_path))
        os.makedirs(config_dir, exist_ok=True)

        tmp_path = None
        try:
            with tempfile.NamedTemporaryFile(
                mode="w",
                encoding="utf-8",
                dir=config_dir,
                prefix=".config_",
                suffix=".tmp",
                delete=False,
            ) as tmp_file:
                tmp_path = tmp_file.name
                json.dump(normalized, tmp_file, indent=2, ensure_ascii=False)
                tmp_file.write("\n")
                tmp_file.flush()
                os.fsync(tmp_file.fileno())
            os.replace(tmp_path, config_path)
            tmp_path = None
        finally:
            if tmp_path and os.path.exists(tmp_path):
                try:
                    os.unlink(tmp_path)
                except OSError:
                    pass

        return copy.deepcopy(normalized)
