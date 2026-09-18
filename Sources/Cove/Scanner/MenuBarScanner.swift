import AppKit
import ApplicationServices
import OSLog

public final class MenuBarScanner: Sendable {
    public static let shared = MenuBarScanner()

    public init() {}

    /// Performs a full scan of all Menu Bar status items using AXUIElement and CoreGraphics.
    public func scan() -> [MenuBarItem] {
        let currentPID = ProcessInfo.processInfo.processIdentifier
        let isTrusted = AXIsProcessTrusted()

        AppLog.scanner.info("Starting MenuBar scan (AX Trusted: \(isTrusted, privacy: .public))")

        let runningApps = NSWorkspace.shared.runningApplications
        let windowItems = WindowServerScanner.shared.scanStatusWindows()

        var scannedItems: [MenuBarItem] = []
        var seenIDs = Set<String>()

        if isTrusted {
            // 1. Scan Control Center's MenuBar (hosts system items like Wi-Fi, Battery, Clock, Spotlight, Control Center)
            if let ccApp = runningApps.first(where: { $0.bundleIdentifier == "com.apple.controlcenter" }) {
                let ccItems = scanControlCenter(app: ccApp, runningApps: runningApps)
                for item in ccItems where isAllowedItem(item, currentPID: currentPID) {
                    if seenIDs.insert(item.id).inserted {
                        scannedItems.append(item)
                    }
                }
            }

            // 2. Scan SystemUIServer
            if let suApp = runningApps.first(where: { $0.bundleIdentifier == "com.apple.systemuiserver" }) {
                let suItems = scanSystemUIServer(app: suApp, runningApps: runningApps)
                for item in suItems where isAllowedItem(item, currentPID: currentPID) {
                    if seenIDs.insert(item.id).inserted {
                        scannedItems.append(item)
                    }
                }
            }

            // 3. Scan all running third-party applications (accessory and regular) via AXExtrasMenuBar
            let nonAppleApps = runningApps.filter { app in
                guard let bundleID = app.bundleIdentifier, !bundleID.isEmpty else { return false }
                return !bundleID.hasPrefix("com.apple.") &&
                       bundleID != "com.cove.app" &&
                       app.localizedName != "Cove" &&
                       app.processIdentifier != currentPID &&
                       (app.activationPolicy == .accessory || app.activationPolicy == .regular)
            }

            for app in nonAppleApps {
                let appItems = scanAppProcess(app: app)
                for item in appItems where isAllowedItem(item, currentPID: currentPID) {
                    if seenIDs.insert(item.id).inserted {
                        scannedItems.append(item)
                    }
                }
            }
        }

        // 4. Reconcile with WindowServer status windows (layer 25)
        let ccApp = runningApps.first(where: { $0.bundleIdentifier == "com.apple.controlcenter" })

        for win in windowItems where win.ownerPID != currentPID {
            // Check if this window was already matched to a scanned AX item by X proximity
            let matchedIndex = scannedItems.firstIndex { item in
                abs(item.frame.midX - win.bounds.midX) < 18.0 || abs(item.frame.minX - win.bounds.minX) < 18.0
            }

            if let idx = matchedIndex {
                // Refine frame with exact WindowServer bounds if AX frame was imprecise
                if scannedItems[idx].frame.width <= 0 || scannedItems[idx].frame.height <= 0 {
                    let old = scannedItems[idx]
                    scannedItems[idx] = MenuBarItem(
                        id: old.id,
                        title: old.title,
                        itemDescription: old.itemDescription,
                        frame: win.bounds,
                        ownerName: old.ownerName,
                        ownerPID: old.ownerPID,
                        bundleIdentifier: old.bundleIdentifier,
                        icon: old.icon,
                        systemSymbolName: old.systemSymbolName,
                        accessibilityElement: old.accessibilityElement,
                        overflowState: old.overflowState,
                        isClickable: old.isClickable,
                        actionState: old.actionState
                    )
                }
            } else {
                // Window not yet matched to any scanned item
                // Ignore if this window belongs to Cove itself (e.g. from an old or current instance)
                if win.ownerName == "Cove" { continue }

                var resolvedName = "Status Item"
                var resolvedIcon: NSImage? = nil
                var resolvedSymbol: String? = "menubar.dock.rectangle"
                var axElement: AXUIElement? = nil
                var isClickable = false
                var resolvedPID: pid_t = win.ownerPID
                var resolvedBundleID: String? = nil

                // Try hit-testing systemWide at this coordinate
                if isTrusted {
                    let sysWide = AXUIElementCreateSystemWide()
                    var hitElement: AXUIElement?
                    let hitResult = AXUIElementCopyElementAtPosition(sysWide, Float(win.bounds.midX), Float(win.bounds.midY), &hitElement)
                    if hitResult == .success, let elem = hitElement {
                        axElement = elem
                        isClickable = AXHelper.supportsPressAction(elem)

                        let title = AXHelper.getTitle(elem)
                        let desc = AXHelper.getDescription(elem)
                        let info = resolveIdentity(element: elem, title: title, desc: desc, runningApps: runningApps)
                        if info.ownerName != "Status Item" {
                            resolvedName = info.ownerName
                            resolvedIcon = info.icon
                            resolvedSymbol = info.systemSymbol
                            resolvedPID = info.ownerPID ?? win.ownerPID
                            resolvedBundleID = info.bundleID
                        }
                    }
                }

                // If window owner is not Control Center, use the owner process name directly
                if resolvedName == "Status Item" && win.ownerPID != ccApp?.processIdentifier {
                    if let app = runningApps.first(where: { $0.processIdentifier == win.ownerPID }) {
                        resolvedName = app.localizedName ?? win.ownerName
                        resolvedIcon = app.icon
                        resolvedBundleID = app.bundleIdentifier
                        resolvedSymbol = nil
                    } else if !win.ownerName.isEmpty && win.ownerName != "Unknown" {
                        resolvedName = win.ownerName
                    }
                }

                // Ignore if it's Cove
                if resolvedName == "Cove" || resolvedBundleID == "com.cove.app" {
                    continue
                }

                let fallbackID = "\(resolvedPID)_\(Int(win.bounds.minX))_\(Int(win.bounds.minY))"
                if seenIDs.insert(fallbackID).inserted {
                    scannedItems.append(MenuBarItem(
                        id: fallbackID,
                        title: resolvedName,
                        itemDescription: "Status Item",
                        frame: win.bounds,
                        ownerName: resolvedName,
                        ownerPID: resolvedPID,
                        bundleIdentifier: resolvedBundleID,
                        icon: resolvedIcon,
                        systemSymbolName: resolvedSymbol,
                        accessibilityElement: axElement,
                        overflowState: .unknown,
                        isClickable: isClickable
                    ))
                }
            }
        }

        // Filter out zero-dimension items and Cove items
        let validItems = scannedItems.filter { item in
            item.frame.width > 2 && item.frame.height > 2 &&
            item.ownerName != "Cove" &&
            item.bundleIdentifier != "com.cove.app" &&
            item.title != "Cove"
        }

        // Sort items from left to right (increasing minX)
        var result = validItems
        result.sort { $0.frame.minX < $1.frame.minX }

        AppLog.scanner.info("Scan completed with \(result.count, privacy: .public) valid items")
        return result
    }

