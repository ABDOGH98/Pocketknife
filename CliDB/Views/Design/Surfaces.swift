import SwiftUI

// MARK: - Cards

extension View {
    /// A rounded panel one step above the window background.
    func card(padding: CGFloat = 18, radius: CGFloat = Theme.Radius.large) -> some View {
        self
            .padding(padding)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: radius, style: .continuous).strokeBorder(Theme.stroke))
    }

    /// Slides and fades the view in when it first appears. `index` staggers items in a group.
    func appearAnimation(index: Int = 0) -> some View {
        modifier(AppearAnimation(delay: Double(index) * 0.05))
    }
}

private struct AppearAnimation: ViewModifier {
    let delay: Double
    @State private var isVisible = false

    func body(content: Content) -> some View {
        content
            .opacity(isVisible ? 1 : 0)
            .offset(y: isVisible ? 0 : 10)
            .onAppear {
                guard let animation = Theme.motion(.lively.delay(delay)) else {
                    isVisible = true
                    return
                }
                withAnimation(animation) { isVisible = true }
            }
    }
}

/// A heading for a group of content inside a pane, with optional trailing controls.
struct SectionHeader<Trailing: View>: View {
    let title: String
    var systemImage: String?
    @ViewBuilder var trailing: Trailing

    @Environment(\.sectionAccent) private var accent

    var body: some View {
        HStack(spacing: 8) {
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(accent)
            }
            Text(title)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(Theme.text)
            Spacer(minLength: 8)
            trailing
        }
    }
}

extension SectionHeader where Trailing == EmptyView {
    init(title: String, systemImage: String? = nil) {
        self.init(title: title, systemImage: systemImage) { EmptyView() }
    }
}

// MARK: - Empty states

struct EmptyStateView<Actions: View>: View {
    let title: String
    let message: String
    let systemImage: String
    @ViewBuilder var actions: Actions

    @Environment(\.sectionAccent) private var accent
    @State private var isFloating = false

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: systemImage)
                .font(.system(size: 30, weight: .semibold))
                .foregroundStyle(accent)
                .frame(width: 72, height: 72)
                .background(accent.opacity(0.14), in: Circle())
                .overlay(Circle().strokeBorder(accent.opacity(0.25)))
                .offset(y: isFloating ? -4 : 2)
            VStack(spacing: 6) {
                Text(title)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(Theme.text)
                Text(message)
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.textSecondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 300)
            }
            actions.padding(.top, 4)
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            if let animation = Theme.motion(.easeInOut(duration: 2.4).repeatForever(autoreverses: true)) {
                withAnimation(animation) { isFloating = true }
            }
        }
        .appearAnimation()
    }
}

extension EmptyStateView where Actions == EmptyView {
    init(title: String, message: String, systemImage: String) {
        self.init(title: title, message: message, systemImage: systemImage) { EmptyView() }
    }
}

// MARK: - Tiles

/// A rounded square with a symbol or letter on a soft gradient of `tint`.
struct IconTile: View {
    var systemImage: String?
    var letter: String?
    let tint: Color
    var size: CGFloat = 40

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
        Group {
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.system(size: size * 0.44, weight: .semibold))
            } else {
                Text(letter ?? "?")
                    .font(.system(size: size * 0.46, weight: .bold, design: .rounded))
            }
        }
        .foregroundStyle(tint)
        .frame(width: size, height: size)
        .background(
            LinearGradient(colors: [tint.opacity(0.28), tint.opacity(0.12)], startPoint: .topLeading, endPoint: .bottomTrailing),
            in: shape
        )
        .overlay(shape.strokeBorder(tint.opacity(0.3)))
        .accessibilityHidden(true)
    }
}

// MARK: - Background

/// Soft, slowly drifting color glows behind the home screen. Still when Reduce Motion is on.
struct AmbientBackground: View {
    @State private var drift = false

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            ZStack {
                glow(Theme.mint, diameter: size.width * 0.55)
                    .offset(x: drift ? -size.width * 0.28 : -size.width * 0.18, y: drift ? -size.height * 0.30 : -size.height * 0.18)
                glow(Theme.amber, diameter: size.width * 0.45)
                    .offset(x: drift ? size.width * 0.30 : size.width * 0.22, y: drift ? -size.height * 0.10 : -size.height * 0.26)
                glow(Theme.lavender, diameter: size.width * 0.5)
                    .offset(x: drift ? size.width * 0.05 : -size.width * 0.08, y: drift ? size.height * 0.36 : size.height * 0.26)
            }
            .frame(width: size.width, height: size.height)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .onAppear {
            if let animation = Theme.motion(.easeInOut(duration: 14).repeatForever(autoreverses: true)) {
                withAnimation(animation) { drift = true }
            }
        }
    }

    private func glow(_ color: Color, diameter: CGFloat) -> some View {
        Circle()
            .fill(color.opacity(0.16))
            .frame(width: diameter, height: diameter)
            .blur(radius: 90)
    }
}
