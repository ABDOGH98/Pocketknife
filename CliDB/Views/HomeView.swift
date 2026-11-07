import SwiftUI
import SwiftData

struct HomeView: View {
    var onSelect: (AppSection) -> Void

    @Query private var commands: [SavedCommand]
    @Query private var passwords: [SavedPassword]

    var body: some View {
        VStack(spacing: 32) {
            VStack(spacing: 6) {
                Text("Pocketknife")
                    .font(.largeTitle.weight(.bold))
                Text("What do you need?")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 20) {
                HomeCard(
                    title: "CLI Commands",
                    subtitle: "Search, fill in and copy the commands you use often.",
                    systemImage: "terminal.fill",
                    tint: .blue,
                    count: Text("^[\(commands.count) command](inflect: true)"),
                    shortcut: "1"
                ) { onSelect(.commands) }

                HomeCard(
                    title: "Passwords",
                    subtitle: "Usernames and passwords, kept in your Keychain.",
                    systemImage: "key.fill",
                    tint: .orange,
                    count: Text("^[\(passwords.count) login](inflect: true)"),
                    shortcut: "2"
                ) { onSelect(.passwords) }

                HomeCard(
                    title: "Utilities",
                    subtitle: "Format JSON and XML, encode and decode Base64.",
                    systemImage: "wrench.and.screwdriver.fill",
                    tint: .purple,
                    count: Text("JSON · XML · Base64"),
                    shortcut: "3"
                ) { onSelect(.utils) }
            }
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .navigationTitle("Pocketknife")
    }
}

private struct HomeCard: View {
    let title: String
    let subtitle: String
    let systemImage: String
    let tint: Color
    let count: Text
    let shortcut: KeyEquivalent
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 14) {
                Image(systemName: systemImage)
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 56, height: 56)
                    .background(tint.gradient, in: RoundedRectangle(cornerRadius: 14))

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.title2.weight(.semibold))
                    Text(subtitle)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)

                HStack {
                    count
                        .font(.callout.weight(.medium))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Image(systemName: "arrow.right")
                        .foregroundStyle(tint)
                        .offset(x: isHovered ? 3 : 0)
                }
            }
            .padding(22)
            .frame(width: 250, height: 240, alignment: .topLeading)
            .background(.background, in: RoundedRectangle(cornerRadius: 18))
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .strokeBorder(isHovered ? AnyShapeStyle(tint.opacity(0.6)) : AnyShapeStyle(.separator), lineWidth: isHovered ? 2 : 1)
            )
            .shadow(color: .black.opacity(isHovered ? 0.12 : 0.05), radius: isHovered ? 14 : 6, y: isHovered ? 6 : 2)
            .scaleEffect(isHovered ? 1.02 : 1)
            .contentShape(RoundedRectangle(cornerRadius: 18))
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.snappy(duration: 0.2)) { isHovered = hovering }
        }
        .help("\(title) (⌘\(String(shortcut.character)))")
        .accessibilityHint(subtitle)
    }
}
