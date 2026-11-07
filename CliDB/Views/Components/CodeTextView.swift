import AppKit
import SwiftUI

/// A plain-text, monospaced editor backed by `NSTextView`, with the system find bar (⌘F).
///
/// Bump `findRequest` to focus the view and show its find bar.
struct CodeTextView: NSViewRepresentable {
    @Binding var text: String
    var isEditable = true
    var findRequest = 0

    func makeCoordinator() -> Coordinator { Coordinator(text: $text) }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSTextView.scrollableTextView()
        scrollView.drawsBackground = false
        scrollView.autohidesScrollers = true

        let textView = scrollView.documentView as! NSTextView
        textView.delegate = context.coordinator
        textView.font = .monospacedSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
        textView.drawsBackground = false
        textView.isRichText = false
        textView.importsGraphics = false
        textView.allowsUndo = true
        textView.usesFindBar = true
        textView.isIncrementalSearchingEnabled = true
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.isContinuousSpellCheckingEnabled = false
        textView.textContainerInset = NSSize(width: 2, height: 6)
        // Code reads left to right even when the app is in a right-to-left language.
        textView.baseWritingDirection = .leftToRight
        textView.alignment = .left
        textView.string = text
        context.coordinator.lastFindRequest = findRequest
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView else { return }
        context.coordinator.text = $text
        textView.isEditable = isEditable
        textView.isSelectable = true

        if textView.string != text {
            let selection = textView.selectedRanges
            textView.string = text
            let length = (text as NSString).length
            textView.selectedRanges = selection.map { value in
                let range = value.rangeValue
                let location = min(range.location, length)
                return NSValue(range: NSRange(location: location, length: min(range.length, length - location)))
            }
        }

        if findRequest != context.coordinator.lastFindRequest {
            context.coordinator.lastFindRequest = findRequest
            DispatchQueue.main.async {
                textView.window?.makeFirstResponder(textView)
                let item = NSMenuItem()
                item.tag = NSTextFinder.Action.showFindInterface.rawValue
                textView.performTextFinderAction(item)
            }
        }
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        var text: Binding<String>
        var lastFindRequest = 0

        init(text: Binding<String>) { self.text = text }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            text.wrappedValue = textView.string
        }
    }
}
