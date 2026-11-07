import AppKit

@MainActor
enum Clipboard {
    static func copy(_ string: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(string, forType: .string)
    }

    /// Copies a password: marked concealed so clipboard managers skip it, and cleared after
    /// `clearAfter` unless something else has been copied since.
    static func copySecret(_ string: String, clearAfter delay: Duration = .seconds(60)) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(string, forType: .string)
        pasteboard.setString("", forType: NSPasteboard.PasteboardType("org.nspasteboard.ConcealedType"))
        let changeCount = pasteboard.changeCount
        Task {
            try? await Task.sleep(for: delay)
            if pasteboard.changeCount == changeCount { pasteboard.clearContents() }
        }
    }
}
