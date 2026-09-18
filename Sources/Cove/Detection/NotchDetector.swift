import AppKit
import OSLog

public final class NotchDetector: Sendable {
    public static let shared = NotchDetector()

    public init() {}

    /// Detects notch and menu bar geometry for a specified screen (or current active screen).
    public func detect(for screen: NSScreen? = nil) -> ScreenGeometry {
        let targetScreen = screen ?? NSScreen.main ?? NSScreen.screens.first
        guard let screen = targetScreen else {
            AppLog.notch.warning("No screen available for notch detection")
            return .zero
        }

        let primaryScreenHeight = NSScreen.screens.first?.frame.height ?? screen.frame.height
        let screenFrame = convertToCGCoordinates(screen.frame, primaryScreenHeight: primaryScreenHeight)
        let visibleFrame = convertToCGCoordinates(screen.visibleFrame, primaryScreenHeight: primaryScreenHeight)

        // Menu bar height calculation
        let safeTop = screen.safeAreaInsets.top
        let defaultMenuBarHeight: CGFloat = safeTop > 0 ? safeTop : max(screen.frame.maxY - screen.visibleFrame.maxY, 24.0)

        // Check auxiliary areas (macOS 12+)
        let topLeftArea = screen.auxiliaryTopLeftArea
        let topRightArea = screen.auxiliaryTopRightArea

        if let topLeft = topLeftArea, let topRight = topRightArea, topRight.minX > topLeft.maxX {
            let leftCG = convertToCGCoordinates(topLeft, primaryScreenHeight: primaryScreenHeight)
            let rightCG = convertToCGCoordinates(topRight, primaryScreenHeight: primaryScreenHeight)

            let notchX = leftCG.maxX
            let notchWidth = rightCG.minX - leftCG.maxX
            let notchHeight = max(leftCG.height, rightCG.height, defaultMenuBarHeight)
            let notchCG = CGRect(
                x: notchX,
                y: min(leftCG.minY, rightCG.minY),
                width: notchWidth,
                height: notchHeight
            )

            let geometry = ScreenGeometry(
                screenFrame: screenFrame,
                screenVisibleFrame: visibleFrame,
                menuBarHeight: notchHeight,
                hasNotch: true,
                leftAvailableArea: leftCG,
                notchArea: notchCG,
                rightAvailableArea: rightCG,
                safeAreaTopInset: safeTop
            )

            AppLog.notch.info("Notch detected on screen: notchWidth=\(notchWidth, privacy: .public), rightAreaStartX=\(rightCG.minX, privacy: .public)")
            return geometry
        } else {
            // Screen without notch (external monitor or pre-notch Mac)
            let menuBarY = screenFrame.minY
            let menuBarHeight = defaultMenuBarHeight
            let halfWidth = screenFrame.width / 2.0

            let leftArea = CGRect(
                x: screenFrame.minX,
                y: menuBarY,
                width: halfWidth,
                height: menuBarHeight
            )
            let rightArea = CGRect(
                x: screenFrame.minX + halfWidth,
                y: menuBarY,
                width: halfWidth,
                height: menuBarHeight
            )

            let geometry = ScreenGeometry(
                screenFrame: screenFrame,
                screenVisibleFrame: visibleFrame,
                menuBarHeight: menuBarHeight,
                hasNotch: false,
                leftAvailableArea: leftArea,
                notchArea: .zero,
                rightAvailableArea: rightArea,
                safeAreaTopInset: safeTop
            )

            AppLog.notch.info("No notch on screen \(screen.localizedName): width=\(screenFrame.width, privacy: .public)")
            return geometry
        }
    }

    /// Converts AppKit bottom-left origin coordinate rect to CoreGraphics / AX top-left coordinate rect
    private func convertToCGCoordinates(_ rect: CGRect, primaryScreenHeight: CGFloat) -> CGRect {
        let cgY = primaryScreenHeight - (rect.origin.y + rect.size.height)
        return CGRect(
            x: rect.origin.x,
            y: cgY,
            width: rect.size.width,
            height: rect.size.height
        )
    }
}
