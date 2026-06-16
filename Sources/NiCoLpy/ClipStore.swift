import Foundation
import Combine

/// The in-memory model holding clipboard history.
///
/// Items are kept newest-first. Pinned items are exempt from the history limit
/// and are always sorted above unpinned items in the UI layer.
final class ClipStore: ObservableObject {
    @Published private(set) var items: [ClipItem] = []

    /// Maximum number of *unpinned* items to retain. Pinned items don't count
    /// against this limit.
    let maxUnpinned: Int

    init(maxUnpinned: Int = 50) {
        self.maxUnpinned = maxUnpinned
    }

    // MARK: - Capture

    /// Adds a freshly captured clip. If identical content already exists, the
    /// existing item is moved to the top instead of creating a duplicate.
    func add(_ item: ClipItem) {
        if let existingIndex = items.firstIndex(where: { $0.hasSameContent(as: item) }) {
            var existing = items.remove(at: existingIndex)
            existing = ClipItem(
                id: existing.id,
                kind: existing.kind,
                createdAt: Date(),
                isPinned: existing.isPinned
            )
            items.insert(existing, at: 0)
        } else {
            items.insert(item, at: 0)
        }
        enforceLimit()
    }

    // MARK: - Mutations

    func togglePin(_ item: ClipItem) {
        guard let index = items.firstIndex(where: { $0.id == item.id }) else { return }
        items[index].isPinned.toggle()
        enforceLimit()
    }

    func remove(_ item: ClipItem) {
        items.removeAll { $0.id == item.id }
    }

    /// Clears all unpinned items. Pinned items are kept.
    func clearUnpinned() {
        items.removeAll { !$0.isPinned }
    }

    /// Moves an item to the top (used after pasting so the most recently used
    /// clip is easy to find again).
    func bumpToTop(_ item: ClipItem) {
        guard let index = items.firstIndex(where: { $0.id == item.id }) else { return }
        let moved = items.remove(at: index)
        items.insert(moved, at: 0)
    }

    // MARK: - Ordering

    /// History ordered for display: pinned first (newest-first), then unpinned
    /// (newest-first).
    var ordered: [ClipItem] {
        let pinned = items.filter { $0.isPinned }.sorted { $0.createdAt > $1.createdAt }
        let unpinned = items.filter { !$0.isPinned }.sorted { $0.createdAt > $1.createdAt }
        return pinned + unpinned
    }

    // MARK: - Private

    private func enforceLimit() {
        let unpinned = items.filter { !$0.isPinned }.sorted { $0.createdAt > $1.createdAt }
        guard unpinned.count > maxUnpinned else { return }
        let toRemove = Set(unpinned.dropFirst(maxUnpinned).map { $0.id })
        items.removeAll { toRemove.contains($0.id) }
    }
}
