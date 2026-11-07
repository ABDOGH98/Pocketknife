import AppKit
import SwiftUI

enum UtilityTool: String, CaseIterable, Identifiable {
    case json, xml, base64, jwt

    var id: Self { self }

    var title: String {
        switch self {
        case .json: "JSON"
        case .xml: "XML"
        case .base64: "Base64"
        case .jwt: "JWT"
        }
    }

    var summary: String {
        switch self {
        case .json, .xml: String(localized: "Format · Minify")
        case .base64: String(localized: "Encode · Decode")
        case .jwt: String(localized: "Decode tokens")
        }
    }

    var systemImage: String {
        switch self {
        case .json: "curlybraces"
        case .xml: "chevron.left.forwardslash.chevron.right"
        case .base64: "number"
        case .jwt: "key.horizontal.fill"
        }
    }

    var placeholder: String {
        switch self {
        case .json: String(localized: "Paste or type JSON here")
        case .xml: String(localized: "Paste or type XML here")
        case .base64: String(localized: "Paste text or Base64 here")
        case .jwt: String(localized: "Paste a JWT here (a Bearer prefix is fine)")
        }
    }

    var modes: [UtilityMode] {
        switch self {
        case .json, .xml: [.format, .minify]
        case .base64: [.encode, .decode]
        case .jwt: [.decode]
        }
    }

    /// Guesses which tool `text` is meant for, so the app can offer to switch.
    static func detect(_ text: String) -> UtilityTool? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let first = trimmed.first else { return nil }
        var token = Substring(trimmed)
        if token.lowercased().hasPrefix("bearer ") { token = token.dropFirst(7) }
        if token.hasPrefix("eyJ"),
           !token.contains(where: \.isWhitespace),
           token.split(separator: ".", omittingEmptySubsequences: false).count == 3 {
            return .jwt
        }
        if first == "{" || first == "[" { return .json }
        if first == "<" { return .xml }
        return nil
    }
}

enum UtilityMode: String, Identifiable {
    case format = "Format", minify = "Minify", encode = "Encode", decode = "Decode"
    var id: Self { self }

    var title: String {
        switch self {
        case .format: String(localized: "Format")
        case .minify: String(localized: "Minify")
        case .encode: String(localized: "Encode")
        case .decode: String(localized: "Decode")
        }
    }
}

struct UtilsView: View {
    @Binding var pendingRequest: SectionRequest?

    @State private var tool: UtilityTool = .json
    @State private var inputs: [UtilityTool: String] = [:]
    @State private var modes: [UtilityTool: UtilityMode] = [:]
    @State private var urlSafe = false
    @State private var toaster = Toaster()

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Utilities")
                    .font(.system(size: 22, weight: .bold))
                Text("Paste something in. The result updates as you type.")
                    .font(.system(size: 12.5, weight: .medium))
                    .foregroundStyle(Theme.textSecondary)
            }

            ToolTabs(selection: $tool)

            UtilityToolView(
                tool: tool,
                input: Binding(get: { inputs[tool, default: ""] }, set: { inputs[tool] = $0 }),
                mode: Binding(get: { modes[tool] ?? tool.modes[0] }, set: { modes[tool] = $0 }),
                urlSafe: $urlSafe,
                toaster: toaster,
                onSwitch: switchTool(to:)
            )
            .id(tool)
            .transition(.opacity.combined(with: .offset(y: 8)))
        }
        .padding(.horizontal, 24)
        .padding(.top, 10)
        .padding(.bottom, 20)
        .navigationTitle("Utilities")
        .toast(toaster)
        .task {
            if case .utility(let requested) = pendingRequest {
                tool = requested
                pendingRequest = nil
            }
        }
    }

    /// Moves the current input to `newTool`, used when the app recognizes what was pasted.
    private func switchTool(to newTool: UtilityTool) {
        let text = inputs[tool, default: ""]
        inputs[tool] = ""
        inputs[newTool] = text
        withAnimation(Theme.motion(.snappy(duration: 0.3))) { tool = newTool }
        toaster.show(String(localized: "Switched to \(newTool.title)"), kind: .info)
    }
}

// MARK: - Tool tabs

private struct ToolTabs: View {
    @Binding var selection: UtilityTool

    @Environment(\.sectionAccent) private var accent
    @Namespace private var namespace

    var body: some View {
        HStack(spacing: 10) {
            ForEach(UtilityTool.allCases) { tool in
                ToolTab(tool: tool, isSelected: tool == selection, namespace: namespace) {
                    withAnimation(Theme.motion(.snappy(duration: 0.3))) { selection = tool }
                }
            }
        }
    }
}

private struct ToolTab: View {
    let tool: UtilityTool
    let isSelected: Bool
    let namespace: Namespace.ID
    let action: () -> Void

