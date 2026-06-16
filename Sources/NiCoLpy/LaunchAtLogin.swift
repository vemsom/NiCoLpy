import Foundation
import ServiceManagement
import Combine

/// Manages whether NiCoLpy launches automatically at login, using the modern
/// `SMAppService` API (macOS 13+). The app registers *itself* as a login item;
/// no separate helper bundle is required.
final class LaunchAtLogin: ObservableObject {
    static let shared = LaunchAtLogin()

    /// Reflects the current registration state. Setting it registers or
    /// unregisters the app as a login item.
    @Published var isEnabled: Bool {
        didSet {
            guard oldValue != isEnabled else { return }
            // Avoid re-entrancy when we're only syncing from the system state.
            guard !isSyncing else { return }
            apply(isEnabled)
        }
    }

    /// True while we update `isEnabled` to mirror the OS, so `didSet` doesn't
    /// try to re-apply the change.
    private var isSyncing = false

    private init() {
        self.isEnabled = (SMAppService.mainApp.status == .enabled)
    }

    /// Re-reads the system state (e.g. after the user changed it in System
    /// Settings) without triggering a register/unregister.
    func refresh() {
        let live = (SMAppService.mainApp.status == .enabled)
        guard live != isEnabled else { return }
        isSyncing = true
        isEnabled = live
        isSyncing = false
    }

    private func apply(_ enable: Bool) {
        do {
            if enable {
                if SMAppService.mainApp.status != .enabled {
                    try SMAppService.mainApp.register()
                }
            } else {
                if SMAppService.mainApp.status == .enabled {
                    try SMAppService.mainApp.unregister()
                }
            }
        } catch {
            NSLog("NiCoLpy: failed to \(enable ? "enable" : "disable") launch at login: \(error.localizedDescription)")
            DispatchQueue.main.async { [weak self] in
                self?.refresh()
            }
        }
    }
}
