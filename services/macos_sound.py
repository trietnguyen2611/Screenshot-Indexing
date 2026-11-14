"""Non-blocking macOS shutter sound playback utilities."""

from __future__ import annotations

import os
import subprocess
import sys

MACOS_CAPTURE_SOUND = (
    "/System/Library/Components/CoreAudio.component/Contents/"
    "SharedSupport/SystemSounds/system/Grab.aif"
)


def play_shutter_sound(enabled: bool = True) -> bool:
    """Play the default macOS capture shutter sound without blocking.

    Args:
        enabled: Whether shutter sound playback is enabled by the user.

    Returns:
        True if playback was launched successfully, False otherwise.
    """
    if not enabled or sys.platform != "darwin":
        return False
    if not os.path.exists(MACOS_CAPTURE_SOUND):
        return False

    try:
        subprocess.Popen(
            ["afplay", MACOS_CAPTURE_SOUND],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            start_new_session=True,
        )
        return True
    except Exception:
        return False
