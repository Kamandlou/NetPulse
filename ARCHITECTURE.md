# NetPulse Technical Architecture Document

## Overview

**NetPulse** is a native macOS menu bar utility engineered in Swift 6 and SwiftUI for macOS 14 Sonoma and newer. It solves a ubiquitous networking problem: **Wi-Fi association does not guarantee real internet access.**

NetPulse implements a privacy-first, zero-external-dependency, battery-efficient monitoring engine designed according to Apple's Human Interface Guidelines.

---

## 1. System Components & Architecture

The application adopts the **Model-View-ViewModel (MVVM)** pattern with strict separation between system networking, business state, persistence, and SwiftUI presentation.

```
┌────────────────────────────────────────────────────────────────────────┐
│                             PRESENTATION                               │
│                                                                        │
│   ┌────────────────────┐   ┌─────────────────┐   ┌─────────────────┐   │
│   │  MenuBarPopupView  │   │  SettingsView   │   │   HistoryView   │   │
│   │    (Status & UI)   │   │   (Preferences) │   │ (Charts & Table)│   │
│   └─────────▲──────────┘   └────────▲────────┘   └────────▲────────┘   │
│             │                       │                     │            │
│   ┌─────────┴──────────┐   ┌────────┴────────┐   ┌────────┴────────┐   │
│   │MenuBarPopupViewModel   SettingsViewModel │   │ HistoryViewModel│   │
│   └─────────▲──────────┘   └────────▲────────┘   └────────▲────────┘   │
└─────────────┼───────────────────────┼─────────────────────┼────────────┘
              │                       │                     │
┌─────────────┼───────────────────────┼─────────────────────┼────────────┐
│             ▼                       ▼                     ▼   CORE     │
│  ┌──────────────────────────────────────────────────────────────┐      │
│  │                     ConnectivityMonitor                      │      │
│  │  - Single authoritative coordinator (@MainActor)             │      │
│  │  - Polling timer + adaptive immediate path change trigger   │      │
│  │  - Publishes state, interface, latency, and uptime           │      │
│  └──────┬───────────────────┬──────────────────────┬────────────┘      │
│         │                   │                      │                   │
│         ▼                   ▼                      ▼                   │
│  ┌──────────────┐    ┌──────────────┐       ┌──────────────┐           │
│  │ Connectivity │    │ Connectivity │       │ OutageHistory│           │
│  │ StateMachine │    │    Probe     │       │    Store     │           │
│  │ (Hysteresis) │    │ (URLSession) │       │ (JSON Files) │           │
│  └──────────────┘    └──────┬───────┘       └──────┬───────┘           │
│                             │                      │                   │
│                             ▼                      ▼                   │
│                      ┌──────────────┐       ┌──────────────┐           │
│                      │Network.frame-│       │Statistics-   │           │
│                      │work / NWPath │       │Service       │           │
│                      └──────────────┘       └──────────────┘           │
└────────────────────────────────────────────────────────────────────────┘
```

---

## 2. Connectivity Detection Engine

### Layer 1: Network Path Observation (`NWPathMonitor`)
- Monitors hardware interfaces using Apple's `Network.framework`.
- Distinguishes between:
  - Wi-Fi (`.wifi`)
  - Wired Ethernet (`.wiredEthernet`)
  - Cellular hotspot / interface (`.cellular`)
  - Other / Loopback / VPN (`.other`)
  - No interface (`.none`)
- Observes path satisfaction (`path.status == .satisfied`).
- Retrieves active Wi-Fi SSID using `CoreWLAN.CWWiFiClient` safely.
- **Adaptive Triggering**: When an interface change occurs (e.g., unplugging Ethernet or switching Wi-Fi networks), an immediate connectivity verification is triggered rather than waiting for the next periodic check interval. Rapid path changes are debounced to prevent request floods.

### Layer 2: Active Internet Probing (`ConnectivityProbing`)
- Being connected to a router or Wi-Fi hotspot with a captive portal or offline ISP does not mean internet works.
- NetPulse sends lightweight asynchronous HTTP/HTTPS requests with an ephemeral `URLSessionConfiguration`:
  - `requestCachePolicy = .reloadIgnoringLocalAndRemoteCacheData`
  - `urlCache = nil` (no disk or memory cache writes)
  - `waitsForConnectivity = false` (fails fast on timeout)
  - `httpShouldSetCookies = false` (privacy-friendly, no cookie tracking)
- Default Endpoints:
  1. `https://www.apple.com/library/test/success.html` (Apple Captive Portal check; verifies status 200 and `"Success"` token).
  2. `https://www.google.com/generate_204` (Google check; verifies HTTP 204 No Content).
  3. `https://cloudflare.com/cdn-cgi/trace` (Cloudflare edge trace; verifies status 200 and `"fl="` token).
