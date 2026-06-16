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

## Installation (step by step)

NiCoLpy isn't on the App Store — you build it once on your own Mac with a single
command, then drag it into your Applications folder. **No coding experience
needed.** Just follow these steps exactly. It takes about 5 minutes.

> **What you need:** a Mac running macOS 13 (Ventura) or newer. That's it.

### Step 1 — Open the Terminal app

The Terminal is an app that already comes with every Mac.

1. Press `⌘` (Command) and the `Space bar` at the same time. A search box appears
   in the middle of the screen.
2. Type **Terminal** and press `Return`.
3. A window with a blinking cursor opens. This is where you'll paste commands.

### Step 2 — Install Apple's developer tools (one-time)

NiCoLpy needs a small free toolkit from Apple to build. You probably don't have
it yet, so install it now. (If you already have it, the command just tells you so
— no harm done.)

Copy the line below, paste it into the Terminal window, and press `Return`:

```bash
xcode-select --install
```

- A popup window appears asking to install the tools. Click **Install** and then
  **Agree**.
- Wait for it to finish (a few minutes). When it's done, the popup closes by
  itself.

> Already have Xcode or the tools installed? You'll see a message like
> *"command line tools are already installed"* — that's fine, move on.

### Step 3 — Download and build NiCoLpy

Copy this entire block, paste it into the Terminal, and press `Return`.
It downloads NiCoLpy and builds the app for you automatically:

```bash
cd ~/Downloads && \
git clone https://github.com/vemsom/NiCoLpy.git && \
cd NiCoLpy && \
./build-app.sh release
```

When it finishes (about a minute), you'll see a line that says **"Done."**
The finished app is now in `~/Downloads/NiCoLpy/build/`.

### Step 4 — Move the app to your Applications folder

Copy and paste this line, then press `Return`:

```bash
cp -R ~/Downloads/NiCoLpy/build/NiCoLpy.app /Applications/
```

NiCoLpy is now installed in your Applications folder, just like any other app.

### Step 5 — Open NiCoLpy for the first time

Because NiCoLpy is a free app (not sold through Apple), macOS asks you to confirm
the first time you open it. You only do this **once**.

1. Open your **Applications** folder (in Finder, press `⌘⇧A`).
2. **Right-click** (or hold `Control` and click) on **NiCoLpy**.
3. Choose **Open** from the menu.
4. A warning appears — click the **Open** button to confirm.

That's it! Look at the top-right of your screen: a small clipboard icon 📋 now
sits in your menu bar. NiCoLpy is running.

> From now on, NiCoLpy just opens normally — you never have to right-click again.

### Step 6 — Allow auto-paste (recommended)

So that picking a clip can paste it for you automatically, give NiCoLpy one
permission:

1. When NiCoLpy first runs, a box may pop up asking for **Accessibility** access —
   click **Open System Settings** and turn NiCoLpy **on**.
2. If you missed it: open **System Settings → Privacy & Security →
   Accessibility**, find **NiCoLpy** in the list, and switch it **on**.

Without this, NiCoLpy still copies the clip you pick — you just paste it yourself
with `⌘V`.

## How to use it

- **Copy things normally** with `⌘C`. NiCoLpy remembers them.
- Press **`⌘⇧V`** (Command-Shift-V) anywhere to open the list of what you've
  copied — it appears right next to your cursor.
- **Pick a clip:** click it, or press a number key (`1`–`9`), or use `↑`/`↓` and
  press `Return`. Press `esc` to close without pasting.
- **Right-click the 📋 menu bar icon** for Settings, Launch at Login, and Quit.

## Updating to a newer version

Open Terminal and paste:

```bash
cd ~/Downloads/NiCoLpy && \
git pull && \
./build-app.sh release && \
cp -R build/NiCoLpy.app /Applications/
```

(Quit NiCoLpy first by right-clicking the menu bar icon → Quit.)

## Uninstalling

Drag **NiCoLpy** from your Applications folder to the Trash. To also remove the
permission, open **System Settings → Privacy & Security → Accessibility** and
remove NiCoLpy from the list.

## For developers

```bash
./build-app.sh            # debug build → build/NiCoLpy.app
./build-app.sh release    # optimized build
open build/NiCoLpy.app
```

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
