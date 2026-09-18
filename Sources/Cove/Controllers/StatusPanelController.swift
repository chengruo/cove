import AppKit
import SwiftUI
import OSLog

public final class StatusPanel: NSPanel {
    public override var canBecomeKey: Bool {
        return true
    }

    public override var canBecomeMain: Bool {
        return false
    }
}

@MainActor
public final class StatusPanelController: NSObject, NSWindowDelegate {
    public static let shared = StatusPanelController()

    private var panel: StatusPanel?
    private var globalClickMonitor: Any?
    private var localKeyMonitor: Any?

    public private(set) var isVisible: Bool = false

    public override init() {
        super.init()
        setupPanel()
    }

    private func setupPanel() {
        let panel = StatusPanel(
            contentRect: NSRect(x: 0, y: 0, width: 320, height: 300),
            styleMask: [.nonactivatingPanel, .fullSizeContentView, .borderless],
            backing: .buffered,
            defer: false
        )

        panel.isFloatingPanel = true
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.isMovableByWindowBackground = false
        panel.delegate = self

        // Frosted glass Visual Effect backing
        let visualEffectView = NSVisualEffectView()
        visualEffectView.material = .popover
        visualEffectView.blendingMode = .behindWindow
        visualEffectView.state = .active
        visualEffectView.wantsLayer = true
        visualEffectView.layer?.cornerRadius = 12
        visualEffectView.layer?.masksToBounds = true

        let rootView = OverflowPanel { [weak self] in
            self?.hide()
        }
        let hostingView = NSHostingView(rootView: rootView)
        hostingView.translatesAutoresizingMaskIntoConstraints = false

        visualEffectView.addSubview(hostingView)
        NSLayoutConstraint.activate([
            hostingView.topAnchor.constraint(equalTo: visualEffectView.topAnchor),
            hostingView.bottomAnchor.constraint(equalTo: visualEffectView.bottomAnchor),
            hostingView.leadingAnchor.constraint(equalTo: visualEffectView.leadingAnchor),
            hostingView.trailingAnchor.constraint(equalTo: visualEffectView.trailingAnchor)
        ])

        panel.contentView = visualEffectView
        self.panel = panel
    }

    /// Shows or hides the panel relative to the anchor status item view or notch fallback.
    public func toggle(relativeTo statusItemButton: NSStatusBarButton?) {
        if isVisible {
            hide()
        } else {
            show(relativeTo: statusItemButton)
        }
    }

    /// Displays the panel positioned directly beneath the status item button, or below the notch if occluded.
    public func show(relativeTo statusItemButton: NSStatusBarButton?) {
        guard let panel = self.panel else { return }

        let screen = statusItemButton?.window?.screen ?? NSScreen.main ?? NSScreen.screens[0]
        let screenFrame = screen.visibleFrame
        let geometry = NotchDetector.shared.detect(for: screen)
        let panelWidth = panel.frame.width

        var placedUnderButton = false

        if let button = statusItemButton, let window = button.window {
            let buttonFrameOnScreen = window.convertToScreen(button.frame)

            // Verify if button is inside the visible right area (not hidden behind notch)
            let isOccluded = geometry.hasNotch && (buttonFrameOnScreen.minX < geometry.rightAvailableArea.minX || buttonFrameOnScreen.intersects(geometry.notchArea))

            if !isOccluded && buttonFrameOnScreen.width > 0 {
                // Align center of panel with center of status item
                var x = buttonFrameOnScreen.midX - (panelWidth / 2.0)
                if x + panelWidth > screenFrame.maxX - 10 {
                    x = screenFrame.maxX - panelWidth - 10
                }
                if x < screenFrame.minX + 10 {
                    x = screenFrame.minX + 10
                }

                let y = buttonFrameOnScreen.minY - panel.frame.height - 6.0
                panel.setFrameOrigin(NSPoint(x: x, y: y))
                placedUnderButton = true
            }
        }

        // Fallback: If button is occluded by notch or unavailable, place directly below the notch center!
        if !placedUnderButton {
            let x = screen.frame.midX - (panelWidth / 2.0)
            let menuBarH = geometry.menuBarHeight > 0 ? geometry.menuBarHeight : 32.0
            let y = screen.frame.maxY - menuBarH - panel.frame.height - 6.0
            panel.setFrameOrigin(NSPoint(x: x, y: y))
            AppLog.ui.info("Status item occluded by notch or missing; positioned panel beneath notch center")
        }

        panel.orderFrontRegardless()
        isVisible = true

        setupEventMonitors()
        AppLog.ui.info("Status panel displayed")
    }

    /// Hides the panel.
    public func hide() {
        guard isVisible, let panel = self.panel else { return }
        panel.orderOut(nil)
        isVisible = false
        removeEventMonitors()
        AppLog.ui.info("Status panel hidden")
    }

    private func setupEventMonitors() {
        removeEventMonitors()

        // Dismiss on outside click
        globalClickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            guard let self = self, let panel = self.panel else { return }
            let mouseLocation = NSEvent.mouseLocation
            if !panel.frame.contains(mouseLocation) {
                self.hide()
            }
        }

        // Dismiss on Escape key
        localKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.keyCode == 53 { // Escape
                self?.hide()
                return nil
            }
            return event
        }
    }

    private func removeEventMonitors() {
        if let monitor = globalClickMonitor {
            NSEvent.removeMonitor(monitor)
            globalClickMonitor = nil
        }
        if let monitor = localKeyMonitor {
            NSEvent.removeMonitor(monitor)
            localKeyMonitor = nil
        }
    }
}
