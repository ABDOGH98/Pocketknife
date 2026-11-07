import SwiftUI

// MARK: - Buttons

/// Every button in the app is drawn with a visible shape, so it always reads as clickable.
enum ButtonKind {
    /// Filled with the section accent. One per area: the thing you came to do.
    case primary
    /// Tinted with the section accent.
    case secondary
    /// Neutral, with an outline.
    case ghost
    /// Tinted red, for deleting.
    case destructive
}

enum ButtonSize {
    case small, regular, large

    var height: CGFloat {
        switch self {
        case .small: 28
        case .regular: 34
        case .large: 42
        }
    }

    var font: Font {
        switch self {
        case .small: .system(size: 12, weight: .medium)
        case .regular: .system(size: 13, weight: .semibold)
        case .large: .system(size: 14, weight: .semibold)
        }
    }

    var horizontalPadding: CGFloat {
        switch self {
        case .small: 10
        case .regular: 14
        case .large: 20
        }
    }
}

struct PillButtonStyle: ButtonStyle {
    var kind: ButtonKind = .secondary
    var size: ButtonSize = .regular
    /// Overrides the section accent, for example to turn green after copying.
    var tint: Color?
    var fullWidth = false

    func makeBody(configuration: Configuration) -> some View {
        PillButtonBody(configuration: configuration, kind: kind, size: size, tint: tint, fullWidth: fullWidth)
    }
}

private struct PillButtonBody: View {
    let configuration: ButtonStyleConfiguration
    let kind: ButtonKind
    let size: ButtonSize
    let tint: Color?
    let fullWidth: Bool

    @Environment(\.sectionAccent) private var sectionAccent
    @Environment(\.isEnabled) private var isEnabled
    @State private var isHovered = false

    private var accent: Color { tint ?? (kind == .destructive ? Theme.danger : sectionAccent) }
    private var shape: RoundedRectangle { RoundedRectangle(cornerRadius: size == .large ? 12 : 10, style: .continuous) }

    var body: some View {
        configuration.label
            .font(size.font)
            .labelStyle(PillLabelStyle())
            .lineLimit(1)
            .foregroundStyle(foreground)
            .padding(.horizontal, size.horizontalPadding)
            .frame(maxWidth: fullWidth ? .infinity : nil, minHeight: size.height)
            .background(background, in: shape)
            .overlay(shape.strokeBorder(border, lineWidth: 1))
            .shadow(color: kind == .primary ? accent.opacity(isHovered ? 0.35 : 0.18) : .clear, radius: isHovered ? 10 : 5, y: 3)
            .contentShape(shape)
            .scaleEffect(configuration.isPressed ? 0.96 : (isHovered && isEnabled ? 1.015 : 1))
            .opacity(isEnabled ? 1 : 0.45)
            .onHover { isHovered = $0 }
            .pointerStyle(isEnabled ? .link : .default)
            .animation(.ui, value: isHovered)
            .animation(.snappy(duration: 0.12), value: configuration.isPressed)
            .animation(.ui, value: tint)
    }

    private var foreground: Color {
        switch kind {
        case .primary: Theme.onAccent
        case .secondary, .destructive: accent
        case .ghost: Theme.text
        }
    }

    private var background: Color {
        let hover = isHovered && isEnabled
        switch kind {
        case .primary: return accent
        case .secondary, .destructive: return accent.opacity(hover ? 0.24 : 0.14)
        case .ghost: return hover ? Theme.raised.mix(with: sectionAccent, by: 0.08) : Theme.raised
        }
    }

    private var border: Color {
        switch kind {
        case .primary: .white.opacity(0.12)
        case .secondary, .destructive: accent.opacity(isHovered ? 0.45 : 0.22)
        case .ghost: isHovered ? Theme.strokeStrong : Theme.stroke
        }
    }
}

/// Icon and title with comfortable spacing.
struct PillLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 7) {
            configuration.icon.imageScale(.medium)
            configuration.title
        }
    }
}

/// A square button for an icon, used only next to a text label or with a clear tooltip.
struct IconButtonStyle: ButtonStyle {
    var size: CGFloat = 32
    var tint: Color?

    func makeBody(configuration: Configuration) -> some View {
        IconButtonBody(configuration: configuration, size: size, tint: tint)
    }
}

private struct IconButtonBody: View {
    let configuration: ButtonStyleConfiguration
    let size: CGFloat
    let tint: Color?

    @Environment(\.sectionAccent) private var sectionAccent
    @Environment(\.isEnabled) private var isEnabled
    @State private var isHovered = false

