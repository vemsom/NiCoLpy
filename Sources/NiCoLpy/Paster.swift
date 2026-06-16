import Foundation
import AppKit
import Carbon.HIToolbox

/// Writes a clip back to the pasteboard and (optionally) simulates Cmd+V so the
/// content lands in whatever app the user was last using.
enum Paster {
    /// Writes the item to the general pasteboard.
    ///
    /// - Parameter monitor: if provided, the monitor is told to ignore the
    ///   change we're about to cause, so our own write isn't re-captured.
    static func writeToPasteboard(_ item: ClipItem, monitor: ClipboardMonitor? = nil) {
        let pasteboard = NSPasteboard.general
        monitor?.suppressNextChange()
        pasteboard.clearContents()

        switch item.kind {
        case let .text(string):
            pasteboard.setString(string, forType: .string)
        case let .image(data):
            if let image = NSImage(data: data) {
                pasteboard.writeObjects([image])
            }
        }
    }

    /// Writes the item to the pasteboard and then issues a synthetic Cmd+V to the
    /// frontmost application.
    ///
    /// Requires Accessibility permission. If permission is missing, the content
    /// is still on the pasteboard so the user can paste manually.
    static func paste(_ item: ClipItem, monitor: ClipboardMonitor? = nil) {
        writeToPasteboard(item, monitor: monitor)

        guard AXIsProcessTrusted() else {
            // No permission to post events. The clip is on the pasteboard, which
            // is the best we can do without Accessibility access.
            return
        }

        // Give the frontmost app a moment to become first responder again after
        // our window/menu closes, then post the keystroke.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            postCommandV()
        }
    }

    private static func postCommandV() {
        let source = CGEventSource(stateID: .combinedSessionState)
        let vKey = CGKeyCode(kVK_ANSI_V)

        guard let keyDown = CGEvent(keyboardEventSource: source, virtualKey: vKey, keyDown: true),
              let keyUp = CGEvent(keyboardEventSource: source, virtualKey: vKey, keyDown: false) else {
            return
        }

        keyDown.flags = .maskCommand
        keyUp.flags = .maskCommand

        keyDown.post(tap: .cghidEventTap)
        keyUp.post(tap: .cghidEventTap)
    }
}
