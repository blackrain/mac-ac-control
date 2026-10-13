# GreeBar

A small macOS menu bar app for controlling **Gree** air conditioners (and rebrands that use the Gree Wi‑Fi module and the Gree+ / EWPE Smart apps) directly over your local network.

No cloud account, no Gree servers: the app talks to the unit's Wi‑Fi module on UDP port 7000, the same local protocol used by Home Assistant's Gree integration.

## Features

- Lives in the menu bar; the icon shows the current mode and set temperature while the AC is on
- Power, target temperature (16–30 °C), mode (auto / cool / dry / fan / heat), fan speed (auto, 1–5)
- Vertical and horizontal swing, including fixed louver positions
- Turbo, quiet, sleep, display light, health, X‑Fan, fresh air and energy saving toggles
- Indoor room temperature (if the unit reports it)
- Automatic discovery on the LAN, or connect by IP address
- Supports both encryption schemes used by Gree modules: AES‑ECB (older firmware) and AES‑GCM (newer firmware), detected automatically
- Optional launch at login
- `greectl` command-line tool for scripting and debugging

## Requirements

- macOS 14 Sonoma or later
- Xcode 16 or later (Swift 6 toolchain); the Xcode Command Line Tools alone are enough to build
- The AC must already be connected to your Wi‑Fi (set it up once with the Gree+ app) and be on the same network as your Mac

## Building the app

Clone the repo and run the build script:

```bash
git clone https://github.com/<your-username>/ac-mac.git
cd ac-mac
./scripts/build-app.sh
```

This builds a release binary with Swift Package Manager, puts it in an app bundle at `build/GreeBar.app`, and ad‑hoc signs it. Start it with:

```bash
open build/GreeBar.app
```

To build and copy the app to `/Applications` in one step:

```bash
./scripts/build-app.sh --install
```

### First launch

1. macOS asks whether GreeBar may find devices on your **local network**. Allow it; without this the app can't reach the AC. If you dismissed the prompt, turn it back on in **System Settings → Privacy & Security → Local Network**.
2. GreeBar scans the network and connects to the first AC it finds. If you have several units, or the scan finds nothing, open settings with the ⚙︎ button and pick a unit or enter its IP address.

Because the app is ad‑hoc signed rather than notarized, a copy downloaded from somewhere else may be blocked by Gatekeeper. Building it yourself avoids that.

### Opening in Xcode

`Package.swift` opens directly in Xcode (`xed .`), which is handy for editing and SwiftUI previews. Run the menu bar app through `scripts/build-app.sh`, though: the Local Network permission and menu bar-only behaviour need the proper app bundle and `Info.plist` that the script creates.

## Command-line tool

`greectl` uses the same code as the app:

```bash
swift run greectl scan                    # find units on the LAN
swift run greectl scan 192.168.1.50       # query one IP directly
swift run greectl status                  # print all values of the first unit found
swift run greectl status 1a2b             # select a unit by MAC suffix (or pass an IP)
swift run greectl set Pow=1 Mod=1 SetTem=23 --device 1a2b
```

Commonly used values:

| Column | Meaning | Values |
|---|---|---|
| `Pow` | Power | 0 off, 1 on |
| `Mod` | Mode | 0 auto, 1 cool, 2 dry, 3 fan, 4 heat |
| `SetTem` | Target temperature | 16–30 (°C) |
| `WdSpd` | Fan speed | 0 auto, 1–5 |
| `SwUpDn` | Vertical swing | 0 off, 1 full, 2–6 fixed, 7–11 partial swing |
| `SwingLfRig` | Horizontal swing | 0 off, 1 full, 2–6 fixed |
| `Tur` / `Quiet` | Turbo / quiet | 0, 1 |
| `Lig` | Display light | 0, 1 |
| `Health` / `Blo` / `Air` / `SvSt` | Health, X‑Fan, fresh air, energy saving | 0, 1 |
| `SwhSlp` + `SlpMod` | Sleep | 0, 1 |
| `TemSen` | Room temperature (read only) | usually °C + 40 |

Not every unit supports every feature; unsupported values are ignored by the AC.

## Tests

```bash
swift test
```

## Project layout

```
Sources/GreeKit/    Protocol library: encryption, UDP sockets, discovery, GreeDevice actor, DeviceState
Sources/GreeBar/    SwiftUI MenuBarExtra app
Sources/greectl/    Command-line tool
Tests/              Unit tests for crypto, discovery parsing and state mapping
Resources/          Info.plist for the app bundle
scripts/            build-app.sh
```

## Troubleshooting

- **No AC found**: check the Local Network permission, that the Mac and the AC are on the same subnet, and that the AC shows as online in Gree+. Try `swift run greectl scan <ac-ip>`; your router's client list will show the unit's IP (Gree modules have MAC addresses starting with `50:2c:c6` or similar).
- **"The AC did not respond"**: the unit may have a new IP address. GreeBar rescans automatically; you can also press Scan in settings.
- Some very new modules only work through the cloud and don't answer local requests at all; those aren't supported.

## Disclaimer

This is an unofficial project and isn't affiliated with or endorsed by Gree Electric Appliances. Use at your own risk.
