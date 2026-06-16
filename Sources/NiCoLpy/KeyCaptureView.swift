import AppKit
import SwiftUI

/// A zero-size view whose only job is to be first responder and route key
/// presses to the `PickerController`.
///
/// SwiftUI's `onKeyPress` is only available on macOS 14+, and even there it's
/// fiddly inside a borderless panel. An `NSView` keyDown handler is the most
/// reliable across versions.
struct KeyCaptureView: NSViewRepresentable {
    let controller: PickerController

    func makeNSView(context: Context) -> KeyCaptureNSView {
        let view = KeyCaptureNSView()
        view.controller = controller
        return view
    }

    func updateNSView(_ nsView: KeyCaptureNSView, context: Context) {
        nsView.controller = controller
        // Make sure we hold first-responder so keys keep flowing.
        DispatchQueue.main.async {
            nsView.window?.makeFirstResponder(nsView)
        }
    }
}

final class KeyCaptureNSView: NSView {
    weak var controller: PickerController?

    override var acceptsFirstResponder: Bool { true }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        window?.makeFirstResponder(self)
    }

    override func keyDown(with event: NSEvent) {
        guard let controller else {
            super.keyDown(with: event)
            return
        }

        switch event.keyCode {
        case 125: // Down arrow
            controller.moveDown()
            return
        case 126: // Up arrow
            controller.moveUp()
            return
        case 36, 76: // Return / keypad Enter
            controller.pasteSelected()
            return
        case 53: // Escape
            controller.cancel()
            return
        default:
            break
        }

        // Number keys 1–9 (top row and keypad) for direct paste.
        if let chars = event.charactersIgnoringModifiers,
           chars.count == 1,
           let digit = Int(chars),
           (1...9).contains(digit) {
            if controller.pasteByNumber(digit) {
                return
            }
        }

        super.keyDown(with: event)
    }
}