    var body: some View {
        let accent = tint ?? sectionAccent
        let shape = RoundedRectangle(cornerRadius: size * 0.3, style: .continuous)
        configuration.label
            .labelStyle(.iconOnly)
            .font(.system(size: size * 0.42, weight: .semibold))
            .foregroundStyle(isHovered ? accent : Theme.textSecondary)
            .frame(width: size, height: size)
            .background(isHovered ? accent.opacity(0.16) : Theme.raised, in: shape)
            .overlay(shape.strokeBorder(isHovered ? accent.opacity(0.4) : Theme.stroke))
            .contentShape(shape)
            .scaleEffect(configuration.isPressed ? 0.9 : 1)
            .opacity(isEnabled ? 1 : 0.4)
            .onHover { isHovered = $0 && isEnabled }
            .pointerStyle(isEnabled ? .link : .default)
            .animation(.ui, value: isHovered)
            .animation(.snappy(duration: 0.12), value: configuration.isPressed)
    }
}

// MARK: - Keyboard hint

/// A small badge such as ⌘↩ that teaches the shortcut for the button it sits in.
struct KeyHint: View {
    let keys: String
    var onAccent = false

    var body: some View {
        Text(keys)
            .font(.system(size: 10.5, weight: .semibold, design: .rounded))
            .foregroundStyle(onAccent ? Theme.onAccent.opacity(0.8) : Theme.textTertiary)
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(onAccent ? Color.white.opacity(0.2) : Theme.sunken, in: RoundedRectangle(cornerRadius: 5))
            .fixedSize()
            .accessibilityHidden(true)
    }
}

// MARK: - Copy button

/// A button that copies, then briefly turns into a green "Copied" confirmation.
struct CopyButton: View {
    var title = String(localized: "Copy")
    var systemImage = "doc.on.doc"
    var kind: ButtonKind = .secondary
    var size: ButtonSize = .regular
    var shortcutHint: String?
    var shortcut: KeyboardShortcut?
    var fullWidth = false
    let action: () -> Void

    @State private var didCopy = false
    @State private var resetTask: Task<Void, Never>?

    var body: some View {
        Button {
            action()
            confirm()
        } label: {
            HStack(spacing: 8) {
                Label(didCopy ? String(localized: "Copied") : title, systemImage: didCopy ? "checkmark" : systemImage)
                    .contentTransition(.symbolEffect(.replace))
                if let shortcutHint, !didCopy {
                    KeyHint(keys: shortcutHint, onAccent: kind == .primary)
                }
            }
        }
        .buttonStyle(PillButtonStyle(kind: kind, size: size, tint: didCopy ? Theme.success : nil, fullWidth: fullWidth))
        .keyboardShortcut(shortcut)
    }

    private func confirm() {
        resetTask?.cancel()
        withAnimation(Theme.motion(.lively)) { didCopy = true }
        resetTask = Task {
            try? await Task.sleep(for: .seconds(1.4))
            guard !Task.isCancelled else { return }
            withAnimation(Theme.motion(.ui)) { didCopy = false }
        }
    }
}

// MARK: - Search

struct SearchField: View {
    @Binding var text: String
    var prompt: String
    var focus: FocusState<Bool>.Binding
    /// Return in the field, for example to copy the top result.
    var onSubmit: () -> Void = {}
    /// Up and down arrows in the field, to move the selection without leaving it.
    var onMove: ((Int) -> Void)?

    @Environment(\.sectionAccent) private var accent

    var body: some View {
        let isFocused = focus.wrappedValue
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(isFocused ? accent : Theme.textTertiary)
                .font(.system(size: 13, weight: .semibold))
            TextField("Search", text: $text, prompt: Text(prompt).foregroundStyle(Theme.textTertiary))
                .textFieldStyle(.plain)
                .font(.system(size: 13.5))
                .foregroundStyle(Theme.text)
                .focused(focus)
                .onExitCommand { text = "" }
                .onSubmit(onSubmit)
                .onKeyPress(.downArrow) {
                    guard let onMove else { return .ignored }
                    onMove(1)
                    return .handled
                }
                .onKeyPress(.upArrow) {
                    guard let onMove else { return .ignored }
                    onMove(-1)
                    return .handled
                }
                .labelsHidden()
            if !text.isEmpty {
                Button("Clear Search", systemImage: "xmark.circle.fill") { text = "" }
                    .labelStyle(.iconOnly)
                    .buttonStyle(.plain)
                    .foregroundStyle(Theme.textTertiary)
                    .pointerStyle(.link)
                    .transition(.scale.combined(with: .opacity))
            } else {
                KeyHint(keys: "⌘F")
            }
        }
        .padding(.horizontal, 12)
        .frame(height: 36)
        .background(Theme.raised, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(isFocused ? accent.opacity(0.7) : Theme.stroke, lineWidth: isFocused ? 1.5 : 1)
        )
        .contentShape(Rectangle())
        .onTapGesture { focus.wrappedValue = true }
        .animation(.ui, value: isFocused)
        .animation(.ui, value: text.isEmpty)
        .background {
            // ⌘F jumps to the search field from anywhere in the section.
            Button("Search") { focus.wrappedValue = true }
                .keyboardShortcut("f")
                .hidden()
        }
    }
}

