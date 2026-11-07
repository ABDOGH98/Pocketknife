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

    var systemImage: String {
        switch self {
        case .json: "curlybraces"
        case .xml: "chevron.left.forwardslash.chevron.right"
        case .base64: "number"
        case .jwt: "key"
        }
    }

    var modes: [UtilityMode] {
        switch self {
        case .json, .xml: [.format, .minify]
        case .base64: [.encode, .decode]
        case .jwt: [.decode]
        }
    }
}

enum UtilityMode: String, Identifiable {
    case format = "Format", minify = "Minify", encode = "Encode", decode = "Decode"
    var id: Self { self }
}

struct UtilsView: View {
    var onHome: () -> Void = {}

    @State private var tool: UtilityTool? = .json
    @State private var inputs: [UtilityTool: String] = [:]
    @State private var modes: [UtilityTool: UtilityMode] = [:]
    @State private var urlSafe = false
    @State private var toaster = Toaster()

    var body: some View {
        NavigationSplitView {
            List(UtilityTool.allCases, selection: $tool) { tool in
                Label(tool.title, systemImage: tool.systemImage)
            }
            .navigationSplitViewColumnWidth(min: 160, ideal: 180, max: 240)
        } detail: {
            if let tool {
                UtilityToolView(
                    tool: tool,
                    input: Binding(get: { inputs[tool, default: ""] }, set: { inputs[tool] = $0 }),
                    mode: Binding(get: { modes[tool] ?? tool.modes[0] }, set: { modes[tool] = $0 }),
                    urlSafe: $urlSafe,
                    toaster: toaster
                )
                .id(tool)
            }
        }
        .navigationTitle("Utilities")
        .toolbar { HomeToolbarButton(action: onHome) }
        .toast(toaster)
    }
}

private struct UtilityToolView: View {
    let tool: UtilityTool
    @Binding var input: String
    @Binding var mode: UtilityMode
    @Binding var urlSafe: Bool
    let toaster: Toaster

    @Environment(\.openWindow) private var openWindow
    @State private var inputFindRequest = 0
    @State private var outputFindRequest = 0

    var body: some View {
        let result = transform()
        let outputText = output(result)
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                if tool.modes.count > 1 {
                    Picker("Mode", selection: $mode) {
                        ForEach(tool.modes) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .fixedSize()
                }

                if tool == .base64, mode == .encode {
                    Toggle("URL-safe", isOn: $urlSafe)
                        .toggleStyle(.checkbox)
                        .help("Use - and _ instead of + and /, without = padding")
                }

                Spacer()

                Button("Paste", systemImage: "doc.on.clipboard") {
                    if let text = NSPasteboard.general.string(forType: .string) { input = text }
                }
                Button("Clear", systemImage: "xmark.circle") { input = "" }
                    .disabled(input.isEmpty)
            }

            editor(title: "Input") {
                findButton { inputFindRequest += 1 }
            } content: {
                CodeTextView(text: $input, findRequest: inputFindRequest)
            }

            HStack {
                if case .failure(let error) = result {
                    Label(error.message, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                        .lineLimit(2)
                        .textSelection(.enabled)
                }
                Spacer()
                Button("Use as Input", systemImage: "arrow.up") {
                    if case .success(let output) = result { input = output }
                }
                .disabled(outputText.isEmpty)
                Button("Copy Output", systemImage: "doc.on.doc") {
                    Clipboard.copy(outputText)
                    toaster.show("Copied output")
                }
                .disabled(outputText.isEmpty)
            }

            editor(title: "Output") {
                findButton { outputFindRequest += 1 }
                Button("Expand", systemImage: "arrow.up.left.and.arrow.down.right") {
                    openWindow(id: ExpandedOutput.windowID, value: ExpandedOutput(title: "\(tool.title) \(mode.rawValue) Output", text: outputText))
                }
                .labelStyle(.iconOnly)
                .buttonStyle(.borderless)
                .help("Open the output in a large window")
                .disabled(outputText.isEmpty)
            } content: {
                CodeTextView(text: .constant(outputText), isEditable: false, findRequest: outputFindRequest)
            }
        }
        .padding(20)
        .navigationSubtitle(tool.title)
    }

    private func editor(
        title: String,
        @ViewBuilder accessories: () -> some View,
        @ViewBuilder content: () -> some View
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 10) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.secondary)
                Spacer()
                accessories()
            }
            content()
                .padding(4)
                .background(.background, in: RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(.separator))
        }
    }

    private func findButton(action: @escaping () -> Void) -> some View {
        Button("Find", systemImage: "magnifyingglass", action: action)
            .labelStyle(.iconOnly)
            .buttonStyle(.borderless)
            .help("Search (⌘F)")
    }

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

#Preview {
    UtilsView()
        .frame(width: 900, height: 600)
}
