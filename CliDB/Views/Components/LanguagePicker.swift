import SwiftUI

/// Lets people pick the app's language, then offers to restart so it takes effect.
struct LanguagePicker: View {
    enum Style {
        /// A compact globe menu, for the Home screen.
        case menu
        /// A labeled picker row, for the Settings window.
        case form
    }

    var style: Style = .form

    /// "" means "same as the Mac".
    @State private var selection = AppLanguage.chosen ?? ""
    @State private var isAskingToRestart = false

    var body: some View {
        Group {
            switch style {
            case .menu:
                Menu {
                    picker.pickerStyle(.inline)
                } label: {
                    Label(AppLanguage.nativeName(AppLanguage.current), systemImage: "globe")
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
                .help(Text("Change the app’s language"))
            case .form:
                picker
            }
        }
        .onChange(of: selection) {
            AppLanguage.choose(selection.isEmpty ? nil : selection)
            // Only ask when the app would actually look different after a restart.
            isAskingToRestart = AppLanguage.effective != AppLanguage.current
        }
        .alert(
            Text("Restart to switch to \(AppLanguage.nativeName(AppLanguage.effective))?"),
            isPresented: $isAskingToRestart
        ) {
            Button("Restart Now") { AppLanguage.relaunch() }
            Button("Later", role: .cancel) {}
        } message: {
            Text("Pocketknife will close and reopen. Unsaved changes in open editors will be lost.")
        }
    }

    private var picker: some View {
        Picker("Language", selection: $selection) {
            Text("Same as Mac (\(AppLanguage.nativeName(AppLanguage.macLanguage)))").tag("")
            Divider()
            ForEach(AppLanguage.supported, id: \.self) { code in
                Text(verbatim: AppLanguage.nativeName(code)).tag(code)
            }
        }
    }
}

/// The app's Settings window (⌘,).
struct SettingsView: View {
    var body: some View {
        Form {
            Section {
                LanguagePicker(style: .form)
            } footer: {
                FormHint("Pocketknife restarts to apply a new language.")
            }
        }
        .formStyle(.grouped)
        .frame(width: 440)
        .fixedSize(horizontal: false, vertical: true)
    }
}