    private func isAllowedItem(_ item: MenuBarItem, currentPID: pid_t) -> Bool {
        guard item.ownerPID != currentPID,
              item.bundleIdentifier != "com.cove.app",
              item.ownerName != "Cove",
              item.title != "Cove" else {
            return false
        }
        return true
    }

    // MARK: - Control Center Scanning

    private func scanControlCenter(app: NSRunningApplication, runningApps: [NSRunningApplication]) -> [MenuBarItem] {
        let appElement = AXUIElementCreateApplication(app.processIdentifier)
        var items: [MenuBarItem] = []

        // Try kAXChildrenAttribute for MenuBar
        var childrenVal: AnyObject?
        if AXUIElementCopyAttributeValue(appElement, kAXChildrenAttribute as CFString, &childrenVal) == .success,
           let children = childrenVal as? [AXUIElement] {
            for child in children {
                var roleVal: AnyObject?
                AXUIElementCopyAttributeValue(child, kAXRoleAttribute as CFString, &roleVal)
                if (roleVal as? String) == (kAXMenuBarRole as String) {
                    var mbChildrenVal: AnyObject?
                    if AXUIElementCopyAttributeValue(child, kAXChildrenAttribute as CFString, &mbChildrenVal) == .success,
                       let mbChildren = mbChildrenVal as? [AXUIElement] {
                        for itemElem in mbChildren {
                            if let item = makeResolvedItem(element: itemElem, runningApps: runningApps) {
                                items.append(item)
                            }
                        }
                    }
                }
            }
        }

        return items
    }

    // MARK: - SystemUIServer Scanning

