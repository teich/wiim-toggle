# wiim-toggle

One Stream Deck key that switches my Mac between two ways of listening:

| Key | Sound comes from | Mac output | Mac volume | WiiM Ultra input |
| --- | --- | --- | --- | --- |
| <img src="icons/display.svg" width="72"> Display | Apple Studio Display speakers | Studio Display Speakers | restored to what it was | Wi-Fi |
| <img src="icons/wiim.svg" width="72"> WiiM | 63" soundbar behind the display, driven by the WiiM | USB SPDIF Audio → WiiM optical in | 100% (loudness is set on the WiiM) | Optical |

The key's icon follows the Mac's actual output, so it stays right even when the output is changed from the menu bar.

## Pieces

- `wiim-toggle`: zsh script that does the switching. `wiim-toggle` flips to the other mode; `wiim-toggle wiim` and `wiim-toggle display` force one. Device names and the WiiM host are at the top.
- `audio-device.swift`: small CoreAudio CLI that lists output devices, sets the default output, and gets or sets one device's volume.
- `plugin/`: native Stream Deck plugin (`net.teich.wiimtoggle`). A key press runs `wiim-toggle`, and the key's state tracks the default output.
- `icons/`: key art as SVG, plus `render.swift`, which rasterizes it with AppKit.

The WiiM is controlled through its local LinkPlay HTTP API (`setPlayerCmd:switchmode:optical|wifi`).

## Install

Requires macOS with the Xcode command-line tools (`swiftc`) and Stream Deck 6.4+.

```bash
./install.sh
```

This installs `wiim-toggle` and `audio-device` into `~/.local/bin`, builds the plugin into Stream Deck's plugin folder, and restarts Stream Deck. Then drag **WiiM › WiiM Toggle** onto a key.

The script keeps the saved display volume and a log in `~/.local/state/wiim-toggle/`. The plugin writes `plugin.log` there too.
