import Foundation
import Testing
@testable import Pocketknife

struct SavedPasswordTests {
    @Test func searchMatchesTitleUsernameAndWebsite() {
        let login = SavedPassword(title: "GitHub", username: "octocat", website: "github.com")
        #expect(login.matches("git octo"))
        #expect(login.matches("GITHUB.COM"))
        #expect(!login.matches("gitlab"))
        #expect(login.matches("  "))
    }

    @Test func websiteURLAddsSchemeWhenMissing() {
        #expect(SavedPassword(title: "a", website: "example.com").websiteURL?.absoluteString == "https://example.com")
        #expect(SavedPassword(title: "a", website: "http://x.dev").websiteURL?.absoluteString == "http://x.dev")
        #expect(SavedPassword(title: "a").websiteURL == nil)
    }

    @Test func generatedPasswordsMixCharacterKinds() {
        for _ in 0..<50 {
            let password = PasswordGenerator.generate(length: 20)
            #expect(password.count == 20)
            let hasLetter = password.contains(where: \.isLetter)
            let hasDigit = password.contains(where: \.isNumber)
            let hasSymbol = password.contains(where: { "!@#$%^&*-_=+?".contains($0) })
            #expect(hasLetter && hasDigit && hasSymbol)
        }
    }
}

@Test func passwordStrengthRatings() {
    #expect(PasswordStrength("") == .empty)
    #expect(PasswordStrength("abc123") == .weak)
    #expect(PasswordStrength("abcdefgh1234") == .fair)
    #expect(PasswordStrength("Abcdefgh1234!xyz") == .strong)
    #expect(PasswordStrength("aaaaaaaaaaaaaaaaaaaa") == .fair)
    #expect(PasswordStrength(PasswordGenerator.generate()) == .strong)
}