- Endpoint-specific validation:
  - HTTP Status Code validation (e.g. 200, 204).
  - Body token substring validation (e.g. `"Success"`, `"fl="`).
  - Distinguishes technical failure reasons:
    - DNS resolution failure (`NSURLErrorCannotFindHost`, `NSURLErrorDNSLookupFailed`)
    - Request timeout (`NSURLErrorTimedOut`)
    - TLS/SSL handshake error (`NSURLErrorSecureConnectionFailed`, `NSURLErrorServerCertificateUntrusted`)
    - Captive portal redirection (HTTP 301, 302, 307 or body token mismatch)
    - Host unreachable (`NSURLErrorCannotConnectToHost`)

---

## 3. Finite State Machine with Hysteresis & Debouncing

To avoid notification spam during transient packet drops or cellular handover, the connection state is mediated by `ConnectivityStateMachine`:

### States:
- `.online`: Real internet connection confirmed.
- `.offline`: Loss of internet connectivity confirmed.
- `.checking`: Probe request actively in-flight.
- `.unstable`: Connectivity fluctuating or transitioning before confirmation thresholds are satisfied.
- `.unknown`: Initial uninitialized state before the first probe sequence.

### Hysteresis Rules:
- Requires $N$ consecutive failures (default: 2) to declare the connection **Offline**.
- Requires $M$ consecutive successes (default: 2) to declare the connection **Online**.
- Generation Token Counter: Outdated asynchronous responses from cancelled or slow requests are discarded, preventing race conditions.
- **Initial Launch Suppression**: On application startup, the initial confirmed state is established silently without firing a misleading "Internet Connected" notification.

---

## 4. Notifications & User Experience

- Uses `UserNotifications.framework` (`UNUserNotificationCenter`).
- Independent configuration:
  - Disconnection alerts
  - Reconnection alerts (includes downtime duration: e.g. `Downtime: 1m 42s`)
  - Notification sounds
  - Minimum outage threshold (e.g. only notify if outage lasts $\ge 5$ seconds)
  - Notification cooldown timer
- Does not spam duplicate alerts for the same confirmed transition.

---

## 5. Sleep & Wake Handling

- NetPulse registers for `NSWorkspace.willSleepNotification` and `NSWorkspace.didWakeNotification`.
- When the Mac goes to sleep:
  - The check timer is immediately suspended.
  - The sleep start timestamp is recorded.
- When the Mac wakes:
  - The elapsed sleep interval is computed and deducted from any ongoing outage record.
  - State machine counters are reset.
  - An immediate probe is scheduled to verify network availability post-wake.
  - **Guarantee**: Time spent asleep is **never** counted as internet downtime.

---

## 6. Local Persistence & Statistics

- **Outage Storage**: Persisted locally at `~/Library/Application Support/ir.kamandlou.NetPulse/outages.json` via atomic writes (`Data.write(to:options: .atomic)`).
- **Outage Model**:
  - `id: UUID`
  - `startDate: Date`
  - `endDate: Date?` (nil for ongoing outage)
  - `duration: TimeInterval` (live-updating during active outage)
  - `interfaceType: NetworkInterfaceType`
  - `technicalReason: String?`
- **Midnight Crossing**: `StatisticsService.overlapDuration` calculates exact overlapping seconds inside any arbitrary time interval (Today, Last 7 Days, Last 30 Days). An outage spanning midnight is correctly distributed to each day.
- **Interactive Charts**: Rendered with Apple's `Charts` framework.
- **Data Export**: Built-in CSV and JSON exporters for networking audits.

---

## 7. Performance & Battery Efficiency

- **Zero Polling When Paused**: Pausing suspends all timers and network calls.
- **Ephemeral Requests**: Ephemeral URLSession without cache writes avoids disk thrashing.
- **Minimal Idle Footprint**: Memory usage is $< 25$ MB and idle CPU is $\approx 0.0\%$.
- **Battery Saving Strategy**: Increases polling interval to 15 seconds to minimize system wakeups.
- **Thread Safety**: UI-bound services are isolated to `@MainActor`, while network probes and path monitoring run on dedicated background dispatch queues.
- **Single-Instance Mutex**: `SingleInstanceGuard` uses `NSRunningApplication.runningApplications(withBundleIdentifier:)` and atomic POSIX `flock` locks (`LOCK_EX | LOCK_NB`) on `~tmp/ir.kamandlou.NetPulse.lock`. If a user attempts to launch a second instance, the guard brings the running instance to the front and immediately exits (`exit(0)`), completely preventing duplicate menu bar icons or overlapping pollers.

---

## 8. Localization & RTL

- Fully localized for **English** and **Persian (فارسی)**.
- In-app live language switching without application restart.
- Natural Persian phrasing conforming to Persian networking terminology.
- Supports native right-to-left layout direction via SwiftUI `.environment(\.layoutDirection, settings.language.layoutDirection)`.
