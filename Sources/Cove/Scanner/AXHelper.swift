import AppKit
import ApplicationServices
import OSLog

public enum AXHelper {
    public static func copyAttribute<T>(_ element: AXUIElement, attribute: String) -> T? {
        var value: AnyObject?
        let result = AXUIElementCopyAttributeValue(element, attribute as CFString, &value)
        guard result == .success else {
            return nil
        }
        return value as? T
    }

    public static func getChildren(_ element: AXUIElement) -> [AXUIElement] {
        return copyAttribute(element, attribute: kAXChildrenAttribute) ?? []
    }

    public static func getRole(_ element: AXUIElement) -> String? {
        return copyAttribute(element, attribute: kAXRoleAttribute)
    }

    public static func getSubrole(_ element: AXUIElement) -> String? {
        return copyAttribute(element, attribute: kAXSubroleAttribute)
    }

    public static func getTitle(_ element: AXUIElement) -> String? {
        return copyAttribute(element, attribute: kAXTitleAttribute)
    }

    public static func getDescription(_ element: AXUIElement) -> String? {
        return copyAttribute(element, attribute: kAXDescriptionAttribute)
    }

    public static func getPosition(_ element: AXUIElement) -> CGPoint? {
        var value: AnyObject?
        let result = AXUIElementCopyAttributeValue(element, kAXPositionAttribute as CFString, &value)
        guard result == .success, let val = value else {
            return nil
        }
        guard CFGetTypeID(val) == AXValueGetTypeID() else {
            return nil
        }
        let axVal = val as! AXValue
        var point = CGPoint.zero
        if AXValueGetValue(axVal, .cgPoint, &point) {
            return point
        }
        return nil
    }

    public static func getSize(_ element: AXUIElement) -> CGSize? {
        var value: AnyObject?
        let result = AXUIElementCopyAttributeValue(element, kAXSizeAttribute as CFString, &value)
        guard result == .success, let val = value else {
            return nil
        }
        guard CFGetTypeID(val) == AXValueGetTypeID() else {
            return nil
        }
        let axVal = val as! AXValue
        var size = CGSize.zero
        if AXValueGetValue(axVal, .cgSize, &size) {
            return size
        }
        return nil
    }

    public static func getFrame(_ element: AXUIElement) -> CGRect? {
        guard let pos = getPosition(element), let size = getSize(element) else {
            return nil
        }
        return CGRect(origin: pos, size: size)
    }

    public static func getActionNames(_ element: AXUIElement) -> [String] {
        var actionNames: CFArray?
        let result = AXUIElementCopyActionNames(element, &actionNames)
        guard result == .success, let actions = actionNames as? [String] else {
            return []
        }
        return actions
    }

    public static func supportsPressAction(_ element: AXUIElement) -> Bool {
        let actions = getActionNames(element)
        return actions.contains(kAXPressAction as String)
    }

    public static func isElementValid(_ element: AXUIElement) -> Bool {
        var value: AnyObject?
        let result = AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &value)
        return result != .invalidUIElement && result != .cannotComplete
    }
}
