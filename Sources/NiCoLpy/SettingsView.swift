import SwiftUI

/// The Settings window (⌘,). Keeps things minimal: launch-at-login control,
/// a quick reference of the keyboard shortcuts, and app info.
struct SettingsView: View {
    @ObservedObject var launchAtLogin: LaunchAtLogin

    var body: some View {
        Form {
            Section {
                Toggle("Launch NiCoLpy at login", isOn: $launchAtLogin.isEnabled)
                Text("NiCoLpy will start automatically and live in the menu bar.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Shortcuts") {
                shortcutRow("Open picker", "⌘⇧V")
                shortcutRow("Navigate", "↑ / ↓")
                shortcutRow("Paste selected", "↩")
                shortcutRow("Paste by position", "1 – 9")
                shortcutRow("Dismiss", "esc")
            }

            Section {
                HStack {
                    Text("NiCoLpy")
                        .fontWeight(.semibold)
                    Spacer()
                    Text("v0.1.0")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 380, height: 360)
        .onAppear { launchAtLogin.refresh() }
    }

    private func shortcutRow(_ label: String, _ keys: String) -> some View {
        HStack {
            Text(label)
            Spacer()
            Text(keys)
                .font(.system(.body, design: .rounded))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .background(
                    RoundedRectangle(cornerRadius: 5)
                        .fill(Color.primary.opacity(0.06))
                )
        }
    }
}
