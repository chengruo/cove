import SwiftUI

public struct PermissionView: View {
    @ObservedObject var accessibilityManager = AccessibilityManager.shared
    @State private var timer: Timer?

    public init() {}

    public var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "lock.shield.fill")
                .font(.system(size: 36))
                .foregroundColor(.accentColor)
                .padding(.top, 4)

            VStack(spacing: 4) {
                Text("Accessibility Access Required")
                    .font(.headline)
                    .multilineTextAlignment(.center)

                Text("Cove needs Accessibility permission to detect and interact with status bar items behind the notch.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 8)

            // Action Buttons
            VStack(spacing: 8) {
                Button(action: {
                    accessibilityManager.requestPermission()
                }) {
                    HStack(spacing: 6) {
                        Text("1. Open System Settings")
                        Image(systemName: "arrow.up.forward.app")
                            .font(.caption)
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.regular)

                Button(action: {
                    accessibilityManager.revealAppInFinder()
                }) {
                    HStack(spacing: 6) {
                        Text("2. Reveal Cove in Finder")
                        Image(systemName: "folder")
                            .font(.caption)
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .help("If Cove is not listed in Settings, drag it from Finder into the Accessibility list")

                Button(action: {
                    accessibilityManager.relaunchApp()
                }) {
                    HStack(spacing: 6) {
                        Text("Restart Cove to Apply")
                        Image(systemName: "arrow.clockwise")
                            .font(.caption)
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)
                .font(.system(size: 11))
                .foregroundColor(.accentColor)
                .padding(.top, 2)
            }

            // Tip Box
            VStack(alignment: .leading, spacing: 3) {
                Text("💡 Manual Setup Guide:")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.primary)
                Text("• If Cove is not in the list, click the '+' button in System Settings, or drag Cove.app into the list.")
                Text("• After toggling ON, if macOS doesn't update immediately, click 'Restart Cove to Apply'.")
            }
            .font(.system(size: 10))
            .foregroundColor(.secondary)
            .padding(8)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.secondary.opacity(0.1))
            )
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .onAppear {
            startPolling()
        }
        .onDisappear {
            timer?.invalidate()
            timer = nil
        }
    }

    private func startPolling() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1.2, repeats: true) { _ in
            Task { @MainActor in
                _ = accessibilityManager.checkPermissionStatus()
            }
        }
    }
}
