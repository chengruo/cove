import AppKit
import OSLog

public final class OverflowDetector: Sendable {
    public static let shared = OverflowDetector()

    public init() {}

    /// Evaluates the overflow state of an item against the given screen geometry.
    public func evaluate(item: MenuBarItem, geometry: ScreenGeometry) -> OverflowState {
        let frame = item.frame

        // 1. Check for invalid or zero frame
        if frame.width <= 0 || frame.height <= 0 {
            AppLog.overflow.debug("Item \(item.id, privacy: .public) has zero or negative frame dimensions -> unknown")
            return .unknown
        }

        // 2. Off-screen check (completely pushed outside the screen)
        if frame.maxX <= geometry.screenFrame.minX || frame.minX >= geometry.screenFrame.maxX {
            AppLog.overflow.info("Item \(item.id, privacy: .public) is off-screen (frame: \(frame.debugDescription, privacy: .public)) -> overflowed")
            return .overflowed
        }

        // 3. Screen with Notch
        if geometry.hasNotch {
            let notch = geometry.notchArea
            let rightArea = geometry.rightAvailableArea

            // Direct intersection with the notch cutout
            if frame.intersects(notch) {
                AppLog.overflow.info("Item \(item.id, privacy: .public) intersects notch area -> overflowed")
                return .overflowed
            }

            // Placed behind or inside the notch boundaries
            if frame.minX >= notch.minX && frame.maxX <= notch.maxX {
                AppLog.overflow.info("Item \(item.id, privacy: .public) is inside notch X range -> overflowed")
                return .overflowed
            }

            // Pushed to the left of the right available area (into notch or beyond)
            // macOS status bar grows right-to-left. Items with minX < rightArea.minX are cut off.
            if frame.minX < rightArea.minX {
                AppLog.overflow.info("Item \(item.id, privacy: .public) minX (\(frame.minX, privacy: .public)) < rightArea.minX (\(rightArea.minX, privacy: .public)) -> overflowed")
                return .overflowed
            }

            // Normal visible status item within the right available area
            if frame.minX >= rightArea.minX - 2.0 && frame.maxX <= geometry.screenFrame.maxX + 5.0 {
                return .visible
            }

            // Boundary edge case
            AppLog.overflow.debug("Item \(item.id, privacy: .public) near boundary -> possiblyHidden")
            return .possiblyHidden
        } else {
            // 4. Non-notch screen: items overflow if pushed past available width
            if frame.minX < geometry.screenFrame.minX {
                return .overflowed
            }

            return .visible
        }
    }

    /// Evaluates a list of items, updating their overflow state.
    public func evaluateAll(items: [MenuBarItem], geometry: ScreenGeometry) -> [MenuBarItem] {
        return items.map { item in
            var updated = item
            updated.overflowState = evaluate(item: item, geometry: geometry)
            return updated
        }
    }
}
