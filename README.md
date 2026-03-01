# Notipon

> A [Mugendesk](https://github.com/Mugendesk/Notipon) Project

Customizable notification popups for macOS — control position, size, opacity, and duration. Plus full notification history with search and export.

![macOS](https://img.shields.io/badge/macOS-13.0+-blue.svg)
![Swift](https://img.shields.io/badge/Swift-5.9-orange.svg)
![License](https://img.shields.io/badge/license-MIT-green.svg)

**[日本語版はこちら](README_JP.md)**

## Why Notipon?

macOS notifications disappear quickly and you can't customize how they look or where they appear. Notipon solves both problems:

1. **Custom Popup Notifications** - Show notifications exactly where you want, sized how you want, for as long as you want
2. **Notification History** - Every notification is saved and searchable, so you never miss anything

Perfect for streamers, multi-monitor setups, and anyone who needs more control over macOS notifications.

## Key Features

### Custom Popup
- **Position** - Place notifications anywhere on screen (X/Y coordinates)
- **Size** - Width 200-1200px, Height 60-400px
- **Opacity** - 30-100% transparency
- **Font Size** - 10-30pt
- **Duration** - 0-30 seconds (0 = persistent until dismissed)
- **App Icon & Image** - Displays app icon and notification images

### Notification History
- **Auto Capture** - Saves all macOS notifications in real-time
- **Search** - Find notifications by title, body, or app name
- **App Filtering** - Filter by specific apps
- **Date Grouping** - Auto-organizes by "Today", "Yesterday", "Month/Day"
- **Export** - JSON/CSV formats

### Menu Bar
- **Hover** - Preview 5 recent notifications
- **Click** - Dropdown with recent 20 notifications
- **Right-click** - Open full history window
- **Unread Badge** - See unread count at a glance

### Other
- **Auto Cleanup** - Remove notifications from Notification Center after saving
- **Exclude Apps** - Prevent specific apps from being captured
- **Auto Launch** - Start at login
- **Retention Control** - 24 hours / 7 days / 30 days / Unlimited

## Screenshots

### Custom Popup
<img width="480" alt="Custom Popup" src="docs/screenshots/popup.png">

### Menu Bar
<img width="300" alt="Menu Bar" src="docs/screenshots/menubar.png">

### History Window
<img width="700" alt="History Window" src="docs/screenshots/history.png">

### Settings
<img width="480" alt="Settings" src="docs/screenshots/settings.png">

## Installation

### Homebrew (Recommended)

```bash
brew tap mugendesk/tap
brew install --cask notipon
```

Quarantine is automatically removed during installation — no extra steps needed.

### Manual Download

1. Download `Notipon.zip` from the [latest release](https://github.com/Mugendesk/Notipon/releases/latest)
2. Extract the ZIP file
3. Move `Notipon.app` to `/Applications` folder
4. Remove quarantine before first launch:
   ```bash
   xattr -cr /Applications/Notipon.app
   ```
5. Launch the app

### Why is this needed?

This app is currently unsigned. macOS blocks unsigned apps by default (Gatekeeper). The `xattr -cr` command removes the quarantine flag so the app can launch normally.

## Required Permissions

### 1. Full Disk Access (Required)

Necessary to read macOS notification database.

**Setup:**
1. `System Settings` → `Privacy & Security` → `Full Disk Access`
2. Click lock icon to authenticate
3. Click `+` button
4. Select `/Applications/Notipon.app`
5. Restart Notipon

### 2. Accessibility (Recommended)

Enables real-time notification detection with lower latency.

**Setup:**
1. `System Settings` → `Privacy & Security` → `Accessibility`
2. Click lock icon to authenticate
3. Click `+` button
4. Select `/Applications/Notipon.app`
5. Restart Notipon

## Technical Specifications

### Architecture
- **Language**: Swift 5.9
- **Frameworks**: SwiftUI, AppKit
- **Database**: SQLite (GRDB.swift)
- **Notification Detection**: Accessibility API (adaptive polling)

### Performance
| Metric | Performance |
|--------|------------|
| Notification detection latency | 50-200ms (adaptive) |
| App filter switching | Instant (in-memory filter) |
| Memory usage | ~50MB |
| CPU usage | 0% idle / ~10% on notification |
| Energy impact | Low |

### Data Storage Location
```
~/Library/Application Support/Notipon/notifications.db
```

## Troubleshooting

### Notifications not being saved

1. Verify **Full Disk Access** permission is granted
2. Restart Notipon
3. Check if database exists:
   ```bash
   ls ~/Library/Application\ Support/Notipon/
   ```

### Slow detection

1. Add **Accessibility** permission
2. Real-time detection will be enabled, reducing latency

### App won't launch

1. Right-click → "Open" to launch
2. Requires macOS 13.0 or later
3. Check Console.app for error logs

## Contributing

Pull requests are welcome!

```bash
git clone https://github.com/Mugendesk/Notipon.git
cd Notipon
open Notipon.xcodeproj
```

### Development Requirements
- Xcode 15.0 or later
- Swift 5.9 or later

## License

MIT License

Copyright (c) 2026 Mugendesk

See [LICENSE](LICENSE) file for details.

## Links

- [GitHub Repository](https://github.com/Mugendesk/Notipon)
- [Report Issues](https://github.com/Mugendesk/Notipon/issues)
- [Latest Release](https://github.com/Mugendesk/Notipon/releases)

---

Made by [Mugendesk](https://github.com/Mugendesk/Notipon)