    @Environment(\.sectionAccent) private var accent
    @State private var isHovered = false

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 14, style: .continuous)
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: tool.systemImage)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(isSelected ? Theme.onAccent : accent)
                    .frame(width: 32, height: 32)
                    .background(isSelected ? accent : accent.opacity(0.14), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                    .symbolEffect(.bounce, value: isSelected)
                VStack(alignment: .leading, spacing: 1) {
                    Text(tool.title)
                        .font(.system(size: 13.5, weight: .bold))
                        .foregroundStyle(Theme.text)
                    Text(tool.summary)
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.textSecondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
            }
            .padding(10)
            .frame(maxWidth: .infinity)
            .background {
                shape.fill(isHovered ? Theme.raised : Theme.surface)
                if isSelected {
                    shape
                        .fill(accent.opacity(0.1))
                        .overlay(shape.strokeBorder(accent.opacity(0.6), lineWidth: 1.5))
                        .matchedGeometryEffect(id: "tool-selection", in: namespace)
                }
            }
            .overlay(shape.strokeBorder(isSelected ? .clear : Theme.stroke))
            .contentShape(shape)
        }
        .buttonStyle(PressableStyle())
        .onHover { isHovered = $0 }
        .pointerStyle(.link)
        .animation(.ui, value: isHovered)
        .accessibilityLabel(tool.title)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

// MARK: - Tool

private struct UtilityToolView: View {
    let tool: UtilityTool
    @Binding var input: String
    @Binding var mode: UtilityMode
    @Binding var urlSafe: Bool
    let toaster: Toaster
    let onSwitch: (UtilityTool) -> Void

    @Environment(\.openWindow) private var openWindow
    @Environment(\.sectionAccent) private var accent
    @State private var inputFindRequest = 0
    @State private var outputFindRequest = 0

