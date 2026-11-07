import SwiftUI

/// A capsule label, optionally removable. Tags get a soft color that stays the same for each name.
struct Chip: View {
    let text: String
    var systemImage: String?
    var monospaced = false
    /// nil draws a neutral chip.
    var tint: Color?
    var onRemove: (() -> Void)?

    @State private var isRemoveHovered = false

    var body: some View {
        let color = tint ?? Theme.textSecondary
        HStack(spacing: 5) {
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.system(size: 9.5, weight: .bold))
            }
            Text(text)
                .font(monospaced ? .system(size: 12, design: .monospaced) : .system(size: 12, weight: .medium))
                .lineLimit(1)
            if let onRemove {
                Button(action: onRemove) {
                    Image(systemName: "xmark")
                        .font(.system(size: 8.5, weight: .heavy))
                        .frame(width: 16, height: 16)
                        .background(isRemoveHovered ? Theme.danger.opacity(0.25) : color.opacity(0.18), in: Circle())
                        .foregroundStyle(isRemoveHovered ? Theme.danger : color)
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .onHover { isRemoveHovered = $0 }
                .pointerStyle(.link)
                .help("Remove \(text)")
                .accessibilityLabel("Remove \(text)")
            }
        }
        .foregroundStyle(color)
        .padding(.leading, 9)
        .padding(.trailing, onRemove == nil ? 9 : 4)
        .frame(height: 24)
        .background(color.opacity(0.13), in: Capsule())
        .overlay(Capsule().strokeBorder(color.opacity(0.2)))
        .animation(.ui, value: isRemoveHovered)
    }
}

/// A chip for a tag, colored by name.
struct TagChip: View {
    let tag: String
    var onRemove: (() -> Void)?

    var body: some View {
        Chip(text: tag, systemImage: "number", tint: Theme.swatch(for: tag), onRemove: onRemove)
    }
}
