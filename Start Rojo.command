#!/bin/bash
# Mac version of "Start Rojo.bat": double-click to download Rojo (first time) and start syncing.
cd "$(dirname "$0")"
ROJO=tools/rojo-7.7.0/rojo
if [ ! -x "$ROJO" ]; then
  echo "Downloading Rojo 7.7.0 - one time only..."
  mkdir -p tools/rojo-7.7.0
  if [ "$(uname -m)" = "arm64" ]; then ARCH=macos-aarch64; else ARCH=macos-x86_64; fi
  curl -sSL -o tools/rojo.zip "https://github.com/rojo-rbx/rojo/releases/download/v7.7.0/rojo-7.7.0-$ARCH.zip" \
    && unzip -oq tools/rojo.zip -d tools/rojo-7.7.0 && rm tools/rojo.zip && chmod +x "$ROJO"
fi
if [ ! -x "$ROJO" ]; then
  echo "Could not download Rojo. Check your internet connection and try again."
  read -n 1
  exit 1
fi
echo
echo "============================================================"
echo "  Rojo is running!"
echo "  In Roblox Studio: open the Rojo plugin and click Connect."
echo "  Keep this window open while you work. Close it to stop."
echo "============================================================"
echo
"$ROJO" serve
