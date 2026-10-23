#!/bin/zsh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP_NAME="新天堂电影院·导演工作台"
VERSION="0.9.0"
APP_DIR="$ROOT/dist-native/$VERSION/$APP_NAME.app"
CONTENTS="$APP_DIR/Contents"
MACOS="$CONTENTS/MacOS"
RESOURCES="$CONTENTS/Resources"

mkdir -p "$MACOS" "$RESOURCES"

xcrun swiftc \
  -parse-as-library \
  -target arm64-apple-macos13.0 \
  -framework AppKit \
  -framework AVFoundation \
  -framework Security \
  -framework Vision \
  -framework WebKit \
  "$ROOT/macos/AITranslationCredentialStore.swift" \
  "$ROOT/macos/DeepSeekSubtitleTranslator.swift" \
  "$ROOT/macos/CloudSubtitleExtractor.swift" \
  "$ROOT/macos/BackupManager.swift" \
  "$ROOT/macos/FramePackageExporter.swift" \
  "$ROOT/macos/ExcelExporter.swift" \
  "$ROOT/macos/ShotDetector.swift" \
  "$ROOT/macos/SubtitleReader.swift" \
  "$ROOT/macos/RepresentativeFrameGenerator.swift" \
  "$ROOT/macos/BasicSceneAnalyzer.swift" \
  "$ROOT/macos/App.swift" \
  -o "$MACOS/DirectorWorkbench"

cp "$ROOT/macos/Info.plist" "$CONTENTS/Info.plist"
/usr/bin/ditto "$ROOT/macos/Assets/AppIcon.icns" "$RESOURCES/AppIcon.icns"
if [[ -x "$ROOT/macos/Tools/ffmpeg" ]]; then
  /usr/bin/ditto "$ROOT/macos/Tools/ffmpeg" "$RESOURCES/ffmpeg"
  chmod u+x "$RESOURCES/ffmpeg"
fi
/usr/bin/ditto "$ROOT/preview" "$RESOURCES/preview"
/usr/bin/ditto "$ROOT/report" "$RESOURCES/report"
# User exports are local data and must never enter a distributable app bundle.

codesign --force --deep --sign - "$APP_DIR"
print "$APP_DIR"
