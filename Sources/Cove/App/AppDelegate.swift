import AppKit
import OSLog

extension Notification.Name {
    public static let requestMenuBarRefresh = Notification.Name("CoveRequestMenuBarRefresh")
}

@MainActor
public final class AppDelegate: NSObject, NSApplicationDelegate {
    public func applicationDidFinishLaunching(_ notification: Notification) {
        AppLog.app.info("Cove is launching...")

        // Setup status item in Menu Bar
        MenuBarController.shared.setup()

        // Check accessibility permission on startup
        let isTrusted = AccessibilityManager.shared.checkPermissionStatus()
        AppLog.app.info("Initial Accessibility trust: \(isTrusted, privacy: .public)")

        // Register global hotkey (Control + Option + C) for toggling panel even if notch occludes status item
        HotKeyManager.shared.registerDefaultHotKey {
            StatusPanelController.shared.toggle(relativeTo: MenuBarController.shared.statusItemButton)
        }

        // Register system event observers for zero-polling background updates
        registerNotificationObservers()

        AppLog.app.info("Cove initialized successfully")
    }

    private func registerNotificationObservers() {
        let notificationCenter = NotificationCenter.default
        let workspaceCenter = NSWorkspace.shared.notificationCenter

        // Screen configuration or resolution change
        notificationCenter.addObserver(
            self,
            selector: #selector(screenParametersDidChange),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )

        // App launch
        workspaceCenter.addObserver(
            self,
            selector: #selector(workspaceAppDidChange),
            name: NSWorkspace.didLaunchApplicationNotification,
            object: nil
        )

        // App quit
        workspaceCenter.addObserver(
            self,
            selector: #selector(workspaceAppDidChange),
            name: NSWorkspace.didTerminateApplicationNotification,
            object: nil
        )

        // App activate / switch (affects left-hand menu bar width)
        workspaceCenter.addObserver(
            self,
            selector: #selector(workspaceAppDidChange),
            name: NSWorkspace.didActivateApplicationNotification,
            object: nil
        )

        // Space / desktop switch
        workspaceCenter.addObserver(
            self,
            selector: #selector(workspaceAppDidChange),
            name: NSWorkspace.activeSpaceDidChangeNotification,
            object: nil
        )

        // System wake from sleep
        workspaceCenter.addObserver(
            self,
            selector: #selector(systemDidWake),
            name: NSWorkspace.didWakeNotification,
            object: nil
        )
    }

    @objc private func screenParametersDidChange() {
        AppLog.app.info("Screen parameters changed, notifying refresh...")
        NotificationCenter.default.post(name: .requestMenuBarRefresh, object: nil)
    }

    @objc private func workspaceAppDidChange() {
        AppLog.app.debug("Workspace app launched/terminated/switched, notifying refresh...")
        NotificationCenter.default.post(name: .requestMenuBarRefresh, object: nil)
    }

    @objc private func systemDidWake() {
        AppLog.app.info("System woke from sleep, re-checking status...")
        _ = AccessibilityManager.shared.checkPermissionStatus()
        NotificationCenter.default.post(name: .requestMenuBarRefresh, object: nil)
    }
}
