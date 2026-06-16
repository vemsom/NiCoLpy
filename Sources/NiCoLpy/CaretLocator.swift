import Foundation
import AppKit
import ApplicationServices

/// Finds the on-screen location of the text insertion point (caret) in the
/// frontmost application, so the picker can be shown right next to where text
/// will be inserted.
///
/// This relies on the Accessibility API. macOS does not expose the caret for
/// every app (some non-native or custom text views don't publish it), so every
/// path falls back gracefully to the current mouse location.
enum CaretLocator {
    /// Returns a screen point (in Cocoa bottom-left origin coordinates) suitable
    /// for anchoring the picker. Prefers the caret; falls back to the mouse.
    static func anchorPoint() -> NSPoint {
        if let caret = caretScreenRect() {
            // Anchor just below the caret's baseline.
            return NSPoint(x: caret.minX, y: caret.minY)
        }
        return mouseLocation()
    }

    /// The caret rectangle in Cocoa screen coordinates, if obtainable.
    static func caretScreenRect() -> NSRect? {
        guard AXIsProcessTrusted() else { return nil }

        let system = AXUIElementCreateSystemWide()

        // 1. Find the focused UI element.
        var focused: AnyObject?
        guard AXUIElementCopyAttributeValue(system,
                                            kAXFocusedUIElementAttribute as CFString,
                                            &focused) == .success,
              let element = focused else {
            return nil
        }
        let axElement = element as! AXUIElement

        // 2. Get the selected text range (the caret is a zero-length selection).
        var rangeValue: AnyObject?
        guard AXUIElementCopyAttributeValue(axElement,
                                            kAXSelectedTextRangeAttribute as CFString,
                                            &rangeValue) == .success,
              let rangeAX = rangeValue,
              CFGetTypeID(rangeAX) == AXValueGetTypeID() else {
            return nil
        }

        var cfRange = CFRange()
        guard AXValueGetValue(rangeAX as! AXValue, .cfRange, &cfRange) else {
            return nil
        }

        // 3. Ask for the bounds of that range. Some elements only answer for a
        //    length >= 1, so try the real range first, then a 1-char range.
        if let rect = boundsForRange(axElement, location: cfRange.location, length: max(cfRange.length, 1)) {
            return convertToCocoa(rect)
        }
        if cfRange.location > 0,
           let rect = boundsForRange(axElement, location: cfRange.location - 1, length: 1) {
            return convertToCocoa(rect)
        }

        // 4. Last resort: the element's own frame (e.g. a small text field).
        if let frame = elementFrame(axElement) {
            return convertToCocoa(frame)
        }

        return nil
    }

    // MARK: - Helpers

    private static func boundsForRange(_ element: AXUIElement, location: Int, length: Int) -> CGRect? {
        var cfRange = CFRange(location: location, length: length)
        guard let axRange = AXValueCreate(.cfRange, &cfRange) else { return nil }

        var boundsValue: AnyObject?
        let err = AXUIElementCopyParameterizedAttributeValue(
            element,
            kAXBoundsForRangeParameterizedAttribute as CFString,
            axRange,
            &boundsValue
        )
        guard err == .success,
              let bounds = boundsValue,
              CFGetTypeID(bounds) == AXValueGetTypeID() else {
            return nil
        }

        var rect = CGRect.zero
        guard AXValueGetValue(bounds as! AXValue, .cgRect, &rect) else { return nil }
        // A zero-size rect is useless as an anchor.
        guard rect.width.isFinite, rect.height.isFinite, !(rect.origin.x == 0 && rect.origin.y == 0) else {
            return nil
        }
        return rect
    }

    private static func elementFrame(_ element: AXUIElement) -> CGRect? {
        var posValue: AnyObject?
        var sizeValue: AnyObject?
        guard AXUIElementCopyAttributeValue(element, kAXPositionAttribute as CFString, &posValue) == .success,
              AXUIElementCopyAttributeValue(element, kAXSizeAttribute as CFString, &sizeValue) == .success,
              let posAX = posValue, let sizeAX = sizeValue,
              CFGetTypeID(posAX) == AXValueGetTypeID(),
              CFGetTypeID(sizeAX) == AXValueGetTypeID() else {
            return nil
        }
        var point = CGPoint.zero
        var size = CGSize.zero
        guard AXValueGetValue(posAX as! AXValue, .cgPoint, &point),
              AXValueGetValue(sizeAX as! AXValue, .cgSize, &size) else {
            return nil
        }
        return CGRect(origin: point, size: size)
    }

    /// AX rects use top-left origin in global display space. Convert to Cocoa's
    /// bottom-left origin using the primary screen height.
    private static func convertToCocoa(_ axRect: CGRect) -> NSRect {
        let screenHeight = (NSScreen.screens.first?.frame.height) ?? NSScreen.main?.frame.height ?? 0
        let flippedY = screenHeight - axRect.origin.y - axRect.height
        return NSRect(x: axRect.origin.x, y: flippedY, width: axRect.width, height: axRect.height)
    }

    private static func mouseLocation() -> NSPoint {
        NSEvent.mouseLocation
    }
}
