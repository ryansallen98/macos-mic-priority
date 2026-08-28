#!/bin/zsh
set -euo pipefail

PROJECT_DIR="${0:A:h:h}"
cd "$PROJECT_DIR"

mkdir -p "$PROJECT_DIR/.build/tests"
swiftc \
    "$PROJECT_DIR/Sources/MacOSMicPriority/AudioDevice.swift" \
    "$PROJECT_DIR/Sources/MacOSMicPriority/PriorityPolicy.swift" \
    "$PROJECT_DIR/Sources/MacOSMicPriority/PreferencesStore.swift" \
    "$PROJECT_DIR/Tests/PriorityPolicyTests.swift" \
    -o "$PROJECT_DIR/.build/tests/PriorityPolicyTests"
"$PROJECT_DIR/.build/tests/PriorityPolicyTests"
"$PROJECT_DIR/scripts/build.sh"
plutil -lint "$PROJECT_DIR/Resources/Info.plist" "$PROJECT_DIR/Resources/PrivacyInfo.xcprivacy"
codesign --verify --deep --strict --verbose=2 "$PROJECT_DIR/build/Mic Priority.app"
