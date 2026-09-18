import Foundation
import OSLog

public enum AppLog {
    private static let subsystem = "com.cove.app"

    public static let app = Logger(subsystem: subsystem, category: "App")
    public static let accessibility = Logger(subsystem: subsystem, category: "Accessibility")
    public static let scanner = Logger(subsystem: subsystem, category: "Scanner")
    public static let notch = Logger(subsystem: subsystem, category: "Notch")
    public static let overflow = Logger(subsystem: subsystem, category: "Overflow")
    public static let action = Logger(subsystem: subsystem, category: "Action")
    public static let ui = Logger(subsystem: subsystem, category: "UI")
}
