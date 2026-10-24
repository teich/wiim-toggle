#!/bin/zsh
# Build and install everything, then restart Stream Deck so it loads the plugin:
#   ~/.local/bin/wiim-toggle, ~/.local/bin/audio-device, and the WiiM Toggle plugin.
set -euo pipefail
cd "${0:A:h}"

BIN="$HOME/.local/bin"
PLUGIN="$HOME/Library/Application Support/com.elgato.StreamDeck/Plugins/net.teich.wiimtoggle.sdPlugin"
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

mkdir -p "$BIN" "$PLUGIN"
install -m 755 wiim-toggle "$BIN/wiim-toggle"
swiftc -O -o "$BIN/audio-device" audio-device.swift

swiftc -O -o "$PLUGIN/wiimtoggle" plugin/main.swift
cp plugin/manifest.json "$PLUGIN/"

# Key images: 72px and 144px (@2x) for each state.
swiftc -O -o "$TMP/render" icons/render.swift
for icon in display wiim; do
  "$TMP/render" "icons/$icon.svg" "$PLUGIN/$icon.png" 72
  "$TMP/render" "icons/$icon.svg" "$PLUGIN/$icon@2x.png" 144
done

if pgrep -x "Stream Deck" >/dev/null; then
  # Stream Deck refuses an AppleScript quit; SIGTERM shuts it down cleanly.
  pkill -TERM -x "Stream Deck"
  while pgrep -x "Stream Deck" >/dev/null; do perl -e 'select(undef, undef, undef, 0.25)'; done
  open -a "Elgato Stream Deck"
fi
echo "Installed. In Stream Deck, drag WiiM > WiiM Toggle onto a key if it isn't on one yet."
