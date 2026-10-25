# Clipstream

> **The hyper-polished, native clipboard manager for macOS Sonoma & Sequoia.**

**Clipstream** is built using **Swift, SwiftUI, and AppKit**. It runs as an unobtrusive menu-bar resident agent with a floating Spotlight-style HUD overlay summoned at `⌘ + ⇧ + V`.

---

## Repository Structure

The codebase is organized into modular subdirectories for easy modification and GitHub management:

```
clipstream/
├── site/                        # Static marketing site (for clipstream.sysnode.cloud)
│   ├── index.html               # Main landing page & interactive HUD simulator
│   ├── styles.css               # Apple HIG macOS design system
│   ├── app.js                   # Interactive HUD playground controller
│   ├── assets/                  # Brand assets (logo, retina app icon, favicon)
│   │   ├── logo.svg             # Vector continuous-curvature app icon
│   │   ├── favicon.svg          # 64x64 vector favicon
│   │   └── app-icon.jpg         # 3D Sonoma/Sequoia style app icon
│   ├── nginx.conf               # Turnkey Nginx server block for VPS
│   └── docker-compose.yml       # 1-command Docker container deployment
│
├── macos/                       # Native macOS App (Swift Package / Xcode)
│   ├── Package.swift            # Swift Package Manager manifest (macOS 14+)
│   └── Sources/Clipstream/
│       ├── Models/
│       │   └── ClipItem.swift   # SwiftData entity with content classifier
│       ├── Services/
│       │   ├── ClipboardManager.swift  # NSPasteboard observer & privacy filter
│       │   ├── HotKeyManager.swift     # Carbon global ⌘ + ⇧ + V hotkey
│       │   └── AutoPaster.swift        # Simulated CGEvent Command+V paste
│       ├── Views/
│       │   ├── ClipstreamView.swift    # 720x460pt 40/60 Split HUD overlay
│       │   └── SyntaxHighlighter.swift # Gutter line numbers & code preview
│       └── App/
│           └── ClipstreamApp.swift     # Menu-bar agent (LSUIElement) lifecycle
│
├── .gitignore
└── README.md
```

## Developing the macOS App

To build or open the macOS application:

```bash
cd macos
open Package.swift # Opens directly in Xcode
# or build via command line:
swift build
```

To package a standalone `.dmg` installer:

```bash
./scripts/package_dmg.sh
```

---

## License

This project is open source and available under the [MIT License](LICENSE).
Copyright © 2026 Hirok Biswas.
