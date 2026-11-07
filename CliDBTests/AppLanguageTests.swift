import Foundation
import Testing
@testable import Pocketknife

@MainActor
struct AppLanguageTests {
    @Test func readsTheMacLanguageFromInsideTheSandbox() {
        let global = UserDefaults.standard.persistentDomain(forName: UserDefaults.globalDomain)?["AppleLanguages"] as? [String]
        #expect(global?.isEmpty == false, "The global AppleLanguages preference should be readable")
        #expect(AppLanguage.supported.contains(AppLanguage.macLanguage))
    }

    @Test func namesEachLanguageInItself() {
        #expect(AppLanguage.nativeName("de") == "Deutsch")
        #expect(AppLanguage.nativeName("ja") == "日本語")
        #expect(AppLanguage.nativeName("es") == "Español")
        #expect(AppLanguage.supported.allSatisfy { !AppLanguage.nativeName($0).isEmpty })
    }
}
