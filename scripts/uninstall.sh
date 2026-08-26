#!/bin/zsh
set -euo pipefail

APP_PATH="/Applications/macOS Mic Priority.app"
EXECUTABLE="$APP_PATH/Contents/MacOS/MacOSMicPriority"

if [[ -x "$EXECUTABLE" ]]; then
    "$EXECUTABLE" --unregister-login-item || true
fi

pkill -x MacOSMicPriority >/dev/null 2>&1 || true

if [[ -d "$APP_PATH" ]]; then
    destination="$HOME/.Trash/macOS Mic Priority.app"
    if [[ -e "$destination" ]]; then
        destination="$HOME/.Trash/macOS Mic Priority-$(date +%Y%m%d-%H%M%S).app"
    fi
    mv "$APP_PATH" "$destination"
    echo "Moved macOS Mic Priority to $destination"
else
    echo "macOS Mic Priority is not installed."
fi

echo "Preferences were retained. Remove dev.rallen.macos-mic-priority from UserDefaults to reset them."