// MARK: - Filter chips

/// A selectable capsule used for filters such as All, Favorites and tags.
struct FilterChip: View {
    let title: String
    var systemImage: String?
    var count: Int?
    var tint: Color?
    let isSelected: Bool
    let action: () -> Void

    @Environment(\.sectionAccent) private var sectionAccent
    @State private var isHovered = false

    var body: some View {
        let accent = tint ?? sectionAccent
        Button(action: action) {
            HStack(spacing: 5) {
                if let systemImage {
                    Image(systemName: systemImage).imageScale(.small)
                }
                Text(title).lineLimit(1)
                if let count {
                    Text("\(count)")
                        .font(.system(size: 10.5, weight: .bold, design: .rounded))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(isSelected ? Theme.onAccent.opacity(0.2) : Theme.sunken, in: Capsule())
                        .contentTransition(.numericText())
                }
            }
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(isSelected ? Theme.onAccent : (isHovered ? accent : Theme.textSecondary))
            .padding(.horizontal, 10)
            .frame(height: 28)
            .background(isSelected ? accent : (isHovered ? accent.opacity(0.14) : Theme.raised), in: Capsule())
            .overlay(Capsule().strokeBorder(isSelected ? .clear : (isHovered ? accent.opacity(0.4) : Theme.stroke)))
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .pointerStyle(.link)
        .animation(.ui, value: isHovered)
        .animation(.ui, value: isSelected)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

// MARK: - Segmented picker

/// A segmented control with large hit areas and a sliding highlight.
struct PillPicker<Value: Hashable>: View {
    let options: [Value]
    @Binding var selection: Value
    let title: (Value) -> String
    var systemImage: ((Value) -> String)?

    @Environment(\.sectionAccent) private var accent
    @Namespace private var namespace

    var body: some View {
        HStack(spacing: 2) {
            ForEach(options, id: \.self) { option in
                let isSelected = option == selection
                Button {
                    withAnimation(Theme.motion(.lively)) { selection = option }
                } label: {
                    HStack(spacing: 6) {
                        if let systemImage { Image(systemName: systemImage(option)) }
                        Text(title(option))
                    }
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(isSelected ? Theme.onAccent : Theme.textSecondary)
                    .padding(.horizontal, 14)
                    .frame(height: 30)
                    .background {
                        if isSelected {
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(accent)
                                .matchedGeometryEffect(id: "selection", in: namespace)
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .pointerStyle(.link)
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
        .padding(3)
        .background(Theme.sunken, in: RoundedRectangle(cornerRadius: 11, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 11, style: .continuous).strokeBorder(Theme.stroke))
    }
}

// MARK: - Menus

extension View {
    /// Gives a `Menu` the same outlined look as a ghost button.
    func pillMenuStyle(height: CGFloat = 30) -> some View {
        self
            .menuStyle(.borderlessButton)
            .menuIndicator(.visible)
            .fixedSize()
            .padding(.horizontal, 10)
            .frame(height: height)
            .background(Theme.raised, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 9, style: .continuous).strokeBorder(Theme.stroke))
            .pointerStyle(.link)
    }
}

// MARK: - Text fields

/// A labelled text field with a soft background and an accent ring while editing.
struct FieldBox<Content: View>: View {
    var label: String?
    var hint: String?
    var monospaced = false
    @ViewBuilder var content: Content

    @Environment(\.sectionAccent) private var accent
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if label != nil || hint != nil {
                HStack(alignment: .firstTextBaseline) {
                    if let label { FieldLabel(label) }
                    Spacer(minLength: 8)
                    if let hint {
                        Text(hint)
                            .font(.caption)
                            .foregroundStyle(Theme.textTertiary)
                    }
                }
            }
            content
                .textFieldStyle(.plain)
                .font(monospaced ? .system(size: 13, design: .monospaced) : .system(size: 13.5))
                .foregroundStyle(Theme.text)
                .focused($isFocused)
                .padding(.horizontal, 11)
                .frame(minHeight: 36)
                .background(Theme.raised, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(isFocused ? accent.opacity(0.7) : Theme.stroke, lineWidth: isFocused ? 1.5 : 1)
                )
                .animation(.ui, value: isFocused)
        }
    }
}

struct FieldLabel: View {
    let text: String
    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(Theme.textSecondary)
    }
}
