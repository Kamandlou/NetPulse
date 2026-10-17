# NetPulse — Native macOS Internet Connectivity Monitor

<p align="center">
  <img src="Resources/AppIcon.icns" width="128" height="128" alt="NetPulse Icon" />
  <br>
  <strong>A lightweight, privacy-friendly native macOS menu bar application that continuously monitors real internet connectivity.</strong>
  <br>
  <em>Built with Swift 6, SwiftUI, Network.framework, and Swift Charts for macOS 14 Sonoma and newer.</em>
</p>

---

## Highlights

- **Real Internet Verification (Not Just Wi-Fi)**: Differentiates between local Wi-Fi association and genuine global internet reachability using lightweight active HTTP/HTTPS endpoint probes.
- **Debouncing & Hysteresis**: State machine requires configurable consecutive checks (default: 2 failures to mark Offline, 2 successes to mark Online) to eliminate false alerts from momentary packet drops.
- **Native macOS Menu Bar Agent**: Runs quietly in the status bar with color-coded SF Symbols (`Green` = Online, `Red` = Offline, `Orange` = Unstable, `Gray` = Checking) and optional live latency readout.
- **Smart System Notifications**: Uses `UNUserNotificationCenter` with independent toggles for disconnection and reconnection alerts, sound control, cooldowns, and downtime duration reporting.
- **Sleep & Wake Aware**: Observes `NSWorkspace` sleep notifications. Time spent asleep is automatically deducted so your Mac being asleep is never classified as an internet outage.
- **Single-Instance Enforcement**: Integrated `SingleInstanceGuard` uses `NSRunningApplication` and atomic kernel-level POSIX file locks to guarantee that only one instance of NetPulse can ever run simultaneously on the Mac.
- **Local Outage History & Swift Charts**: Tracks confirmed outages locally with duration, start/end timestamps, interface type, and technical failure reasons. Includes interactive Swift Charts and CSV/JSON export.
- **Zero External Dependencies**: 100% native Apple frameworks (`Network`, `NWPathMonitor`, `URLSession`, `UserNotifications`, `ServiceManagement`, `Charts`, `AppKit`, `SwiftUI`).
- **Bilingual & RTL Ready**: Complete native localization for **English** and **Persian (فارسی)** with proper Right-to-Left (RTL) layout support.

---

## System Requirements

- **Operating System**: macOS 14.0 (Sonoma) or newer (macOS 14, macOS 15 Sequoia, and newer).
- **Architecture**: Universal (Apple Silicon `arm64` and Intel `x86_64`).
- **Dependencies**: None. Pure native Apple frameworks.

---

## Quick Start & Build Instructions

### 1. Build and Run via Swift Package Manager (Terminal)

```bash
# Build the project (debug mode)
swift build

# Run NetPulse directly
swift run NetPulse
```

### 2. Run the Automated Test Suite

```bash
swift test
```
All 15 tests across 6 test suites will execute and verify state machine transitions, hysteresis, notification deduplication, sleep/wake downtime deduction, and persistence.

### 3. Build the Runnable `.app`, ZIP, and DMG

We provide an automated build script `scripts/build_app.sh`:

```bash
bash scripts/build_app.sh
```

This compiles a release binary, constructs the `NetPulse.app` bundle, embeds the `Info.plist`, `AppIcon.icns`, and entitlements, applies ad-hoc code signing, and creates:
- `build/NetPulse.app` (Runnable macOS application)
- `build/NetPulse-1.0.0.zip` (Compressed distribution archive)
- `build/NetPulse-1.0.0.dmg` (macOS Drag-and-Drop installer disk image)

### 4. Open in Xcode

Double-click `NetPulse.xcodeproj` or run:

```bash
open NetPulse.xcodeproj
```

Select the **NetPulse** scheme and press **⌘R** to build and run.

---

## Architecture & Detection Strategy

NetPulse uses a **2-Layer Hybrid Monitoring Strategy**:

