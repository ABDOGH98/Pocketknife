import SwiftUI

/// Shows a short confirmation message at the bottom of a view, then hides it.
@MainActor
@Observable
final class Toaster {
    private(set) var message: String?
    @ObservationIgnored private var hideTask: Task<Void, Never>?

    func show(_ message: String) {
        hideTask?.cancel()
        withAnimation(.snappy) { self.message = message }
        AccessibilityNotification.Announcement(message).post()
        hideTask = Task {
            try? await Task.sleep(for: .seconds(1.8))
            guard !Task.isCancelled else { return }
            withAnimation(.easeOut) { self.message = nil }
        }
    }
}

extension View {
    func toast(_ toaster: Toaster) -> some View {
        overlay(alignment: .bottom) {
            if let message = toaster.message {
                Label(message, systemImage: "checkmark.circle.fill")
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
