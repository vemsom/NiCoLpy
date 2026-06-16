import AppKit
import SwiftUI

/// A floating, borderless panel that hosts the clip picker.
///
/// Unlike `NSPopover`, a panel can be positioned at an arbitrary screen point
/// (next to the caret) and can become key to receive keyboard events, while
/// still being lightweight and non-activating.
final class PickerPanel: NSPanel {
    init(contentView: NSView) {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 360, height: 440),
            styleMask: [.nonactivatingPanel, .borderless, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        isFloatingPanel = true
        level = .floating
        hidesOnDeactivate = false
        isMovableByWindowBackground = false
        backgroundColor = .clear
        isOpaque = false
        hasShadow = true

        // Rounded corners on the hosted content.
        contentView.wantsLayer = true
        contentView.layer?.cornerRadius = 12
        contentView.layer?.masksToBounds = true
        self.contentView = contentView

        // Don't show up in the window list / Mission Control.
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
    }

    // Borderless panels return false by default; we need key to read the keyboard.
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    /// Shows the panel anchored near the given screen point (Cocoa coordinates),
    /// keeping it fully on-screen.
    func show(near anchor: NSPoint) {
        let size = frame.size
        guard let screen = screenContaining(anchor) ?? NSScreen.main else {
            makeKeyAndOrderFront(nil)
            return
        }
        let visible = screen.visibleFrame

        // Default: place the panel below-right of the anchor (just under caret).
        var origin = NSPoint(x: anchor.x, y: anchor.y - size.height - 4)

        // Keep within horizontal bounds.
        if origin.x + size.width > visible.maxX {
            origin.x = visible.maxX - size.width - 8
        }
        if origin.x < visible.minX {
            origin.x = visible.minX + 8
        }

        // If it would go off the bottom, flip to above the anchor.
        if origin.y < visible.minY {
            origin.y = anchor.y + 4
        }
        // And clamp the top.
        if origin.y + size.height > visible.maxY {
            origin.y = visible.maxY - size.height - 8
        }

        setFrameOrigin(origin)
        makeKeyAndOrderFront(nil)
    }

    private func screenContaining(_ point: NSPoint) -> NSScreen? {
        NSScreen.screens.first { NSPointInRect(point, $0.frame) }
    }
}
