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
- Wi‑Fi setup for new or reset units, without the Gree+ app
- Supports both encryption schemes used by Gree modules: AES‑ECB (older firmware) and AES‑GCM (newer firmware), detected automatically
- Optional launch at login
- `greectl` command-line tool for scripting and debugging

## Requirements

- macOS 14 Sonoma or later
- Xcode 16 or later (Swift 6 toolchain); the Xcode Command Line Tools alone are enough to build
- The AC must be on the same Wi‑Fi network as your Mac. If it isn't connected yet, use **Set up a new AC…** in GreeBar (see below) or the Gree+ app

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

### Connecting a new or reset AC to Wi‑Fi

If the unit isn't on your network yet, open settings (⚙︎) and choose **Set up a new AC…**:

1. Reset the AC's Wi‑Fi: with the unit on, hold **MODE + WIFI** on the remote (on some remotes just **WIFI**) for 5–10 seconds until it beeps. The AC now runs its own Wi‑Fi network for a couple of minutes.
2. Join that network from the macOS Wi‑Fi menu. Its name is 8 hex characters (for example `c6a1b2c3`) and the password is `12345678`. GreeBar detects the AC automatically.
3. Enter your home Wi‑Fi name and password and press **Send**. The password is only sent to the AC and is never stored.
4. Switch your Mac back to your home network. GreeBar finds the AC there and connects.

The same thing from the command line, while joined to the AC's network:

```bash
swift run greectl wifi "MyNetwork" "my-password"
```

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
swift run greectl wifi MyNetwork password # send Wi‑Fi details to a unit in setup mode
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
- **Setup: the AC's network doesn't appear**: repeat the reset; the setup network turns itself off after a few minutes. Some units need the remote's key combo pressed while the unit is off.
- **Setup: the AC never shows up on your network**: the module only supports **2.4 GHz** Wi‑Fi. If your router uses one name for both bands, give the 2.4 GHz band its own name. Check that the password is right, and that the network isn't a guest network or has "client/AP isolation" on.
- Some very new modules only work through the cloud and don't answer local requests at all; those aren't supported.

## Disclaimer

This is an unofficial project and isn't affiliated with or endorsed by Gree Electric Appliances. Use at your own risk.
