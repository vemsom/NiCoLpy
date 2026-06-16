import SwiftUI

/// App entry point.
///
/// `NiCoLpy` is a menu-bar app, so the SwiftUI `App` here mainly hosts the
/// `AppDelegate`, which owns the status item, picker panel and lifecycle. The
/// `Settings` scene provides the standard macOS Settings window (⌘,).
@main
struct NiCoLpyApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings {
            SettingsView(launchAtLogin: LaunchAtLogin.shared)
        }
    }
}