    private func scanSystemUIServer(app: NSRunningApplication, runningApps: [NSRunningApplication]) -> [MenuBarItem] {
        let appElement = AXUIElementCreateApplication(app.processIdentifier)
        var items: [MenuBarItem] = []

        let topChildren = AXHelper.getChildren(appElement)
        for child in topChildren {
            let role = AXHelper.getRole(child)
            if role == (kAXMenuBarRole as String) {
                let subChildren = AXHelper.getChildren(child)
                for sc in subChildren {
                    if let item = makeResolvedItem(element: sc, runningApps: runningApps) {
                        items.append(item)
                    }
                }
            } else if role == (kAXMenuBarItemRole as String) || role == "AXMenuExtra" {
                if let item = makeResolvedItem(element: child, runningApps: runningApps) {
                    items.append(item)
                }
            }
        }

        return items
    }

    // MARK: - Third-Party App Process Scanning

    public func scanApplicationForStatusItems(app: NSRunningApplication) -> [MenuBarItem] {
        return scanAppProcess(app: app)
    }

    private func scanAppProcess(app: NSRunningApplication) -> [MenuBarItem] {
        let appElement = AXUIElementCreateApplication(app.processIdentifier)
        var items: [MenuBarItem] = []

        // 1. Check "AXExtrasMenuBar" (the dedicated attribute for status bar extras)
        var extrasVal: AnyObject?
        if AXUIElementCopyAttributeValue(appElement, "AXExtrasMenuBar" as CFString, &extrasVal) == .success,
           let extras = extrasVal {
            let chs = AXHelper.getChildren(extras as! AXUIElement)
            for child in chs {
                if let item = makeItemForApp(element: child, app: app) {
                    items.append(item)
                }
            }
        }

        // 2. Check top children strictly for subroles "AXStatusItem" or "AXMenuExtra"
        let topChildren = AXHelper.getChildren(appElement)
        for child in topChildren {
            let role = AXHelper.getRole(child)
            let subrole = AXHelper.getSubrole(child)

            if subrole == "AXStatusItem" || subrole == "AXMenuExtra" || role == "AXMenuExtra" {
                if let item = makeItemForApp(element: child, app: app) {
                    items.append(item)
                }
            }
        }

        return items
    }

    // MARK: - Identity Resolution Helpers

    private func makeResolvedItem(element: AXUIElement, runningApps: [NSRunningApplication]) -> MenuBarItem? {
        let title = AXHelper.getTitle(element)
        let desc = AXHelper.getDescription(element)
        let frame = AXHelper.getFrame(element) ?? .zero
        let isClickable = AXHelper.supportsPressAction(element)

        // Ignore placeholder items with zero frame and empty descriptions
        if frame.width <= 0 && frame.height <= 0 && (desc == nil || desc!.isEmpty) {
            return nil
        }

        let identity = resolveIdentity(element: element, title: title, desc: desc, runningApps: runningApps)
        let id = "\(identity.ownerPID ?? 0)_\(identity.ownerName)_\(Int(frame.minX))_\(Int(frame.minY))"

        return MenuBarItem(
            id: id,
            title: identity.resolvedTitle,
            itemDescription: (desc != nil && desc != identity.ownerName) ? desc : nil,
            frame: frame,
            ownerName: identity.ownerName,
            ownerPID: identity.ownerPID,
            bundleIdentifier: identity.bundleID,
            icon: identity.icon,
            systemSymbolName: identity.systemSymbol,
            accessibilityElement: element,
            overflowState: .unknown,
            isClickable: isClickable
        )
    }

    private func makeItemForApp(element: AXUIElement, app: NSRunningApplication) -> MenuBarItem? {
        let title = AXHelper.getTitle(element)
        let desc = AXHelper.getDescription(element)
        let frame = AXHelper.getFrame(element) ?? .zero
        let isClickable = AXHelper.supportsPressAction(element)

        let appName = app.localizedName ?? "App"
        let displayTitle = (title != nil && !title!.isEmpty) ? title! : appName
        let id = "\(app.processIdentifier)_\(appName)_\(Int(frame.minX))_\(Int(frame.minY))"

        return MenuBarItem(
            id: id,
            title: displayTitle,
            itemDescription: desc,
            frame: frame,
            ownerName: appName,
            ownerPID: app.processIdentifier,
            bundleIdentifier: app.bundleIdentifier,
            icon: app.icon,
            systemSymbolName: nil,
            accessibilityElement: element,
            overflowState: .unknown,
            isClickable: isClickable
        )
    }

    private struct ResolvedIdentity {
        let ownerName: String
        let ownerPID: pid_t?
        let bundleID: String?
        let icon: NSImage?
        let resolvedTitle: String
        let systemSymbol: String?
    }

