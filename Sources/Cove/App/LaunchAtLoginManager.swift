import Foundation
import ServiceManagement
import OSLog

@MainActor
public final class LaunchAtLoginManager: ObservableObject {
    public static let shared = LaunchAtLoginManager()

    @Published public private(set) var isEnabled: Bool = false
    @Published public private(set) var status: SMAppService.Status = .notRegistered
    @Published public private(set) var requiresApproval: Bool = false
    @Published public private(set) var lastErrorMessage: String? = nil

    private init() {
        refreshStatus()
    }

    public func refreshStatus() {
        let currentStatus = SMAppService.mainApp.status
        self.status = currentStatus
        self.isEnabled = (currentStatus == .enabled)
        self.requiresApproval = (currentStatus == .requiresApproval)
        AppLog.app.info("LaunchAtLogin status refreshed: \(String(describing: currentStatus)) (enabled: \(self.isEnabled))")
    }

    public func setEnabled(_ enabled: Bool) {
        lastErrorMessage = nil
        do {
            if enabled {
                if SMAppService.mainApp.status == .enabled {
                    self.isEnabled = true
                    return
                }
                try SMAppService.mainApp.register()
                AppLog.app.info("SMAppService.mainApp successfully registered for login launch")
            } else {
                try SMAppService.mainApp.unregister()
                AppLog.app.info("SMAppService.mainApp successfully unregistered from login launch")
            }
        } catch {
            let desc = error.localizedDescription
            self.lastErrorMessage = desc
            AppLog.app.error("Failed to set LaunchAtLogin (\(enabled)): \(desc, privacy: .public)")
        }
        refreshStatus()
    }

    public func toggle() {
        setEnabled(!isEnabled)
    }

    public func openSystemSettings() {
        SMAppService.openSystemSettingsLoginItems()
    }
}
