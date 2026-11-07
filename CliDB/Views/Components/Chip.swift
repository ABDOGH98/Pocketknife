import SwiftUI

/// A small capsule label, optionally removable.
struct Chip: View {
    enum Style {
        case neutral, accent
    }

    let text: String
    var systemImage: String?
    var monospaced = false
    var style: Style = .neutral
    var onRemove: (() -> Void)?

    var body: some View {
        HStack(spacing: 4) {
            if let systemImage {
                Image(systemName: systemImage).imageScale(.small)
            }
            Text(text)
                .font(monospaced ? .system(.callout, design: .monospaced) : .callout)
                .lineLimit(1)
            if let onRemove {
                Button(action: onRemove) {
                    Image(systemName: "xmark.circle.fill")
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .accessibilityLabel("Remove \(text)")
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(background, in: Capsule())
    }

    private var background: AnyShapeStyle {
        switch style {
        case .neutral: AnyShapeStyle(.quaternary)
        case .accent: AnyShapeStyle(.tint.opacity(0.18))
        }
    }
}
