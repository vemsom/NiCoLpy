import Foundation
import AppKit

/// A single captured clipboard entry.
///
/// An item is either text or an image. Equality is based on `kind` content so we
/// can detect and skip duplicates when the same thing is copied repeatedly.
struct ClipItem: Identifiable, Equatable {
    enum Kind: Equatable {
        case text(String)
        case image(Data) // PNG-encoded image data

        static func == (lhs: Kind, rhs: Kind) -> Bool {
            switch (lhs, rhs) {
            case let (.text(a), .text(b)):
                return a == b
            case let (.image(a), .image(b)):
                return a == b
            default:
                return false
            }
        }
    }

    let id: UUID
    let kind: Kind
    let createdAt: Date
    var isPinned: Bool

    init(id: UUID = UUID(), kind: Kind, createdAt: Date = Date(), isPinned: Bool = false) {
        self.id = id
        self.kind = kind
        self.createdAt = createdAt
        self.isPinned = isPinned
    }

    /// Two items are considered "the same clip" when their content matches,
    /// regardless of id, timestamp or pin state.
    func hasSameContent(as other: ClipItem) -> Bool {
        kind == other.kind
    }

    // MARK: - Display helpers

    /// A short, single-line label suitable for menus and rows.
    var displayTitle: String {
        switch kind {
        case let .text(string):
            let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
            let collapsed = trimmed.replacingOccurrences(of: "\n", with: " ")
            if collapsed.count <= 60 {
                return collapsed.isEmpty ? "(empty text)" : collapsed
            }
            let endIndex = collapsed.index(collapsed.startIndex, offsetBy: 60)
            return String(collapsed[..<endIndex]) + "…"
        case .image:
            return "Image"
        }
    }

    /// An `NSImage` for image items, decoded on demand.
    var image: NSImage? {
        guard case let .image(data) = kind else { return nil }
        return NSImage(data: data)
    }

    var isText: Bool {
        if case .text = kind { return true }
        return false
    }

    var isImage: Bool {
        if case .image = kind { return true }
        return false
    }
}
