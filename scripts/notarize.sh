#!/bin/zsh
set -euo pipefail

PROJECT_DIR="${0:A:h:h}"
APP_PATH="$PROJECT_DIR/build/macOS Mic Priority.app"
NOTARY_PROFILE="${NOTARY_PROFILE:-}"

if [[ -z "$NOTARY_PROFILE" ]]; then
    echo "Set NOTARY_PROFILE to a notarytool Keychain profile name." >&2
    exit 2
fi

if [[ ! -d "$APP_PATH" ]]; then
    echo "Build the Developer ID-signed app before notarizing." >&2
    exit 2
fi

TEMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TEMP_DIR"' EXIT
SUBMISSION_ZIP="$TEMP_DIR/macOS-Mic-Priority-notarization.zip"

ditto -c -k --sequesterRsrc --keepParent "$APP_PATH" "$SUBMISSION_ZIP"
xcrun notarytool submit "$SUBMISSION_ZIP" --keychain-profile "$NOTARY_PROFILE" --wait
xcrun stapler staple "$APP_PATH"
xcrun stapler validate "$APP_PATH"
SKIP_BUILD=1 "$PROJECT_DIR/scripts/package-release.sh"
