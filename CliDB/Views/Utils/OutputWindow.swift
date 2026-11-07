import SwiftUI

/// The text shown in a standalone output window, opened from the Utilities section.
struct ExpandedOutput: Codable, Hashable {
    static let windowID = "utility-output"

    var title: String
    var text: String
}

/// A large, resizable window for reading output; supports full screen and ⌘F search.
struct OutputWindow: View {
    let output: ExpandedOutput

    @State private var findRequest = 0
    @State private var toaster = Toaster()

    var body: some View {
        CodeTextView(text: .constant(output.text), isEditable: false, findRequest: findRequest)
            .padding(10)
            .background(Theme.sunken, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Theme.stroke))
            .padding(12)
            .frame(minWidth: 500, minHeight: 300)
            .navigationTitle(output.title)
            .toolbar {
                ToolbarItemGroup {
                    Button("Find", systemImage: "magnifyingglass") { findRequest += 1 }
                        .help("Search the output (⌘F)")
                    Button("Copy", systemImage: "doc.on.doc") {
                        Clipboard.copy(output.text)
                        toaster.show(String(localized: "Copied output"))
                    }
                    .help("Copy the output")
                    Button("Full Screen", systemImage: "arrow.up.left.and.arrow.down.right") {
                        NSApp.keyWindow?.toggleFullScreen(nil)
                    }
                    .help("Enter or exit full screen (⌃⌘F)")
                }
            }
            .toast(toaster)
    }
}
