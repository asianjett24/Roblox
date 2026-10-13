#!/bin/bash
# Mac version of "Start Rojo.bat": double-click to download Rojo (first time) and start syncing.
cd "$(dirname "$0")"
if [ ! -x tools/rojo ]; then
  echo "Downloading Rojo - one time only..."
  mkdir -p tools
  if [ "$(uname -m)" = "arm64" ]; then ARCH=macos-aarch64; else ARCH=macos-x86_64; fi
  curl -sSL -o tools/rojo.zip "https://github.com/rojo-rbx/rojo/releases/download/v7.4.4/rojo-7.4.4-$ARCH.zip" \
    && unzip -oq tools/rojo.zip -d tools && rm tools/rojo.zip && chmod +x tools/rojo
fi
if [ ! -x tools/rojo ]; then
  echo "Could not download Rojo. Check your internet connection and try again."
  read -n 1
  exit 1
fi
tools/rojo plugin install
echo
echo "============================================================"
echo "  Rojo is running!"
echo "  In Roblox Studio: Plugins tab, click Rojo, then Connect."
echo "  Keep this window open while you work. Close it to stop."
echo "============================================================"
echo
tools/rojo serve