    var body: some View {
        let result = transform()
        let outputText = output(result)
        let suggestion = UtilityTool.detect(input).flatMap { $0 == tool ? nil : $0 }

        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 14) {
                if tool.modes.count > 1 {
                    PillPicker(options: tool.modes, selection: $mode, title: \.title)
                }
                if tool == .base64, mode == .encode {
                    Toggle("URL-safe", isOn: $urlSafe)
                        .toggleStyle(.switch)
                        .controlSize(.small)
                        .font(.system(size: 12.5, weight: .medium))
                        .help("Use - and _ instead of + and /, without = padding")
                }
                if tool == .jwt {
                    Label("Signatures are shown but not verified", systemImage: "exclamationmark.shield")
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.textTertiary)
                }
                Spacer()
                if let suggestion {
                    Button {
                        onSwitch(suggestion)
                    } label: {
                        Label("Looks like \(suggestion.title) · Switch", systemImage: "sparkles")
                    }
                    .buttonStyle(PillButtonStyle(kind: .secondary, tint: Theme.sky))
                    .transition(.scale(scale: 0.85).combined(with: .opacity))
                }
            }
            .frame(minHeight: 36)
            .animation(Theme.motion(.lively), value: suggestion)

            HStack(alignment: .top, spacing: 14) {
                inputPane
                outputPane(result: result, text: outputText)
            }
        }
    }

    // MARK: Panes

    private var inputPane: some View {
        EditorPane(title: String(localized: "Input"), systemImage: "square.and.pencil") {
            Button {
                if let text = NSPasteboard.general.string(forType: .string) { input = text }
            } label: {
                Label("Paste", systemImage: "doc.on.clipboard")
            }
            .buttonStyle(PillButtonStyle(kind: .secondary, size: .small))
            Button {
                input = ""
            } label: {
                Label("Clear", systemImage: "xmark")
            }
            .buttonStyle(PillButtonStyle(kind: .ghost, size: .small))
            .disabled(input.isEmpty)
            Button("Find", systemImage: "magnifyingglass") { inputFindRequest += 1 }
                .buttonStyle(IconButtonStyle(size: 28))
                .help("Search the input (⌘F)")
        } content: {
            CodeTextView(text: $input, findRequest: inputFindRequest)
                .overlay {
                    if input.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "arrow.down.doc.fill")
                                .font(.system(size: 26))
                                .foregroundStyle(accent.opacity(0.7))
                            Text(tool.placeholder)
                                .font(.system(size: 13))
                                .foregroundStyle(Theme.textTertiary)
                            Button {
                                if let text = NSPasteboard.general.string(forType: .string) { input = text }
                            } label: {
                                Label("Paste from Clipboard", systemImage: "doc.on.clipboard")
                            }
                            .buttonStyle(PillButtonStyle(kind: .primary))
                        }
                        .transition(.opacity)
                    }
                }
        } footer: {
            Text("^[\(input.count) character](inflect: true)")
                .font(.system(size: 11.5, weight: .medium))
                .foregroundStyle(Theme.textTertiary)
                .contentTransition(.numericText())
            Spacer()
        }
    }

    private func outputPane(result: Result<String, TransformError>, text: String) -> some View {
        EditorPane(title: String(localized: "Output"), systemImage: "sparkles.rectangle.stack") {
            statusBadge(result)
            Spacer(minLength: 4)
            Button("Find", systemImage: "magnifyingglass") { outputFindRequest += 1 }
                .buttonStyle(IconButtonStyle(size: 28))
                .help("Search the output (⌘F)")
                .disabled(text.isEmpty)
            Button("Expand", systemImage: "arrow.up.left.and.arrow.down.right") {
                openWindow(id: ExpandedOutput.windowID, value: ExpandedOutput(title: String(localized: "\(tool.title) \(mode.title) Output"), text: text))
            }
            .buttonStyle(IconButtonStyle(size: 28))
            .help("Open the output in a large window")
            .disabled(text.isEmpty)
        } content: {
            CodeTextView(text: .constant(text), isEditable: false, findRequest: outputFindRequest)
                .overlay {
                    if case .failure(let error) = result {
                        VStack(spacing: 10) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 24))
                                .foregroundStyle(Theme.danger)
                                .symbolEffect(.bounce, value: error.message)
                            Text(error.message)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(Theme.text)
                                .multilineTextAlignment(.center)
                                .textSelection(.enabled)
                                .frame(maxWidth: 300)
                        }
                        .padding(18)
                        .background(Theme.danger.opacity(0.1), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Theme.danger.opacity(0.3)))
                        .transition(.scale(scale: 0.95).combined(with: .opacity))
                    } else if text.isEmpty {
                        Text("The result appears here")
                            .font(.system(size: 13))
                            .foregroundStyle(Theme.textTertiary)
                    }
                }
        } footer: {
            Button {
                if case .success(let output) = result { input = output }
            } label: {
                Label("Use as Input", systemImage: "arrow.uturn.left")
            }
            .buttonStyle(PillButtonStyle(kind: .ghost, size: .small))
            .disabled(text.isEmpty)
            .help("Move the output to the input to transform it again")
            Spacer()
            CopyButton(title: String(localized: "Copy Output"), kind: .primary, size: .small) {
                Clipboard.copy(text)
                toaster.show(String(localized: "Copied output"))
            }
            .disabled(text.isEmpty)
        }
    }

    @ViewBuilder
    private func statusBadge(_ result: Result<String, TransformError>) -> some View {
        switch result {
        case .success(let output) where !output.isEmpty:
            badge(String(localized: "Done"), systemImage: "checkmark", tint: Theme.success)
        case .failure:
            badge(String(localized: "Error"), systemImage: "xmark", tint: Theme.danger)
        default:
            EmptyView()
        }
    }

    private func badge(_ title: String, systemImage: String, tint: Color) -> some View {
        Label(title, systemImage: systemImage)
            .font(.system(size: 11, weight: .bold))
            .foregroundStyle(tint)
            .padding(.horizontal, 8)
            .frame(height: 22)
            .background(tint.opacity(0.14), in: Capsule())
            .transition(.scale.combined(with: .opacity))
    }

    // MARK: Transform

    private func output(_ result: Result<String, TransformError>) -> String {
        if case .success(let output) = result { output } else { "" }
    }

    private func transform() -> Result<String, TransformError> {
        guard !input.isEmpty else { return .success("") }
        do {
            return .success(try run())
        } catch let error as TransformError {
            return .failure(error)
        } catch {
            return .failure(TransformError(message: error.localizedDescription))
        }
    }

    private func run() throws -> String {
        switch (tool, mode) {
        case (.json, .minify): try TextTransforms.minifyJSON(input)
        case (.json, _): try TextTransforms.formatJSON(input)
        case (.xml, .minify): try TextTransforms.minifyXML(input)
        case (.xml, _): try TextTransforms.formatXML(input)
        case (.base64, .decode): try TextTransforms.decodeBase64(input)
        case (.base64, _): TextTransforms.encodeBase64(input, urlSafe: urlSafe)
        case (.jwt, _): try TextTransforms.decodeJWT(input)
        }
    }
}

/// A card holding a text editor, with a header and footer row of controls.
private struct EditorPane<Accessories: View, Content: View, Footer: View>: View {
    let title: String
    let systemImage: String
    @ViewBuilder var accessories: Accessories
    @ViewBuilder var content: Content
    @ViewBuilder var footer: Footer

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                SectionHeader(title: title, systemImage: systemImage)
                    .fixedSize()
                Spacer(minLength: 4)
                accessories
            }
            .frame(height: 30)

            content
                .padding(6)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Theme.sunken, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Theme.stroke))

            HStack(spacing: 8) { footer }
                .frame(height: 30)
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: Theme.Radius.large, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Theme.Radius.large, style: .continuous).strokeBorder(Theme.stroke))
    }
}

#Preview {
    UtilsView(pendingRequest: .constant(nil))
        .frame(width: 900, height: 600)
}
