import SwiftUI
import AppKit

/// Wires together the status item, floating picker panel, global hotkey,
/// clipboard monitor and store.
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let store = ClipStore(maxUnpinned: 50)
    private let monitor = ClipboardMonitor()
    private let hotKeys = HotKeyCenter()
    private lazy var controller = PickerController(store: store)

    private var statusItem: NSStatusItem!
    private var panel: PickerPanel!

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        setupStatusItem()
        setupPanel()
        setupController()
        setupMonitor()
        setupHotKey()

        requestAccessibilityIfNeeded()
        offerLaunchAtLoginIfFirstRun()
    }

    // MARK: - Setup

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "doc.on.clipboard",
                                   accessibilityDescription: "NiCoLpy")
            button.action = #selector(statusItemClicked(_:))
            button.target = self
            // Receive both left- and right-mouse-up so we can show the picker on
            // left-click and a context menu on right-click.
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
    }

    private func setupPanel() {
        let root = HistoryView(
            store: store,
            controller: controller,
            onPaste: { [weak self] item in self?.handlePaste(item) },
            onCopy: { [weak self] item in self?.handleCopy(item) }
        )
        let hosting = NSHostingView(rootView: root)
        hosting.frame = NSRect(x: 0, y: 0, width: 360, height: 440)
        panel = PickerPanel(contentView: hosting)
    }

    private func setupController() {
        controller.onPaste = { [weak self] item in self?.handlePaste(item) }
        controller.onCancel = { [weak self] in self?.hidePanel() }
    }

    private func setupMonitor() {
        monitor.onNewClip = { [weak self] item in
            self?.store.add(item)
        }
        monitor.start()
    }

    private func setupHotKey() {
        hotKeys.onHotKey = { [weak self] in
            self?.toggleAtCaret()
        }
        hotKeys.register() // Cmd+Shift+V
    }

    private func requestAccessibilityIfNeeded() {
        let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        let options = [key: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }

    // MARK: - Show / hide

    /// Hotkey path: anchor at the caret (falls back to the mouse).
    private func toggleAtCaret() {
        if panel.isVisible {
            hidePanel()
            return
        }
        // Capture the anchor *before* our panel takes focus and changes the
        // focused UI element.
        let anchor = CaretLocator.anchorPoint()
        showPanel(at: anchor)
    }

    /// Menu-bar click path. Left-click toggles the picker; right-click (or
    /// control-click) shows the context menu.
    @objc private func statusItemClicked(_ sender: Any?) {
        let event = NSApp.currentEvent
        let isRightClick = event?.type == .rightMouseUp
            || (event?.type == .leftMouseUp && event?.modifierFlags.contains(.control) == true)

        if isRightClick {
            showContextMenu()
            return
        }

        if panel.isVisible {
            hidePanel()
            return
        }
        let anchor: NSPoint
        if let button = statusItem.button, let window = button.window {
            let rectInWindow = button.convert(button.bounds, to: nil)
            let rectInScreen = window.convertToScreen(rectInWindow)
            anchor = NSPoint(x: rectInScreen.minX, y: rectInScreen.minY)
        } else {
            anchor = NSEvent.mouseLocation
        }
        showPanel(at: anchor)
    }

    // MARK: - Context menu

    private func showContextMenu() {
        let menu = NSMenu()

        let loginItem = NSMenuItem(
            title: "Launch at Login",
            action: #selector(toggleLaunchAtLogin),
            keyEquivalent: ""
        )
        loginItem.target = self
        loginItem.state = LaunchAtLogin.shared.isEnabled ? .on : .off
        menu.addItem(loginItem)

        let settingsItem = NSMenuItem(
            title: "Settings…",
            action: #selector(openSettings),
            keyEquivalent: ","
        )
        settingsItem.target = self
        menu.addItem(settingsItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(
            title: "Quit NiCoLpy",
            action: #selector(quit),
            keyEquivalent: "q"
        )
        quitItem.target = self
        menu.addItem(quitItem)

        // Show the menu under the status item, then clear it so left-click keeps
        // opening the picker (a persistent menu would override the action).
        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil
    }

    @objc private func toggleLaunchAtLogin() {
        LaunchAtLogin.shared.isEnabled.toggle()
    }

    @objc private func openSettings() {
        NSApp.activate(ignoringOtherApps: true)
        // Open the standard SwiftUI Settings scene.
        if #available(macOS 14, *) {
            NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
        } else {
            NSApp.sendAction(Selector(("showPreferencesWindow:")), to: nil, from: nil)
        }
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    // MARK: - First-run login prompt

    /// On first launch, offer to add NiCoLpy to Login Items. The choice (and the
    /// fact that we asked) is remembered so we never nag again.
    private func offerLaunchAtLoginIfFirstRun() {
        let key = "NiCoLpy.didOfferLaunchAtLogin"
        guard !UserDefaults.standard.bool(forKey: key) else { return }
        UserDefaults.standard.set(true, forKey: key)

        // Already enabled (e.g. user set it manually)? Nothing to ask.
        guard !LaunchAtLogin.shared.isEnabled else { return }

        // Defer slightly so it doesn't race the app finishing launch.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            let alert = NSAlert()
            alert.messageText = "Launch NiCoLpy at login?"
            alert.informativeText = "NiCoLpy can start automatically and stay ready in the menu bar. You can change this any time in Settings or by right-clicking the menu bar icon."
            alert.addButton(withTitle: "Add to Login Items")
            alert.addButton(withTitle: "Not Now")
            alert.alertStyle = .informational

            NSApp.activate(ignoringOtherApps: true)
            if alert.runModal() == .alertFirstButtonReturn {
                LaunchAtLogin.shared.isEnabled = true
            }
        }
    }

    private func showPanel(at anchor: NSPoint) {
        controller.reset()
        panel.show(near: anchor)
    }

    private func hidePanel() {
        panel.orderOut(nil)
    }

    // MARK: - Actions

    private func handlePaste(_ item: ClipItem) {
        hidePanel()
        store.bumpToTop(item)
        // Let the panel fully close and focus return to the previous app before
        // synthesizing Cmd+V.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) { [weak self] in
            Paster.paste(item, monitor: self?.monitor)
        }
    }

    private func handleCopy(_ item: ClipItem) {
        store.bumpToTop(item)
        Paster.writeToPasteboard(item, monitor: monitor)
        hidePanel()
    }
}
