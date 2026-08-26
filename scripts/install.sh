#!/bin/zsh
set -euo pipefail

PROJECT_DIR="${0:A:h:h}"
SOURCE_APP="$PROJECT_DIR/build/macOS Mic Priority.app"
DESTINATION_APP="/Applications/macOS Mic Priority.app"

if [[ ! -d "$SOURCE_APP" ]]; then
    "$PROJECT_DIR/scripts/build.sh"
fi

if [[ -d "$DESTINATION_APP" ]]; then
    osascript -e 'tell application "macOS Mic Priority" to quit' >/dev/null 2>&1 || true
    pkill -x MacOSMicPriority >/dev/null 2>&1 || true
    for _ in {1..20}; do
        pgrep -x MacOSMicPriority >/dev/null 2>&1 || break
        sleep 0.1
    done
    mv "$DESTINATION_APP" "$HOME/.Trash/macOS Mic Priority-previous-$(date +%Y%m%d-%H%M%S).app"
fi

ditto "$SOURCE_APP" "$DESTINATION_APP"
open "$DESTINATION_APP"
echo "Installed $DESTINATION_APP"
