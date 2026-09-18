import SwiftUI

public struct DebugView: View {
    public let geometry: ScreenGeometry
    public let items: [MenuBarItem]

    public init(geometry: ScreenGeometry, items: [MenuBarItem]) {
        self.geometry = geometry
        self.items = items
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Debug Inspector")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.secondary)

            // Screen Info
            Group {
                Text("Screen: \(Int(geometry.screenFrame.width)) × \(Int(geometry.screenFrame.height)) | SafeTop: \(Int(geometry.safeAreaTopInset))pt")
                Text("Has Notch: \(geometry.hasNotch ? "YES" : "NO")")
                if geometry.hasNotch {
                    Text("Notch: x:\(Int(geometry.notchArea.minX))..\(Int(geometry.notchArea.maxX)) (w:\(Int(geometry.notchArea.width)))")
                    Text("Right Safe Area: x:\(Int(geometry.rightAvailableArea.minX))..\(Int(geometry.rightAvailableArea.maxX))")
                }
            }
            .font(.system(size: 10, design: .monospaced))
            .foregroundColor(.secondary)

            Divider()

            // Item Details
            Text("Items (\(items.count) total):")
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(.secondary)

            ForEach(items.prefix(8)) { item in
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(item.appName) (PID: \(item.ownerPID ?? 0))")
                        .font(.system(size: 10, weight: .medium))
                    Text("State: \(item.overflowState.rawValue) | Frame: (\(Int(item.frame.minX)), \(Int(item.frame.minY)), \(Int(item.frame.width)), \(Int(item.frame.height)))")
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color(nsColor: .controlBackgroundColor).opacity(0.5))
        )
    }
}
