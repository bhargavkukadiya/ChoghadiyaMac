# Security & Privacy Policy

## Supported Versions

We actively maintain and provide security patches for the latest release on currently supported Apple macOS versions:

| Version | Supported | Minimum OS |
| :--- | :--- | :--- |
| **1.0.x (Latest)** | ✅ Yes | macOS 12.0 Monterey or later |

---

## Reporting a Vulnerability

We take the security and privacy of **Choghadiya for Mac** users seriously. If you believe you have discovered a security vulnerability or privacy concern:

1. **Do not disclose publicly:** Please refrain from opening a public GitHub issue.
2. **Private Disclosure:** Please submit your report through [GitHub Private Vulnerability Reporting](https://github.com/bhargavkukadiya/ChoghadiyaMac/security/advisories/new) or contact the project maintainers directly via email.
3. **Information to Include:**
   - Detailed description of the vulnerability and its potential impact.
   - Exact steps to reproduce, proof-of-concept script, or sample payload.
   - macOS version, architecture (Apple Silicon / Intel), and application version tested.
4. **Response Window:** You will receive an initial response acknowledging receipt within 48 hours, followed by regular status updates until a resolution or patch is released.

---

## Architectural Privacy & Sandboxing Principles

**Choghadiya for Mac** is architected from the ground up to respect user privacy and operate under strict security boundaries:

- **Strict App Sandbox:** Both the host application (`ChoghadiyaMacApp`) and the widget extension (`ChoghadiyaWidget`) run strictly inside macOS App Sandboxes (`com.apple.security.app-sandbox: true`).
- **Zero Analytics & Zero Telemetry:** The app contains zero tracking libraries, telemetry SDKs, crash reporters, advertising frameworks, or user analytics.
- **Location Privacy:**
  - Device coordinates are requested through Apple's `CoreLocation` framework after location permission is granted.
  - Geographical coordinates and reverse geocoded city names are stored locally in the shared App Group container (`group.com.choghadiya.mac`) for calculating local solar times and populating widget timelines.
  - Users may opt out of device location by using manual city search. The selected city’s coordinates are still sent to the solar API.
- **Network Disclosure:**
  - ChoghadiyaKit sends latitude, longitude, the requested date, and timezone to `https://api.sunrise-sunset.org/json` to retrieve sunrise/sunset times. These may be device coordinates or those of a manually selected city. The `com.apple.security.network.client` entitlement permits outbound connections; it does not restrict requests to a particular hostname.
  - City-search text and coordinates for reverse geocoding are handled by Apple's `CLGeocoder` services through LocationManager.
  - No personal identifiers, IP logs, or device metadata are captured or correlated by the application.