    private func resolveIdentity(
        element: AXUIElement,
        title: String?,
        desc: String?,
        runningApps: [NSRunningApplication]
    ) -> ResolvedIdentity {
        let rawText = [title, desc].compactMap { $0 }.joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)

        // 1. Try matching against running third-party applications (non-Apple)
        for app in runningApps {
            guard let appName = app.localizedName, appName.count >= 2 else { continue }
            guard let bundleID = app.bundleIdentifier, !bundleID.hasPrefix("com.apple.") else { continue }

            if rawText.localizedCaseInsensitiveContains(appName) ||
               (title?.localizedCaseInsensitiveContains(appName) == true) ||
               (desc?.localizedCaseInsensitiveContains(appName) == true) {
                return ResolvedIdentity(
                    ownerName: appName,
                    ownerPID: app.processIdentifier,
                    bundleID: app.bundleIdentifier,
                    icon: app.icon,
                    resolvedTitle: title ?? appName,
                    systemSymbol: nil
                )
            }
        }

        // 2. Try matching known Apple System Items
        let lower = rawText.lowercased()

        // Handle both standard hyphen and Unicode non-breaking hyphen (\u{2011})
        if lower.contains("wi-fi") || lower.contains("wi‑fi") || lower.contains("wlan") || lower.contains("wifi") {
            return ResolvedIdentity(ownerName: "Wi-Fi", ownerPID: nil, bundleID: "com.apple.wifi", icon: nil, resolvedTitle: "Wi-Fi", systemSymbol: "wifi")
        }
        if lower.contains("电池") || lower.contains("battery") || lower.contains("power") {
            return ResolvedIdentity(ownerName: "Battery", ownerPID: nil, bundleID: nil, icon: nil, resolvedTitle: "Battery", systemSymbol: "battery.100")
        }
        if lower.contains("声音") || lower.contains("音量") || lower.contains("sound") || lower.contains("volume") {
            return ResolvedIdentity(ownerName: "Sound", ownerPID: nil, bundleID: nil, icon: nil, resolvedTitle: "Sound", systemSymbol: "speaker.wave.2")
        }
        if lower.contains("控制中心") || lower.contains("control center") {
            return ResolvedIdentity(ownerName: "Control Center", ownerPID: nil, bundleID: "com.apple.controlcenter", icon: nil, resolvedTitle: "Control Center", systemSymbol: "switch.2")
        }
        if lower.contains("聚焦") || lower.contains("spotlight") {
            return ResolvedIdentity(ownerName: "Spotlight", ownerPID: nil, bundleID: "com.apple.Spotlight", icon: nil, resolvedTitle: "Spotlight", systemSymbol: "magnifyingglass")
        }
        if lower.contains("时钟") || lower.contains("clock") || rawText.range(of: #"^\d{1,2}:\d{2}"#, options: .regularExpression) != nil {
            return ResolvedIdentity(ownerName: "Clock", ownerPID: nil, bundleID: nil, icon: nil, resolvedTitle: title ?? "Clock", systemSymbol: "clock")
        }
        if lower.contains("输入") || lower.contains("拼音") || lower.contains("input") || lower.contains("keyboard") || lower.contains("abc") {
            return ResolvedIdentity(ownerName: "Input Source", ownerPID: nil, bundleID: nil, icon: nil, resolvedTitle: "Input Source", systemSymbol: "character.bubble")
        }
        if lower.contains("隔空播放") || lower.contains("屏幕镜像") || lower.contains("airplay") {
            return ResolvedIdentity(ownerName: "AirPlay", ownerPID: nil, bundleID: nil, icon: nil, resolvedTitle: "AirPlay", systemSymbol: "airplayvideo")
        }
        if lower.contains("蓝牙") || lower.contains("bluetooth") {
            return ResolvedIdentity(ownerName: "Bluetooth", ownerPID: nil, bundleID: nil, icon: nil, resolvedTitle: "Bluetooth", systemSymbol: "wave.3.right")
        }
        if lower.contains("勿扰") || lower.contains("专注") || lower.contains("focus") {
            return ResolvedIdentity(ownerName: "Focus", ownerPID: nil, bundleID: nil, icon: nil, resolvedTitle: "Focus", systemSymbol: "moon.fill")
        }

        // 3. Fallback: Generic or unidentified item
        let fallbackName = title ?? desc ?? "Status Item"
        return ResolvedIdentity(
            ownerName: fallbackName,
            ownerPID: nil,
            bundleID: nil,
            icon: nil,
            resolvedTitle: fallbackName,
            systemSymbol: "menubar.dock.rectangle"
        )
    }
}
