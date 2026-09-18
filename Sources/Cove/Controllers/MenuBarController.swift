import AppKit
import OSLog

@MainActor
public final class MenuBarController: NSObject {
    public static let shared = MenuBarController()

    private var statusItem: NSStatusItem?

    public override init() {
        super.init()
    }

    public static let autosaveName = "com.cove.app.statusitem"
    public static let preferredPositionKey = "NSStatusItem Preferred Position com.cove.app.statusitem"

    public func setup() {
        // Seed initial preferred position if not set, positioning as close to the right edge as allowed
        // (immediately next to system menu extras like Input Source / Control Center)
        if UserDefaults.standard.object(forKey: Self.preferredPositionKey) == nil {
            UserDefaults.standard.set(200.0, forKey: Self.preferredPositionKey)
            AppLog.app.info("Seeded initial preferred position for status item (200.0 pt from right)")
        }

        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.autosaveName = Self.autosaveName

        if let button = item.button {
            let symbolConfig = NSImage.SymbolConfiguration(pointSize: 14, weight: .regular)
            let image = NSImage(systemSymbolName: "menubar.dock.rectangle", accessibilityDescription: "Cove")?
                .withSymbolConfiguration(symbolConfig)
            image?.isTemplate = true

            button.image = image
            button.target = self
            button.action = #selector(statusItemClicked(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }

        self.statusItem = item
        AppLog.app.info("NSStatusItem configured with autosaveName '\(Self.autosaveName)' and mounted to menu bar")
    }

    public func resetPositionToRightmost() {
        UserDefaults.standard.set(200.0, forKey: Self.preferredPositionKey)
        if let existing = statusItem {
            NSStatusBar.system.removeStatusItem(existing)
            statusItem = nil
        }
        setup()
        AppLog.app.info("Reset status item preferred position to rightmost (200.0)")
    }

    @objc private func statusItemClicked(_ sender: NSStatusBarButton) {
        guard let event = NSApp.currentEvent else { return }

        // Right-click or Option+click shows context menu
        if event.type == .rightMouseUp || event.modifierFlags.contains(.option) {
            showContextMenu(for: sender)
        } else {
            // Left-click toggles status panel
            StatusPanelController.shared.toggle(relativeTo: sender)
        }
    }

    private func showContextMenu(for sender: NSStatusBarButton) {
        let menu = NSMenu()

        let refreshItem = NSMenuItem(title: "Refresh Menu Bar", action: #selector(refreshAction), keyEquivalent: "r")
        refreshItem.target = self
        menu.addItem(refreshItem)

        let moveToRightItem = NSMenuItem(title: "Move Next to Input Method (移至输入法旁)", action: #selector(moveToRightAction), keyEquivalent: "")
        moveToRightItem.target = self
        menu.addItem(moveToRightItem)

        let launchAtLoginItem = NSMenuItem(
            title: "Launch at Login (开机自启)",
            action: #selector(toggleLaunchAtLoginAction),
            keyEquivalent: ""
        )
        launchAtLoginItem.target = self
        launchAtLoginItem.state = LaunchAtLoginManager.shared.isEnabled ? .on : .off
        menu.addItem(launchAtLoginItem)

        let settingsItem = NSMenuItem(title: "Accessibility Settings…", action: #selector(openSettingsAction), keyEquivalent: "")
        settingsItem.target = self
        menu.addItem(settingsItem)

        menu.addItem(NSMenuItem.separator())

        let quitItem = NSMenuItem(title: "Quit Cove", action: #selector(quitAction), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem?.menu = menu
        sender.performClick(nil)
        statusItem?.menu = nil // Clear menu so regular click toggles panel
    }

    @objc private func toggleLaunchAtLoginAction() {
        LaunchAtLoginManager.shared.toggle()
    }

    @objc private func moveToRightAction() {
        resetPositionToRightmost()
    }

    @objc private func refreshAction() {
        _ = AccessibilityManager.shared.checkPermissionStatus()
        // If panel is visible, tell it to refresh
    }

    @objc private func openSettingsAction() {
        AccessibilityManager.shared.openAccessibilitySettings()
    }

    @objc private func quitAction() {
        NSApplication.shared.terminate(nil)
    }

    public var statusItemButton: NSStatusBarButton? {
        return statusItem?.button
    }
}
