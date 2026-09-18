import AppKit

public struct ScreenGeometry: Equatable, Sendable {
    public let screenFrame: CGRect
    public let screenVisibleFrame: CGRect
    public let menuBarHeight: CGFloat
    public let hasNotch: Bool
    public let leftAvailableArea: CGRect
    public let notchArea: CGRect
    public let rightAvailableArea: CGRect
    public let safeAreaTopInset: CGFloat

    public init(
        screenFrame: CGRect,
        screenVisibleFrame: CGRect,
        menuBarHeight: CGFloat,
        hasNotch: Bool,
        leftAvailableArea: CGRect,
        notchArea: CGRect,
        rightAvailableArea: CGRect,
        safeAreaTopInset: CGFloat
    ) {
        self.screenFrame = screenFrame
        self.screenVisibleFrame = screenVisibleFrame
        self.menuBarHeight = menuBarHeight
        self.hasNotch = hasNotch
        self.leftAvailableArea = leftAvailableArea
        self.notchArea = notchArea
        self.rightAvailableArea = rightAvailableArea
        self.safeAreaTopInset = safeAreaTopInset
    }

    public static let zero = ScreenGeometry(
        screenFrame: .zero,
        screenVisibleFrame: .zero,
        menuBarHeight: 24,
        hasNotch: false,
        leftAvailableArea: .zero,
        notchArea: .zero,
        rightAvailableArea: .zero,
        safeAreaTopInset: 0
    )
}
