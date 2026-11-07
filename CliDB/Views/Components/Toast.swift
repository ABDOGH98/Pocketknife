import SwiftUI

/// Shows a short confirmation message at the bottom of a view, then hides it.
@MainActor
@Observable
final class Toaster {
    enum Kind {
        case success, info, warning

        var systemImage: String {
            switch self {
            case .success: "checkmark"
            case .info: "info"
            case .warning: "exclamationmark"
            }
        }

        var tint: Color {
            switch self {
            case .success: Theme.success
            case .info: Theme.sky
            case .warning: Theme.warning
            }
        }
    }

    struct Message: Equatable {
        let id = UUID()
        let text: String
        let kind: Kind
    }

    private(set) var message: Message?
    @ObservationIgnored private var hideTask: Task<Void, Never>?

    func show(_ text: String, kind: Kind = .success) {
        hideTask?.cancel()
        withAnimation(Theme.motion(.lively)) { message = Message(text: text, kind: kind) }
        AccessibilityNotification.Announcement(text).post()
        hideTask = Task {
            try? await Task.sleep(for: .seconds(2))
            guard !Task.isCancelled else { return }
            withAnimation(Theme.motion(.easeOut(duration: 0.25))) { self.message = nil }
        }
    }
}

extension View {
    func toast(_ toaster: Toaster) -> some View {
        overlay(alignment: .bottom) {
            if let message = toaster.message {
                ToastView(message: message)
                    .id(message.id)
                    .padding(.bottom, 26)
                    .transition(.move(edge: .bottom).combined(with: .opacity).combined(with: .scale(scale: 0.9)))
            }
        }
    }
}

private struct ToastView: View {
    let message: Toaster.Message
    @State private var appeared = false

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: message.kind.systemImage)
                .font(.system(size: 11, weight: .heavy))
                .foregroundStyle(Theme.onAccent)
                .frame(width: 22, height: 22)
                .background(message.kind.tint, in: Circle())
                .symbolEffect(.bounce, value: appeared)
            Text(message.text)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.text)
        }
        .padding(.leading, 8)
        .padding(.trailing, 16)
        .padding(.vertical, 8)
        .background(.regularMaterial, in: Capsule())
        .background(Theme.surface.opacity(0.6), in: Capsule())
        .overlay(Capsule().strokeBorder(message.kind.tint.opacity(0.35)))
        .shadow(color: .black.opacity(0.18), radius: 14, y: 6)
        .onAppear { appeared = true }
    }
}
