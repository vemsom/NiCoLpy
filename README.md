# NiCoLpy

A lightweight clipboard manager for macOS. Copy multiple things, then pick which one to paste — right where your cursor is.

NiCoLpy lives in the menu bar, keeps a history of what you copy (text and images), and lets you paste any previous clip with a keystroke or a click.

## Features

- **Menu bar app** — unobtrusive, no Dock clutter
- **Global hotkey** — `⌘⇧V` opens the picker at your text insertion point (falls back to the mouse)
- **Text & image history** with automatic de-duplication
- **Keyboard-first picking**
  - `↑` / `↓` to navigate, `↩` to paste
  - `1`–`9` to paste a recent clip directly
  - `esc` to dismiss
- **Pinned favorites** — keep important clips from being cleared
- **Launch at login** — optional, via the modern `SMAppService` API
- **Right-click the menu bar icon** for Settings, Launch at Login, and Quit

## Requirements

- macOS 13 (Ventura) or later
- Swift toolchain (Command Line Tools is enough — full Xcode not required)

## Build & run

```bash
./build-app.sh            # debug build → build/NiCoLpy.app
./build-app.sh release    # optimized build
open build/NiCoLpy.app
```

On first launch, grant **Accessibility** permission when prompted
(System Settings → Privacy & Security → Accessibility) so the auto-paste
(`⌘V` simulation) works. Without it, the chosen clip is still placed on the
clipboard so you can paste manually.

## How it works

- `ClipboardMonitor` polls `NSPasteboard` for changes. Text is always preferred
  over images, because macOS will otherwise render rich text (RTF/HTML) into an
  image — which would create false duplicates on every copy.
- `ClipStore` holds the history, handles de-duplication, the unpinned limit, and
  pinned ordering.
- `CaretLocator` uses the Accessibility API to find the caret position so the
  picker appears next to where you're typing.
- `PickerPanel` is a floating, non-activating `NSPanel` that takes keyboard
  focus without stealing activation from the app you're working in.
- `Paster` writes the selected clip to the pasteboard and synthesizes `⌘V`.

## Project layout

```
NiCoLpy/
├── Package.swift
├── Info.plist
├── build-app.sh            # builds + packages + ad-hoc signs the .app
├── make-icon.swift         # generates AppIcon.icns
└── Sources/NiCoLpy/
    ├── NiCoLpyApp.swift        # entry point + Settings scene
    ├── AppDelegate.swift       # status item, menu, lifecycle
    ├── ClipItem.swift          # data model (text/image, pin, timestamp)
    ├── ClipboardMonitor.swift  # pasteboard polling
    ├── ClipStore.swift         # history, dedup, limit, pinning
    ├── Paster.swift            # write to pasteboard + simulate ⌘V
    ├── HotKeyCenter.swift      # global ⌘⇧V (Carbon)
    ├── CaretLocator.swift      # caret position via Accessibility
    ├── PickerPanel.swift       # floating picker window
    ├── PickerController.swift  # selection + keyboard commands
    ├── KeyCaptureView.swift    # key handling
    ├── HistoryView.swift       # the clip list UI
    ├── SettingsView.swift      # Settings window
    └── LaunchAtLogin.swift     # SMAppService login item
```

## License

MIT
