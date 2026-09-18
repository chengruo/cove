import AppKit
import ApplicationServices

public enum OverflowState: String, Codable, Sendable {
    case visible
    case overflowed
    case possiblyHidden
    case unknown

    public var title: String {
        switch self {
        case .visible:
            return "Visible"
        case .overflowed:
            return "Hidden by Notch"
        case .possiblyHidden:
            return "Possibly Hidden"
        case .unknown:
            return "Unknown"
        }
    }
}

public enum ActionState: Equatable, Sendable {
    case normal
    case triggering
    case success
    case failed(String)
}

public struct MenuBarItem: Identifiable, @unchecked Sendable {
    public let id: String
    public let title: String?
    public let itemDescription: String?
    public let frame: CGRect
    public let ownerName: String?
    public let ownerPID: pid_t?
    public let bundleIdentifier: String?
    public let icon: NSImage?
    public let systemSymbolName: String?
    public let accessibilityElement: AXUIElement?

    public var overflowState: OverflowState
    public var isClickable: Bool
    public var actionState: ActionState

    public init(
        id: String,
        title: String? = nil,
        itemDescription: String? = nil,
        frame: CGRect,
        ownerName: String? = nil,
        ownerPID: pid_t? = nil,
        bundleIdentifier: String? = nil,
        icon: NSImage? = nil,
        systemSymbolName: String? = nil,
        accessibilityElement: AXUIElement? = nil,
        overflowState: OverflowState = .unknown,
        isClickable: Bool = true,
        actionState: ActionState = .normal
    ) {
        self.id = id
        self.title = title
        self.itemDescription = itemDescription
        self.frame = frame
        self.ownerName = ownerName
        self.ownerPID = ownerPID
        self.bundleIdentifier = bundleIdentifier
        self.icon = icon
        self.systemSymbolName = systemSymbolName
        self.accessibilityElement = accessibilityElement
        self.overflowState = overflowState
        self.isClickable = isClickable
        self.actionState = actionState
    }

    public var displayName: String {
        if let title = title, !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return title
        }
        if let desc = itemDescription, !desc.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return desc
        }
        if let owner = ownerName, !owner.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return owner
        }
        return "Status Item"
    }

    public var appName: String {
        if let owner = ownerName, !owner.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return owner
        }
        return "System"
    }
}

extension MenuBarItem: Equatable {
    public static func == (lhs: MenuBarItem, rhs: MenuBarItem) -> Bool {
        lhs.id == rhs.id &&
        lhs.frame == rhs.frame &&
        lhs.overflowState == rhs.overflowState &&
        lhs.isClickable == rhs.isClickable &&
        lhs.actionState == rhs.actionState
    }
}
