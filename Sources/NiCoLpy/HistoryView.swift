import SwiftUI

/// The scrollable list of clips shown in the floating picker panel.
///
/// Selection and keyboard handling live in `PickerController`; this view renders
/// the current state and forwards mouse clicks / hover actions.
struct HistoryView: View {
    @ObservedObject var store: ClipStore
    @ObservedObject var controller: PickerController

    /// Called when the user picks an item to paste (click).
    var onPaste: (ClipItem) -> Void
    /// Called when the user just wants to copy (no auto-paste).
    var onCopy: (ClipItem) -> Void

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            content
        }
        .frame(width: 360, height: 440)
        .background(.regularMaterial)
        // Key catcher overlaid with zero hit-testing so it never blocks clicks
        // on the rows, but still receives keyDown as first responder.
        .background(
            KeyCaptureView(controller: controller)
                .frame(width: 0, height: 0)
                .allowsHitTesting(false)
        )
    }

    private var header: some View {
        HStack {
            Image(systemName: "doc.on.clipboard")
            Text("NiCoLpy")
                .font(.headline)
            Spacer()
            Text("↑↓ · ⏎ · 1–9")
                .font(.caption2)
                .foregroundStyle(.tertiary)
            Button {
                store.clearUnpinned()
            } label: {
                Image(systemName: "trash")
            }
            .buttonStyle(.borderless)
            .help("Clear unpinned history")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    @ViewBuilder
    private var content: some View {
        // Read `store.ordered` directly so SwiftUI tracks `store.items` as a
        // dependency and re-renders when new clips arrive. (Reading via the
        // controller hid this dependency and froze the list on first render.)
        let items = store.ordered
        if items.isEmpty {
            emptyState
        } else {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 2) {
                        ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                            ClipRow(
                                item: item,
                                number: index < 9 ? index + 1 : nil,
                                isSelected: index == controller.selectedIndex,
                                onPaste: { onPaste(item) },
                                onCopy: { onCopy(item) },
                                onPin: { store.togglePin(item) },
                                onDelete: { store.remove(item) }
                            )
                            // Identity must match the ForEach id (the item's id),
                            // not the positional index. Using `.id(index)` here
                            // created a second, conflicting identity that made
                            // SwiftUI reuse cells and show the wrong (first) item
                            // in every row.
                            .id(item.id)
                        }
                    }
                    .padding(8)
                }
                .onChange(of: controller.selectedIndex) { newValue in
                    let ordered = store.ordered
                    guard ordered.indices.contains(newValue) else { return }
                    withAnimation(.easeOut(duration: 0.12)) {
                        proxy.scrollTo(ordered[newValue].id, anchor: .center)
                    }
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Spacer()
            Image(systemName: "tray")
                .font(.system(size: 32))
                .foregroundStyle(.secondary)
            Text("No clips yet")
                .foregroundStyle(.secondary)
            Text("Copy something and it will show up here.")
                .font(.caption)
                .foregroundStyle(.tertiary)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// A single row in the history list.
private struct ClipRow: View {
    let item: ClipItem
    /// 1–9 for the first nine rows, else nil.
    let number: Int?
    let isSelected: Bool
    var onPaste: () -> Void
    var onCopy: () -> Void
    var onPin: () -> Void
    var onDelete: () -> Void

    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 8) {
            numberBadge
            icon
            content
            Spacer(minLength: 4)
            if isHovering {
                actions
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(rowBackground)
        .contentShape(Rectangle())
        .onTapGesture(perform: onPaste)
        .onHover { isHovering = $0 }
    }

    private var rowBackground: some View {
        RoundedRectangle(cornerRadius: 6)
            .fill(backgroundColor)
    }

    private var backgroundColor: Color {
        if isSelected {
            return Color.accentColor.opacity(0.25)
        }
        if isHovering {
            return Color.primary.opacity(0.08)
        }
        return Color.clear
    }

    @ViewBuilder
    private var numberBadge: some View {
        if let number {
            Text("\(number)")
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
                .frame(width: 16, height: 16)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.primary.opacity(0.06))
                )
        } else {
            Color.clear.frame(width: 16, height: 16)
        }
    }

    @ViewBuilder
    private var icon: some View {
        if item.isImage, let nsImage = item.image {
            Image(nsImage: nsImage)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 28, height: 28)
                .clipShape(RoundedRectangle(cornerRadius: 4))
        } else {
            Image(systemName: item.isPinned ? "pin.fill" : "text.alignleft")
                .frame(width: 28, height: 28)
                .foregroundStyle(item.isPinned ? Color.accentColor : Color.secondary)
        }
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(item.displayTitle)
                .lineLimit(1)
                .font(.system(size: 13))
            Text(item.createdAt, style: .relative)
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
    }

    private var actions: some View {
        HStack(spacing: 4) {
            Button(action: onPin) {
                Image(systemName: item.isPinned ? "pin.slash" : "pin")
            }
            .help(item.isPinned ? "Unpin" : "Pin")

            Button(action: onCopy) {
                Image(systemName: "doc.on.doc")
            }
            .help("Copy without pasting")

            Button(action: onDelete) {
                Image(systemName: "xmark")
            }
            .help("Remove")
        }
        .buttonStyle(.borderless)
        .foregroundStyle(.secondary)
    }
}
