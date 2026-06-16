import Foundation
import AppKit
import Combine

/// Watches the system pasteboard and emits a `ClipItem` whenever new content
/// appears.
///
/// macOS doesn't provide a change notification for `NSPasteboard`, so the
/// conventional approach is to poll `changeCount` on a timer. We only do real
/// work (reading data) when the count actually changes, so the poll itself is
/// cheap.
final class ClipboardMonitor: ObservableObject {
    /// Called on the main thread whenever a new clip is detected.
    var onNewClip: ((ClipItem) -> Void)?

    private let pasteboard: NSPasteboard
    private var timer: Timer?
    private var lastChangeCount: Int

    /// When we write to the pasteboard ourselves (on paste), we bump this so the
    /// monitor doesn't re-capture our own write as a "new" clip.
    private var ignoreNextChangeCount: Int?

    init(pasteboard: NSPasteboard = .general) {
        self.pasteboard = pasteboard
        self.lastChangeCount = pasteboard.changeCount
    }

    func start(pollInterval: TimeInterval = 0.5) {
        stop()
        let timer = Timer.scheduledTimer(withTimeInterval: pollInterval, repeats: true) { [weak self] _ in
            self?.poll()
        }
        // Keep firing while menus/tracking loops are open.
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    /// Tell the monitor to ignore the change produced by our own paste write.
    func suppressNextChange() {
        // The change count after our write will be current + 1.
        ignoreNextChangeCount = pasteboard.changeCount + 1
    }

    private func poll() {
        let currentCount = pasteboard.changeCount
        guard currentCount != lastChangeCount else { return }
        lastChangeCount = currentCount

        if let ignore = ignoreNextChangeCount, ignore == currentCount {
            ignoreNextChangeCount = nil
            return
        }

        guard let item = readCurrentItem() else { return }
        if Thread.isMainThread {
            onNewClip?(item)
        } else {
            DispatchQueue.main.async { [weak self] in
                self?.onNewClip?(item)
            }
        }
    }

    /// Reads the current pasteboard content.
    ///
    /// Text is always preferred when present. We must not call
    /// `readObjects(forClasses: [NSImage.self])` first, because macOS will
    /// happily *render* rich text (RTF/HTML) into an `NSImage` — and since each
    /// render differs byte-for-byte, that produced a brand new "image" clip on
    /// every copy and broke de-duplication. Only when there is genuinely no text
    /// do we treat the pasteboard as an image.
    private func readCurrentItem() -> ClipItem? {
        // 1. Plain text in any of its representations.
        if let string = pasteboard.string(forType: .string), !string.isEmpty {
            return ClipItem(kind: .text(string))
        }

        // 2. A real image (only reached when no text is available).
        if hasImageData,
           let images = pasteboard.readObjects(forClasses: [NSImage.self], options: nil) as? [NSImage],
           let first = images.first,
           let png = first.pngData() {
            return ClipItem(kind: .image(png))
        }

        return nil
    }

    /// True only when the pasteboard advertises an actual image type, so we don't
    /// mistake rich-text-rendered-to-image for a real image copy.
    private var hasImageData: Bool {
        guard let types = pasteboard.types else { return false }
        let imageTypes: Set<NSPasteboard.PasteboardType> = [
            .png, .tiff,
            NSPasteboard.PasteboardType("public.jpeg"),
            NSPasteboard.PasteboardType("com.compuserve.gif"),
            NSPasteboard.PasteboardType("public.heic")
        ]
        return !Set(types).isDisjoint(with: imageTypes)
    }
}

// MARK: - NSImage PNG helper

extension NSImage {
    /// Encodes the image to PNG data, or nil if it can't be represented.
    func pngData() -> Data? {
        guard let tiff = tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff) else {
            return nil
        }
        return bitmap.representation(using: .png, properties: [:])
    }
}
