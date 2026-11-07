import Foundation
import SwiftData

/// A saved login. The password itself lives in the Keychain under `keychainID`.
@Model
final class SavedPassword {
    var keychainID: UUID = UUID()
    var title: String = ""
    var username: String = ""
    var website: String = ""
    var notes: String = ""
    var isFavorite: Bool = false
    var useCount: Int = 0
    var lastUsed: Date?
    var createdAt: Date = Date.now

    init(title: String, username: String = "", website: String = "", notes: String = "") {
        self.title = title
        self.username = username
        self.website = website
        self.notes = notes
    }

    var password: String {
        get { Keychain.password(for: keychainID.uuidString) ?? "" }
        set { Keychain.setPassword(newValue, for: keychainID.uuidString) }
    }

    /// `website` as a URL, adding `https://` when no scheme was typed.
    var websiteURL: URL? {
        let trimmed = website.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return nil }
        return URL(string: trimmed.contains("://") ? trimmed : "https://\(trimmed)")
    }

    /// Every whitespace-separated word in `query` must appear in the title, username, website or notes.
    func matches(_ query: String) -> Bool {
        let words = query.split(whereSeparator: \.isWhitespace)
        guard !words.isEmpty else { return true }
        let haystack = [title, username, website, notes].joined(separator: " ")
        return words.allSatisfy { haystack.localizedCaseInsensitiveContains($0) }
    }

    /// Removes the Keychain item. Call before deleting the model.
    func deleteSecret() {
        Keychain.deletePassword(for: keychainID.uuidString)
    }
}

enum PasswordGenerator {
    static func generate(length: Int = 20) -> String {
        // No look-alike characters (0/O, 1/l/I), so it's easy to read off the screen.
        let letters = Array("abcdefghijkmnopqrstuvwxyzABCDEFGHJKLMNPQRSTUVWXYZ")
        let digits = Array("23456789")
        let symbols = Array("!@#$%^&*-_=+?")
        let all = letters + digits + symbols
        var characters = [letters.randomElement()!, digits.randomElement()!, symbols.randomElement()!]
        while characters.count < length { characters.append(all.randomElement()!) }
        return String(characters.shuffled())
    }
}
