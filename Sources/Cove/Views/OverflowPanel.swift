import SwiftUI
import AppKit

public struct OverflowPanel: View {
    @ObservedObject var accessibilityManager = AccessibilityManager.shared
    @ObservedObject var launchManager = LaunchAtLoginManager.shared

    @State private var items: [MenuBarItem] = []
    @State private var geometry: ScreenGeometry = .zero
    @State private var showAllItems: Bool = false
    @State private var showDebug: Bool = false
    @State private var isRefreshing: Bool = false
    @State private var autoRefreshEnabled: Bool = true
    @State private var autoRefreshTimer: Timer? = nil

    public let onDismissRequest: () -> Void

    public init(onDismissRequest: @escaping () -> Void = {}) {
        self.onDismissRequest = onDismissRequest
    }

    private var overflowedItems: [MenuBarItem] {
        items.filter { $0.overflowState == .overflowed || $0.overflowState == .possiblyHidden }
    }

    private var displayedItems: [MenuBarItem] {
        if showAllItems || !geometry.hasNotch {
            return items
        } else {
            return overflowedItems
        }
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView
                .padding(.horizontal, 14)
                .padding(.top, 14)
                .padding(.bottom, 10)

            Divider()
                .opacity(0.5)

            // Content Area
            if !accessibilityManager.isTrusted {
                PermissionView()
            } else if displayedItems.isEmpty {
                EmptyStateView(
                    message: geometry.hasNotch ? "No Hidden Items" : "No Menu Bar Items Detected",
                    subtitle: geometry.hasNotch
                        ? "All menu bar items are currently visible on screen."
                        : "Use the refresh button to re-scan status items."
                )
            } else {
                ScrollView(.vertical, showsIndicators: true) {
                    LazyVStack(spacing: 2) {
                        ForEach(displayedItems) { item in
                            MenuBarItemView(item: item) { clickedItem in
                                handleItemClick(clickedItem)
                            }
                        }
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 6)
                }
                .frame(maxHeight: 380)
            }

            // Optional Debug Inspector
            if showDebug {
                Divider().opacity(0.5)
                ScrollView(.vertical) {
                    DebugView(geometry: geometry, items: items)
                }
                .frame(maxHeight: 200)
                .padding(8)
            }

            // Footer
            Divider().opacity(0.5)
            footerView
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
        }
        .frame(width: 320)
        .background(Color(nsColor: .windowBackgroundColor).opacity(0.85))
        .onAppear {
            refresh(isBackground: false)
            startAutoRefresh()
        }
        .onDisappear {
            stopAutoRefresh()
        }
        .onReceive(NotificationCenter.default.publisher(for: .requestMenuBarRefresh)) { _ in
            refresh(isBackground: true)
        }
    }

    // MARK: - Subviews

    private var headerView: some View {
        HStack(alignment: .center, spacing: 8) {
            Image(systemName: "menubar.dock.rectangle")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.accentColor)

            VStack(alignment: .leading, spacing: 1) {
                Text("Hidden Menu Bar")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.primary)

                if accessibilityManager.isTrusted {
                    Text(statusSubtitle)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            // Refresh Button
            Button(action: {
                refresh(isBackground: false)
            }) {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 12, weight: .medium))
                    .rotationEffect(.degrees(isRefreshing ? 360 : 0))
                    .animation(isRefreshing ? .linear(duration: 0.8).repeatForever(autoreverses: false) : .default, value: isRefreshing)
            }
            .buttonStyle(.plain)
            .foregroundColor(.secondary)
            .help("Refresh menu bar items")

            // Scope & Settings Menu
            Menu {
                Toggle("Show All Items", isOn: $showAllItems)
                Toggle("Auto Refresh (2s)", isOn: Binding(
                    get: { autoRefreshEnabled },
                    set: { enabled in
                        autoRefreshEnabled = enabled
                        if enabled {
                            startAutoRefresh()
                        } else {
                            stopAutoRefresh()
                        }
                    }
                ))
                Toggle("Launch at Login (开机自启)", isOn: Binding(
                    get: { launchManager.isEnabled },
                    set: { enabled in
                        launchManager.setEnabled(enabled)
                    }
                ))
                Toggle("Debug Inspector", isOn: $showDebug)

                Divider()

                Button("Accessibility Settings…") {
                    accessibilityManager.openAccessibilitySettings()
                }

                if launchManager.requiresApproval {
                    Button("Login Items Settings…") {
                        launchManager.openSystemSettings()
                    }
                }

                Divider()

                Button("Quit Cove") {
                    NSApplication.shared.terminate(nil)
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
        }
    }

    private var footerView: some View {
        HStack {
            if geometry.hasNotch {
                HStack(spacing: 4) {
                    Circle()
                        .fill(Color.orange.opacity(0.8))
                        .frame(width: 6, height: 6)
                    Text("Notch Active")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
            } else {
                HStack(spacing: 4) {
                    Circle()
                        .fill(Color.green.opacity(0.8))
                        .frame(width: 6, height: 6)
                    Text("Standard Screen")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            // Shortcut Hint
            Text("⌃⌥C")
                .font(.system(size: 9, weight: .medium, design: .monospaced))
                .foregroundColor(.secondary)
                .padding(.horizontal, 4)
                .padding(.vertical, 2)
                .background(
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.secondary.opacity(0.15))
                )
                .help("Global shortcut to toggle Cove (⌃⌥C)")

            if geometry.hasNotch && !showAllItems {
                Button(action: {
                    showAllItems = true
                }) {
                    Text("View All (\(items.count))")
                        .font(.system(size: 10))
                        .foregroundColor(.accentColor)
                }
                .buttonStyle(.plain)
            } else if showAllItems {
                Button(action: {
                    showAllItems = false
                }) {
                    Text("Hidden Only")
                        .font(.system(size: 10))
                        .foregroundColor(.accentColor)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var statusSubtitle: String {
        if !geometry.hasNotch {
            return "\(items.count) items detected"
        }
        let count = overflowedItems.count
        if count == 0 {
            return "No items hidden"
        } else if count == 1 {
            return "1 item hidden behind notch"
        } else {
            return "\(count) items hidden behind notch"
        }
    }

    // MARK: - Actions & Auto Refresh

    public func refresh(isBackground: Bool = false) {
        if !isBackground {
            isRefreshing = true
        }

        _ = accessibilityManager.checkPermissionStatus()

        let currentGeometry = NotchDetector.shared.detect()
        self.geometry = currentGeometry

        let scanned = MenuBarScanner.shared.scan()
        let evaluated = OverflowDetector.shared.evaluateAll(items: scanned, geometry: currentGeometry)

        withAnimation(.easeInOut(duration: 0.15)) {
            self.items = evaluated
        }

        if !isBackground {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                isRefreshing = false
            }
        }
    }

    private func startAutoRefresh() {
        stopAutoRefresh()
        guard autoRefreshEnabled else { return }

        autoRefreshTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { _ in
            Task { @MainActor in
                refresh(isBackground: true)
            }
        }
    }

    private func stopAutoRefresh() {
        autoRefreshTimer?.invalidate()
        autoRefreshTimer = nil
    }

    private func handleItemClick(_ item: MenuBarItem) {
        accessibilityManager.performPress(item: item) { result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    // Dismiss our panel on successful press so target popover/menu can take focus
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                        onDismissRequest()
                    }
                case .failure:
                    break
                }
            }
        }
    }
}
