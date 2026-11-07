import SwiftUI

/// Shows a short confirmation message at the bottom of a view, then hides it.
@MainActor
@Observable
final class Toaster {
    /// Success messages confirm an action; warnings need the user's attention, so they stay longer
    /// and use a different icon and color.
    enum Style {
        case success, warning

        var systemImage: String {
            switch self {
            case .success: "checkmark.circle.fill"
            case .warning: "exclamationmark.triangle.fill"
            }
        }

        var tint: Color {
            switch self {
            case .success: .green
            case .warning: .orange
            }
        }

        var duration: Duration {
            switch self {
            case .success: .seconds(1.8)
            case .warning: .seconds(3.5)
            }
        }
    }

    private(set) var message: String?
    private(set) var style: Style = .success
    @ObservationIgnored private var hideTask: Task<Void, Never>?

    func show(_ resource: LocalizedStringResource, style: Style = .success) {
        let message = String(localized: resource)
        hideTask?.cancel()
        withAnimation(.snappy) {
            self.message = message
            self.style = style
        }
        AccessibilityNotification.Announcement(message).post()
        hideTask = Task {
            try? await Task.sleep(for: style.duration)
            guard !Task.isCancelled else { return }
            withAnimation(.easeOut) { self.message = nil }
        }
    }
}

extension View {
    func toast(_ toaster: Toaster) -> some View {
        overlay(alignment: .bottom) {
            if let message = toaster.message {
                Label {
                    Text(message)
                } icon: {
                    Image(systemName: toaster.style.systemImage)
                        .foregroundStyle(toaster.style.tint)
                }
                .font(.callout.weight(.medium))
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(.regularMaterial, in: Capsule())
                .overlay(Capsule().strokeBorder(.separator))
                .shadow(color: .black.opacity(0.15), radius: 8, y: 3)
                .padding(.bottom, 24)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
    }
}