```
 ┌────────────────────────────────────────────────────────┐
 │ Layer 1: System Path Monitor (NWPathMonitor)           │
 │ - Monitors interface state (Wi-Fi, Ethernet, None)     │
 │ - Immediate check triggered on network path change     │
 └─────────────────────────┬──────────────────────────────┘
                           │
                           ▼
 ┌────────────────────────────────────────────────────────┐
 │ Layer 2: Real Internet Prober (URLSession)             │
 │ - Lightweight GET requests to configurable endpoints   │
 │   • Apple Captive Portal (HTTP 200 + "Success")       │
 │   • Google Generate 204 (HTTP 204)                     │
 │   • Cloudflare Edge Trace (HTTP 200 + "fl=")           │
 │ - Evaluates latency, HTTP status, and body tokens      │
 └─────────────────────────┬──────────────────────────────┘
                           │
                           ▼
 ┌────────────────────────────────────────────────────────┐
 │ Authoritative State Machine (Hysteresis & Debounce)    │
 │ - Consecutive failures threshold: default 2            │
 │ - Consecutive successes threshold: default 2           │
 │ - States: Online, Offline, Checking, Unstable, Unknown │
 └─────────────┬──────────────────────────┬───────────────┘
               │                          │
               ▼                          ▼
    ┌──────────────────────┐   ┌──────────────────────────┐
    │ Notification Manager │   │   Outage History Store   │
    │ - UNUserNotification │   │ - Atomic JSON file store │
    │ - Downtime duration  │   │ - Deducts sleep intervals│
    │ - Rate-limit cooldown│   │ - CSV / JSON Export      │
    └──────────────────────┘   └──────────────────────────┘
```

See [ARCHITECTURE.md](ARCHITECTURE.md) for full technical documentation.

---

## Settings & Preferences

Open the Settings window from the menu bar popup:

1. **General**:
   - **Launch at Login**: Integrates with Apple's `SMAppService.mainApp` API.
   - **Start Monitoring Automatically**: Begins connectivity checks on app launch.
   - **Show Dock Icon**: Toggle between pure Menu Bar Accessory (`LSUIElement`) mode and standard Dock icon mode.
   - **Show Latency in Menu Bar**: Displays live ping (e.g. `● 24ms`) next to the menu bar icon.
   - **Language**: Switch between English and فارسی instantly without restarting.
   - **Appearance**: Follow System, Light, or Dark mode.

2. **Notifications**:
   - Master notifications toggle.
   - Independent toggles for Disconnect and Reconnect alerts.
   - Notification sound toggle.
   - Include downtime duration in reconnection notification (e.g. `Downtime: 2m 35s`).
   - Minimum outage duration filter (prevents spam on 1-second blips).
   - Cooldown window between notifications.

3. **Connectivity**:
   - Check interval: `2s`, `5s`, `10s`, `15s`, `30s`, `60s`.
   - Request timeout: `1s` to `10s`.
   - Consecutive failures threshold (1 to 5).
   - Consecutive successes threshold (1 to 5).
   - Checking strategy presets: **Balanced**, **Fast & Responsive**, **Battery Saving**.
   - Editable Endpoint Manager: Add custom URLs, configure expected status codes and body tokens, toggle endpoints, and test endpoints live with latency feedback.

4. **History & Privacy**:
   - Enable/disable local history recording.
   - Retention policy: 7 days, 30 days, 90 days, or Never delete.
   - Clear all history (with confirmation).
   - Export history as **CSV** or **JSON**.

5. **About**:
   - Application version, build number, developer information, and architecture details.

---

## Automated Tests

NetPulse includes 15 automated unit and integration tests covering:
- State machine initial state and transition rules
- Hysteresis thresholds and rapid fluctuation filtering
- Reconnection duration calculations
- Outage persistence and atomic file reloads
- Time window calculation spanning midnight
- Sleep/wake duration deduction
- Strategy switching and interval updates
- End-to-end monitor transitions and notification delivery

Run them at any time with:
```bash
swift test
```

---

## Packaging & Distribution

To create a release DMG for distribution:

```bash
bash scripts/build_app.sh
```

Output files in `build/`:
- `NetPulse.app`: Ad-hoc codesigned application bundle.
- `NetPulse-1.0.0.dmg`: Compressed DMG installer with `/Applications` symlink.
- `NetPulse-1.0.0.zip`: Standard ZIP archive.

### Optional Developer ID Signing & Notarization
If signing with a paid Apple Developer certificate:
```bash
codesign --force --deep --sign "Developer ID Application: Your Name (TEAMID)" \
    --options runtime \
    --entitlements Resources/NetPulse.entitlements \
    build/NetPulse.app

xcrun notarytool submit build/NetPulse-1.0.0.dmg \
    --keychain-profile "AC_PASSWORD" --wait
```

---

## License

Copyright © 2026 Amir Hossein Kamandlou. All rights reserved.
Licensed under the MIT License.
