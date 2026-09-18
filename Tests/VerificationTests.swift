import Foundation
import AppKit
import CoreGraphics
import ApplicationServices

// Import/define components to verify
func testNotchDetection() {
    print("--- [TEST 1] Notch Detection ---")
    let screen = NSScreen.screens.first!
    print("Screen Frame: \(screen.frame)")
    print("Screen VisibleFrame: \(screen.visibleFrame)")
    print("Screen SafeAreaInsets: \(screen.safeAreaInsets)")

    let detector = NotchDetector.shared
    let geometry = detector.detect(for: screen)

    print("Geometry HasNotch: \(geometry.hasNotch)")
    print("Left Available Area: \(geometry.leftAvailableArea)")
    print("Notch Area: \(geometry.notchArea)")
    print("Right Available Area: \(geometry.rightAvailableArea)")

    if geometry.hasNotch {
        assert(geometry.notchArea.width > 0, "Notch width must be positive")
        assert(geometry.rightAvailableArea.minX > geometry.leftAvailableArea.maxX, "Right area must start after left area")
        assert(abs(geometry.leftAvailableArea.maxX - geometry.notchArea.minX) < 1.0, "Left area must meet notch start")
        assert(abs(geometry.notchArea.maxX - geometry.rightAvailableArea.minX) < 1.0, "Notch end must meet right area start")
        print("✅ Notch geometric continuity verified!")
    } else {
        print("✅ Standard display geometry verified!")
    }
}

func testOverflowDetection() {
    print("\n--- [TEST 2] Overflow Detection ---")
    let detector = OverflowDetector.shared
    let screenGeom = NotchDetector.shared.detect()

    // Test Case A: Item in normal right safe area (e.g. x = 1100, width = 30)
    let visibleItem = MenuBarItem(
        id: "visible_1",
        frame: CGRect(x: 1100, y: 0, width: 30, height: 32)
    )
    let stateA = detector.evaluate(item: visibleItem, geometry: screenGeom)
    print("Item at x=1100 -> State: \(stateA)")
    assert(stateA == .visible, "Item at x=1100 should be visible")

    if screenGeom.hasNotch {
        // Test Case B: Item intersecting the notch
        let notchMidX = screenGeom.notchArea.midX
        let intersectingItem = MenuBarItem(
            id: "notch_intersect",
            frame: CGRect(x: notchMidX - 15, y: 0, width: 30, height: 32)
        )
        let stateB = detector.evaluate(item: intersectingItem, geometry: screenGeom)
        print("Item at notch center (x=\(notchMidX)) -> State: \(stateB)")
        assert(stateB == .overflowed, "Item intersecting notch must be overflowed")

        // Test Case C: Item pushed to the left of the right safe area
        let pushedItem = MenuBarItem(
            id: "pushed_left",
            frame: CGRect(x: screenGeom.rightAvailableArea.minX - 50, y: 0, width: 30, height: 32)
        )
        let stateC = detector.evaluate(item: pushedItem, geometry: screenGeom)
        print("Item pushed left of right area (x=\(pushedItem.frame.minX)) -> State: \(stateC)")
        assert(stateC == .overflowed, "Item pushed left of right safe area must be overflowed")
    }

    // Test Case D: Off-screen item (negative X)
    let offscreenItem = MenuBarItem(
        id: "offscreen",
        frame: CGRect(x: -40, y: 0, width: 30, height: 32)
    )
    let stateD = detector.evaluate(item: offscreenItem, geometry: screenGeom)
    print("Item off-screen (x=-40) -> State: \(stateD)")
    assert(stateD == .overflowed, "Off-screen item must be overflowed")

    // Test Case E: Zero-dimension item
    let zeroItem = MenuBarItem(
        id: "zero",
        frame: .zero
    )
    let stateE = detector.evaluate(item: zeroItem, geometry: screenGeom)
    print("Item with zero frame -> State: \(stateE)")
    assert(stateE == .unknown, "Zero frame item must be unknown")

    print("✅ All overflow detection test cases passed!")
}

func testWindowServerScan() {
    print("\n--- [TEST 3] WindowServer Scan ---")
    let scanner = WindowServerScanner.shared
    let items = scanner.scanStatusWindows()
    print("Scanned \(items.count) status item windows from WindowServer.")
    for item in items.prefix(5) {
        print(" - PID: \(item.ownerPID) | Owner: \(item.ownerName) | Bounds: \(item.bounds)")
    }
    assert(!items.isEmpty, "WindowServer should detect existing status bar items")
    print("✅ WindowServer status item scanning passed!")
}

func testMenuBarScanner() {
    print("\n--- [TEST 4] MenuBar Full Scan ---")
    let scanner = MenuBarScanner.shared
    let items = scanner.scan()
    print("Scanned total of \(items.count) MenuBar items.")
    for item in items.prefix(5) {
        print(" - \(item.appName): \(item.displayName) at (\(item.frame.minX), \(item.frame.minY), \(item.frame.width), \(item.frame.height))")
    }
    print("✅ MenuBarScanner full scan completed without crash!")
}

@main
struct TestRunner {
    static func main() {
        print("========================================")
        print("Running Cove Automated Verification Suite")
        print("========================================")
        testNotchDetection()
        testOverflowDetection()
        testWindowServerScan()
        testMenuBarScanner()
        print("\n========================================")
        print("🎉 ALL COVE VERIFICATION TESTS PASSED 🎉")
        print("========================================")
    }
}

