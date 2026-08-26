#!/bin/zsh
set -euo pipefail

PROJECT_DIR="${0:A:h:h}"
HARNESS="$PROJECT_DIR/.build/tests/CoreAudioIntegrationHarness"

mkdir -p "$PROJECT_DIR/.build/tests"
swiftc \
    "$PROJECT_DIR/Sources/MacOSMicPriority/AudioDevice.swift" \
    "$PROJECT_DIR/Sources/MacOSMicPriority/CoreAudioService.swift" \
    "$PROJECT_DIR/Tests/CoreAudioIntegrationHarness.swift" \
    -o "$HARNESS"

if ! pgrep -x MacOSMicPriority >/dev/null; then
    echo "Install and launch macOS Mic Priority before running this test." >&2
    exit 2
fi

result="$($HARNESS switch-alternate)" || {
    status=$?
    if [[ $status -eq 3 ]]; then
        echo "Skipped: at least two connected microphones are required."
        exit 0
    fi
    exit $status
}

original_uid="$(printf '%s\n' "$result" | sed -n 's/^ORIGINAL_UID=//p')"
alternate_name="$(printf '%s\n' "$result" | sed -n 's/^ALTERNATE_NAME=//p')"

restore_original() {
    "$HARNESS" set "$original_uid" >/dev/null 2>&1 || true
}
trap restore_original EXIT

for _ in {1..30}; do
    if [[ "$($HARNESS current-uid)" == "$original_uid" ]]; then
        trap - EXIT
        echo "Passed: macOS Mic Priority restored the preferred microphone after $alternate_name took over."
        exit 0
    fi
    sleep 0.1
done

echo "Failed: the preferred microphone was not restored within three seconds." >&2
exit 1
