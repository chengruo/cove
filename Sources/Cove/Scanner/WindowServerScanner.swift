import AppKit
import CoreGraphics
import OSLog

public struct WindowServerStatusItem: Sendable {
    public let windowID: CGWindowID
    public let ownerPID: pid_t
    public let ownerName: String
    public let bounds: CGRect
    public let layer: Int
}

public final class WindowServerScanner: Sendable {
    public static let shared = WindowServerScanner()

    public init() {}

    /// Scans WindowServer for active status bar item windows (layer 25).
    public func scanStatusWindows() -> [WindowServerStatusItem] {
        guard let windowInfoList = CGWindowListCopyWindowInfo([.optionAll], kCGNullWindowID) as? [[String: Any]] else {
            AppLog.scanner.error("Failed to copy CGWindowList")
            return []
        }

        var results: [WindowServerStatusItem] = []

        for info in windowInfoList {
            let layer = info[kCGWindowLayer as String] as? Int ?? 0

            // Status items are rendered at layer 25 (kCGStatusWindowLevel)
            guard layer == 25 else { continue }

            let windowID = info[kCGWindowNumber as String] as? CGWindowID ?? 0
            let ownerPID = info[kCGWindowOwnerPID as String] as? pid_t ?? 0
            let ownerName = info[kCGWindowOwnerName as String] as? String ?? "Unknown"

            guard let boundsDict = info[kCGWindowBounds as String] as? [String: Any],
                  let rect = CGRect(dictionaryRepresentation: boundsDict as CFDictionary) else {
                continue
            }

            // Exclude zero-width or hidden background windows
            guard rect.width > 2 && rect.height > 2 else { continue }

            results.append(WindowServerStatusItem(
                windowID: windowID,
                ownerPID: ownerPID,
                ownerName: ownerName,
                bounds: rect,
                layer: layer
            ))
        }

        // Sort items from right to left (descending minX), standard for macOS status items
        results.sort { $0.bounds.minX > $1.bounds.minX }
        AppLog.scanner.debug("WindowServer found \(results.count, privacy: .public) status item windows")
        return results
    }
}
