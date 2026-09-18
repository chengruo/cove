import SwiftUI
import AppKit

public struct MenuBarItemView: View {
    public let item: MenuBarItem
    public let onItemClicked: (MenuBarItem) -> Void

    @State private var isHovered: Bool = false
    @State private var isTriggering: Bool = false
    @State private var errorMessage: String? = nil

    public init(item: MenuBarItem, onItemClicked: @escaping (MenuBarItem) -> Void) {
        self.item = item
        self.onItemClicked = onItemClicked
    }

    public var body: some View {
        Button(action: {
            handleTap()
        }) {
            HStack(spacing: 10) {
                // Application / Item Icon
                iconView
                    .frame(width: 20, height: 20)

                // App Name and Info
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.appName)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.primary)
                        .lineLimit(1)

                    if item.displayName != item.appName {
                        Text(item.displayName)
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    } else if let desc = item.itemDescription, desc != "Status Item" {
                        Text(desc)
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }

                Spacer(minLength: 8)

                // Trailing Action Indicator
                if isTriggering {
                    ProgressView()
                        .controlSize(.mini)
                } else if let error = errorMessage {
                    Text(error)
                        .font(.system(size: 10))
                        .foregroundColor(.red)
                        .lineLimit(1)
                } else {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.secondary.opacity(0.6))
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(isHovered ? Color(nsColor: .selectedContentBackgroundColor).opacity(0.15) : Color.clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.12)) {
                isHovered = hovering
            }
        }
    }

    @ViewBuilder
    private var iconView: some View {
        if let symbolName = item.systemSymbolName {
            Image(systemName: symbolName)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.accentColor)
                .frame(width: 20, height: 20)
        } else if let icon = item.icon {
            Image(nsImage: icon)
                .resizable()
                .interpolation(.high)
                .aspectRatio(contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
        } else {
            Image(systemName: "menubar.dock.rectangle")
                .font(.system(size: 14))
                .foregroundColor(.secondary)
        }
    }

    private func handleTap() {
        guard !isTriggering else { return }
        isTriggering = true
        errorMessage = nil

        onItemClicked(item)

        // Reset triggering state after short delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            isTriggering = false
        }
    }
}
