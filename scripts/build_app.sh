#!/usr/bin/env bash
# Baut "FuFF Convert.app" (Universal: Apple Silicon + Intel) inkl. FFmpeg.
# Läuft auf GitHub Actions (macOS). Lokal geht es genauso, wenn Xcode installiert ist.
set -euo pipefail

cd "$(dirname "$0")/.."
APP_NAME="FuFF Convert"
BUILD_DIR="build"
APP="$BUILD_DIR/$APP_NAME.app"
VERSION="${VERSION:-0.1.0}"

rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR/ffmpeg"

echo "==> Swift-Code kompilieren"
swift build -c release --arch arm64 --arch x86_64
BIN="$(swift build -c release --arch arm64 --arch x86_64 --show-bin-path)/ConvertAnything"

echo "==> FFmpeg herunterladen (statische Builds von ffmpeg.martin-riedl.de)"
for tool in ffmpeg ffprobe; do
  for arch in arm64 amd64; do
    curl -fsSL --retry 4 -o "$BUILD_DIR/ffmpeg/$tool-$arch.zip" \
      "https://ffmpeg.martin-riedl.de/redirect/latest/macos/$arch/release/$tool.zip"
    mkdir -p "$BUILD_DIR/ffmpeg/$arch"
    unzip -o -q "$BUILD_DIR/ffmpeg/$tool-$arch.zip" -d "$BUILD_DIR/ffmpeg/$arch"
  done
  lipo -create "$BUILD_DIR/ffmpeg/arm64/$tool" "$BUILD_DIR/ffmpeg/amd64/$tool" -output "$BUILD_DIR/ffmpeg/$tool"
  chmod +x "$BUILD_DIR/ffmpeg/$tool"
done

echo "==> App-Paket zusammenbauen"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/ConvertAnything"
cp "$BUILD_DIR/ffmpeg/ffmpeg" "$BUILD_DIR/ffmpeg/ffprobe" "$APP/Contents/Resources/"
sed "s/__VERSION__/$VERSION/g" Resources/Info.plist > "$APP/Contents/Info.plist"
echo "==> App-Icon erzeugen"
ICONSET="$BUILD_DIR/AppIcon.iconset"
mkdir -p "$ICONSET"
for s in 16 32 128 256 512; do
  sips -z $s $s Resources/AppIcon.png --out "$ICONSET/icon_${s}x${s}.png" >/dev/null
  sips -z $((s*2)) $((s*2)) Resources/AppIcon.png --out "$ICONSET/icon_${s}x${s}@2x.png" >/dev/null
done
iconutil -c icns "$ICONSET" -o "$APP/Contents/Resources/AppIcon.icns"

echo "==> Ad-hoc signieren (nötig, damit es auf Apple Silicon startet)"
codesign --force --sign - "$APP/Contents/Resources/ffmpeg"
codesign --force --sign - "$APP/Contents/Resources/ffprobe"
codesign --force --sign - "$APP"

echo "==> Kurztest"
"$APP/Contents/Resources/ffmpeg" -hide_banner -encoders | grep -E "libmp3lame|prores_ks|h264_videotoolbox|hevc_videotoolbox|dnxhd" || true

echo "==> ZIP erstellen"
ditto -c -k --keepParent "$APP" "$BUILD_DIR/FuFF-Convert.zip"
echo "Fertig: $BUILD_DIR/FuFF-Convert.zip"
