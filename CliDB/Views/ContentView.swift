import SwiftUI
import SwiftData

/// The main window: a navigation rail on the left, the current section on the right.
/// `section == nil` is the home screen.
struct ContentView: View {
    @State private var section: AppSection?
    /// Set from Home's quick actions; the destination section consumes it when it appears.
    @State private var pendingRequest: SectionRequest?

    init(initialSection: AppSection? = nil) {
        _section = State(initialValue: initialSection)
    }

    var body: some View {
        HStack(spacing: 0) {
            SideRail(selection: section, onSelect: go)
            Rectangle().fill(Theme.stroke).frame(width: 1).ignoresSafeArea()
            ZStack {
                switch section {
                case nil:
                    HomeView(onSelect: go, onRequest: { request in
                        pendingRequest = request
                        go(request.section)
                    })
                    .transition(.sectionChange)
                case .commands:
                    CommandsView()
                        .transition(.sectionChange)
                case .passwords:
                    PasswordsView(pendingRequest: $pendingRequest)
                        .transition(.sectionChange)
                case .utils:
                    UtilsView(pendingRequest: $pendingRequest)
                        .transition(.sectionChange)
                case .settings:
                    SettingsView()
                        .transition(.sectionChange)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .environment(\.sectionAccent, section?.accent ?? Theme.mint)
            .tint(section?.accent ?? Theme.mint)
        }
        .foregroundStyle(Theme.text)
        .background(Theme.canvas.ignoresSafeArea())
        .focusedSceneValue(\.sectionNavigation, SectionNavigation(current: section, go: go))
        .onAppear { AppSettings.shared.applyAppearance() }
    }

    private func go(_ destination: AppSection?) {
        guard destination != section else { return }
        withAnimation(Theme.motion(.snappy(duration: 0.3))) { section = destination }
    }
}

/// Something Home asks a section to do once it opens, such as "add a new login".
enum SectionRequest: Equatable {
    case newPassword
    case utility(UtilityTool)

    var section: AppSection {
        switch self {
        case .newPassword: .passwords
        case .utility: .utils
        }
    }
}

extension AnyTransition {
    static var sectionChange: AnyTransition {
        .asymmetric(
            insertion: .opacity.combined(with: .offset(y: 12)).combined(with: .scale(scale: 0.99)),
            removal: .opacity
        )
    }
}

/// Lets the Go menu switch sections in the main window.
struct SectionNavigation {
    let current: AppSection?
    let go: @MainActor (AppSection?) -> Void
}

extension FocusedValues {
    @Entry var sectionNavigation: SectionNavigation?
}

// MARK: - Rail

private struct SideRail: View {
    let selection: AppSection?
    let onSelect: (AppSection?) -> Void

    @Namespace private var namespace

    var body: some View {
        VStack(spacing: 6) {
            // Leaves room for the window's traffic-light buttons.
            Spacer().frame(height: 18)

            RailButton(title: String(localized: "Home"), systemImage: "house.fill", accent: Theme.sky, shortcut: "0", isSelected: selection == nil, namespace: namespace) {
                onSelect(nil)
            }

            Rectangle()
                .fill(Theme.stroke)
                .frame(width: 32, height: 1)
                .padding(.vertical, 6)

            ForEach(AppSection.tools, id: \.self) { section in
                RailButton(
                    title: section.title,
                    systemImage: section.systemImage,
                    accent: section.accent,
                    shortcut: section.shortcut,
                    isSelected: selection == section,
                    namespace: namespace
                ) {
                    onSelect(section)
                }
            }

            Spacer()

            RailButton(
                title: AppSection.settings.title,
                systemImage: AppSection.settings.systemImage,
                accent: AppSection.settings.accent,
                shortcut: AppSection.settings.shortcut,
                isSelected: selection == .settings,
                namespace: namespace
            ) {
                onSelect(.settings)
            }
            .padding(.bottom, 14)
        }
        .padding(.horizontal, 8)
        .frame(width: 86)
        .background(Theme.rail.ignoresSafeArea())
    }
}

private struct RailButton: View {
    let title: String
    let systemImage: String
    let accent: Color
    let shortcut: Character
    let isSelected: Bool
    let namespace: Namespace.ID
    let action: () -> Void

    @State private var isHovered = false
    @State private var bounce = 0

    var body: some View {
        Button {
            bounce += 1
            action()
        } label: {
            VStack(spacing: 5) {
                Image(systemName: systemImage)
                    .font(.system(size: 18, weight: .semibold))
                    .symbolEffect(.bounce, value: bounce)
                    .foregroundStyle(isSelected ? accent : (isHovered ? Theme.text : Theme.textSecondary))
                    .frame(width: 48, height: 36)
                    .background {
                        if isSelected {
                            RoundedRectangle(cornerRadius: 11, style: .continuous)
                                .fill(accent.opacity(0.18))
                                .overlay(RoundedRectangle(cornerRadius: 11, style: .continuous).strokeBorder(accent.opacity(0.35)))
                                .matchedGeometryEffect(id: "rail-selection", in: namespace)
                        } else if isHovered {
                            RoundedRectangle(cornerRadius: 11, style: .continuous)
                                .fill(Theme.raised)
                        }
                    }
                Text(title)
                    .font(.system(size: 10.5, weight: isSelected ? .bold : .medium))
                    .foregroundStyle(isSelected ? Theme.text : Theme.textSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .pointerStyle(.link)
        .animation(.ui, value: isHovered)
        .animation(Theme.motion(.lively), value: isSelected)
        .help("\(title) (⌘\(shortcut))")
        .accessibilityLabel(title)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [SavedCommand.self, SavedPassword.self], inMemory: true)
        .environment(EditorEvents())
        .frame(width: 1100, height: 700)
}
