import AppKit
import ApplicationServices
import OSLog

public enum ActionError: Error, LocalizedError {
    case permissionDenied
    case elementNotFound
    case elementStale
    case actionUnsupported
    case executionFailed(String)

    public var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "Accessibility permission not granted."
        case .elementNotFound:
            return "Could not locate status item element."
        case .elementStale:
            return "Status item element is no longer valid."
        case .actionUnsupported:
            return "This item does not support click actions."
        case .executionFailed(let reason):
            return "Unable to open item: \(reason)"
        }
    }

    public var userFriendlyMessage: String {
        switch self {
        case .permissionDenied:
            return "Permission required"
        case .elementNotFound, .elementStale:
            return "Item no longer available"
        case .actionUnsupported, .executionFailed:
            return "Unable to open this item"
        }
    }
}

@MainActor
public final class AccessibilityManager: ObservableObject {
    public static let shared = AccessibilityManager()

    @Published public private(set) var isTrusted: Bool = false

    private init() {
        checkPermissionStatus()
    }

    /// Checks the current process accessibility authorization status, including a live functional test.
    @discardableResult
    public func checkPermissionStatus() -> Bool {
        var trusted = AXIsProcessTrusted()

        // Secondary functional verification:
        // On macOS Ventura/Sonoma/Sequoia, AXIsProcessTrusted() can sometimes report false
        // even after permission is granted until an element is actually queried or process relaunched.
        if !trusted {
            let ccPID: pid_t = 1193
            let testElem = AXUIElementCreateApplication(ccPID)
            var val: AnyObject?
            let res = AXUIElementCopyAttributeValue(testElem, kAXRoleAttribute as CFString, &val)
            if res == .success && val != nil {
                trusted = true
                AppLog.accessibility.info("Accessibility functionally verified via ControlCenter query")
            }
        }

        if self.isTrusted != trusted {
            self.isTrusted = trusted
            AppLog.accessibility.info("Accessibility trust status changed to: \(trusted, privacy: .public)")
        }
        return trusted
    }

    /// Requests accessibility permission with the system prompt and opens System Settings.
    public func requestPermission() {
        AppLog.accessibility.info("Prompting user for Accessibility permission")

        let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        _ = AXIsProcessTrustedWithOptions(options as CFDictionary)

        openAccessibilitySettings()
    }

    /// Opens System Settings directly to Privacy & Security -> Accessibility
    public func openAccessibilitySettings() {
        let urls = [
            "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_Accessibility",
            "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility",
            "x-apple.systempreferences:com.apple.Accessibility-Settings.extension"
        ]
        for urlStr in urls {
            if let url = URL(string: urlStr) {
                if NSWorkspace.shared.open(url) {
                    AppLog.accessibility.info("Opened Settings via URL: \(urlStr, privacy: .public)")
                    return
                }
            }
        }
    }

    /// Reveals the Cove.app bundle in Finder so user can drag it into System Settings if not listed
    public func revealAppInFinder() {
        let bundleURL = Bundle.main.bundleURL
        NSWorkspace.shared.activateFileViewerSelecting([bundleURL])
    }

    /// Relaunches the Cove application to force macOS TCC token refresh
    public func relaunchApp() {
        let bundleURL = Bundle.main.bundleURL
        let config = NSWorkspace.OpenConfiguration()
        NSWorkspace.shared.openApplication(at: bundleURL, configuration: config) { _, _ in
            DispatchQueue.main.async {
                NSApplication.shared.terminate(nil)
            }
        }
    }

    /// Attempts to trigger the click action on the specified status item.
    public func performPress(
        item: MenuBarItem,
        completion: @escaping (Result<Void, ActionError>) -> Void
    ) {
        guard isTrusted else {
            AppLog.action.warning("Cannot perform press: Accessibility permission denied")
            completion(.failure(.permissionDenied))
            return
        }

        // 1. Resolve AX element, re-scanning if stale
        var targetElement = item.accessibilityElement
        if let elem = targetElement, !AXHelper.isElementValid(elem) {
            AppLog.action.info("Element for \(item.displayName, privacy: .public) is stale. Attempting re-scan...")
            targetElement = nil
        }

        if targetElement == nil, let pid = item.ownerPID {
            // Try to acquire fresh element by PID
            if let app = NSWorkspace.shared.runningApplications.first(where: { $0.processIdentifier == pid }) {
                let freshItems = MenuBarScanner.shared.scanApplicationForStatusItems(app: app)
                if let matched = freshItems.first(where: { $0.id == item.id }) ?? freshItems.first {
                    targetElement = matched.accessibilityElement
                }
            }
        }

        guard let element = targetElement else {
            AppLog.action.error("Failed to find valid element for \(item.displayName, privacy: .public)")
            // Fallback: Attempt simulated mouse click if we have a frame
            if performSimulatedClick(item: item) {
                completion(.success(()))
            } else {
                completion(.failure(.elementNotFound))
            }
            return
        }

        // 2. Try AXPress action
        let actionNames = AXHelper.getActionNames(element)
        AppLog.action.debug("Element action names for \(item.displayName, privacy: .public): \(actionNames.joined(separator: ", "), privacy: .public)")

        if actionNames.contains(kAXPressAction as String) {
            let error = AXUIElementPerformAction(element, kAXPressAction as CFString)
            if error == .success {
                AppLog.action.info("Successfully executed AXPress for \(item.displayName, privacy: .public)")
                completion(.success(()))
                return
            } else {
                AppLog.action.warning("AXPress returned AXError \(error.rawValue, privacy: .public) for \(item.displayName, privacy: .public)")
            }
        }

        // 3. Fallback: Secondary action attempts (e.g. AXPick, or simulated click)
        if actionNames.contains(kAXPickAction as String) {
            let error = AXUIElementPerformAction(element, kAXPickAction as CFString)
            if error == .success {
                AppLog.action.info("Successfully executed AXPick for \(item.displayName, privacy: .public)")
                completion(.success(()))
                return
            }
        }

        // 4. Fallback: Synthesized mouse click at item frame center
        if performSimulatedClick(item: item) {
            AppLog.action.info("Fallback simulated click succeeded for \(item.displayName, privacy: .public)")
            completion(.success(()))
        } else {
            AppLog.action.error("All click attempts failed for \(item.displayName, privacy: .public)")
            completion(.failure(.executionFailed("Could not trigger click")))
        }
    }

    /// Simulates a left mouse click at the center of the item's screen frame.
    private func performSimulatedClick(item: MenuBarItem) -> Bool {
        guard item.frame.width > 0, item.frame.height > 0 else { return false }
        let center = CGPoint(x: item.frame.midX, y: item.frame.midY)

        let source = CGEventSource(stateID: .combinedSessionState)
        guard let mouseDown = CGEvent(mouseEventSource: source, mouseType: .leftMouseDown, mouseCursorPosition: center, mouseButton: .left),
              let mouseUp = CGEvent(mouseEventSource: source, mouseType: .leftMouseUp, mouseCursorPosition: center, mouseButton: .left) else {
            return false
        }

        mouseDown.post(tap: .cghidEventTap)
        usleep(30_000) // 30ms delay between down and up
        mouseUp.post(tap: .cghidEventTap)
        return true
    }
}
