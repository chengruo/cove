import SwiftUI

public struct EmptyStateView: View {
    public let message: String
    public let subtitle: String

    public init(
        message: String = "No Hidden Items",
        subtitle: String = "All menu bar items are currently visible and accessible."
    ) {
        self.message = message
        self.subtitle = subtitle
    }

    public var body: some View {
        VStack(spacing: 10) {
            Image(systemName: "checkmark.circle")
                .font(.system(size: 32, weight: .light))
                .foregroundColor(.secondary)
                .padding(.top, 12)

            Text(message)
                .font(.headline)
                .foregroundColor(.primary)

            Text(subtitle)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 16)
                .padding(.bottom, 12)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
    }
}
