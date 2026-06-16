import Foundation
import SwiftUI
import Combine

/// Drives the picker UI: tracks which row is selected and translates keyboard
/// commands (arrows, return, number keys, escape) into actions.
final class PickerController: ObservableObject {
    @Published var selectedIndex: Int = 0

    let store: ClipStore

    /// Paste the item at `index` in the *currently displayed* order.
    var onPaste: ((ClipItem) -> Void)?
    /// Dismiss the picker without pasting.
    var onCancel: (() -> Void)?

    init(store: ClipStore) {
        self.store = store
    }

    /// The items as currently displayed (pinned first, then newest-first).
    var visibleItems: [ClipItem] {
        store.ordered
    }

    /// Reset selection to the top each time the picker is shown.
    func reset() {
        selectedIndex = 0
    }

    // MARK: - Keyboard commands

    func moveDown() {
        let count = visibleItems.count
        guard count > 0 else { return }
        selectedIndex = min(selectedIndex + 1, count - 1)
    }

    func moveUp() {
        guard !visibleItems.isEmpty else { return }
        selectedIndex = max(selectedIndex - 1, 0)
    }

    /// Paste the currently selected row (used by Return).
    func pasteSelected() {
        let items = visibleItems
        guard items.indices.contains(selectedIndex) else { return }
        onPaste?(items[selectedIndex])
    }

    /// Paste by 1-based number key (1 = first row). Returns true if handled.
    @discardableResult
    func pasteByNumber(_ number: Int) -> Bool {
        let index = number - 1
        let items = visibleItems
        guard items.indices.contains(index) else { return false }
        selectedIndex = index
        onPaste?(items[index])
        return true
    }

    func cancel() {
        onCancel?()
    }
}
