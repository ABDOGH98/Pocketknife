#if DEBUG
import AppKit
import SwiftData
import SwiftUI

/// Renders the marketing screenshots for the website, one screen per launch, in any language.
///
/// Debug builds only. Driven by launch arguments (they live in the argument domain, so nothing is
/// written to the user's preferences), with an in-memory database so real data is never touched:
///
///     Pocketknife.app/Contents/MacOS/Pocketknife -PKShot commands-dark -PKSection commands \
///         -themeAppearance dark -themePalette slate -AppleLanguages '(fr)'
///
/// The window is resized to 1280×820 points, drawn at 2× and saved as
/// `~/Library/Containers/com.miy33t.CliDB/Data/tmp/PKShots/<name>.png`, then the app quits.
/// `scripts/screenshots.sh` runs every screen in every language.
@MainActor
enum ScreenshotMode {
    static let shotName = UserDefaults.standard.string(forKey: "PKShot")
    static var isActive: Bool { shotName != nil }

    static var initialSection: AppSection? {
        switch UserDefaults.standard.string(forKey: "PKSection") {
        case "commands": .commands
        case "passwords": .passwords
        case "utils": .utils
        case "settings": .settings
        default: nil
        }
    }

    static let windowSize = NSSize(width: 1280, height: 820)

    static let utilityInput =
        #"{"user":{"id":42,"name":"Ada Lovelace","email":"ada@example.com","roles":["admin","developer"]},"plan":"pro","active":true,"lastLogin":"2026-11-07T09:30:00Z","limits":{"projects":25,"seats":5}}"#

    static func makeContainer() throws -> ModelContainer {
        let container = try ModelContainer(
            for: SavedCommand.self, SavedPassword.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        insertDemoData(into: container.mainContext)
        return container
    }

    // MARK: - Demo data

    private static func insertDemoData(into context: ModelContext) {
        let t = DemoText.current
        let now = Date.now
        let commands: [(String, String, [String], Int, TimeInterval, Bool)] = [
            (t.podLogs, "kubectl -n {{namespace:default}} logs -f {{pod}} --tail={{lines:100}}", ["kubernetes"], 14, 10, false),
            (t.largeFiles, "find {{path:.}} -type f -size +{{size:100M}}", ["files"], 9, 3_600, false),
            (t.dockerShell, "docker exec -it {{container}} /bin/{{shell:bash|bash,sh,zsh}}", ["docker"], 7, 7_200, true),
            (t.killPort, "lsof -ti :{{port:3000}} | xargs kill -9", ["network", "process"], 5, 86_400, false),
            (t.gitBranch, "git checkout -b {{type|feature,fix,chore}}/{{name}}", ["git"], 4, 172_800, false),
            (t.postgres, "psql -h {{host:localhost}} -U {{user:postgres}} {{database}}", ["database"], 2, 259_200, false),
        ]
        for (index, item) in commands.enumerated() {
            let command = SavedCommand(title: item.0, template: item.1, tags: item.2)
            command.useCount = item.3
            command.lastUsed = now.addingTimeInterval(-item.4)
            command.isFavorite = item.5
            command.createdAt = now.addingTimeInterval(-Double(1_000_000 - index))
            context.insert(command)
        }

        let logins: [(String, String, String, String, TimeInterval?)] = [
            ("AWS Console", "ada@acme.dev", "console.aws.amazon.com", t.stagingNote, 3_000),
            ("Docker Hub", "adalovelace", "hub.docker.com", "", nil),
            ("GitHub", "ada-dev", "github.com", "", nil),
            (t.stagingDatabase, "app_readonly", "", "", nil),
        ]
        for item in logins {
            let login = SavedPassword(title: item.0, username: item.1, website: item.2, notes: item.3)
            login.lastUsed = item.4.map { now.addingTimeInterval(-$0) }
            context.insert(login)
        }
        try? context.save()
    }

    // MARK: - Capture

    /// Sizes the main window, waits for it to settle, draws it at 2× and quits.
    static func captureWhenReady() {
        guard let name = shotName else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            guard let window = NSApp.windows.first(where: { $0.identifier?.rawValue.hasPrefix("main") == true || $0.isVisible }) else { return }
            window.setContentSize(windowSize)
            // Draw at 2×: put the window on a Retina screen if one is connected.
            if let retina = NSScreen.screens.first(where: { $0.backingScaleFactor >= 2 }) {
                let area = retina.visibleFrame
                window.setFrameOrigin(NSPoint(x: area.midX - window.frame.width / 2, y: area.midY - window.frame.height / 2))
            } else {
                window.center()
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
                if UserDefaults.standard.bool(forKey: "PKExternalCapture") {
                    // scripts/screenshots.sh captures the window with `screencapture -l` (which draws
                    // every layer, unlike cacheDisplay) and then quits the app.
                    print("PKWindow \(window.windowNumber)")
                    fflush(stdout)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 15) { NSApp.terminate(nil) }
                } else {
                    save(window: window, name: name)
                    NSApp.terminate(nil)
                }
            }
        }
    }

    private static func save(window: NSWindow, name: String) {
        // The theme frame includes the traffic-light buttons drawn over the hidden title bar.
        guard let view = window.contentView?.superview ?? window.contentView else { return }
        let bounds = view.bounds
        guard let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: Int(bounds.width * 2), pixelsHigh: Int(bounds.height * 2),
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
            colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
        ) else { return }
        rep.size = bounds.size
        view.cacheDisplay(in: bounds, to: rep)

        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("PKShots", isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let url = folder.appendingPathComponent("\(name).png")
        try? rep.representation(using: .png, properties: [:])?.write(to: url)
        print("PKShot saved \(url.path)")
    }
}

/// The few demo strings that are user data rather than UI, translated so each language's
/// screenshots look like a real person's library. Tags and brand names stay as they are.
private struct DemoText {
    let podLogs, largeFiles, dockerShell, killPort, gitBranch, postgres, stagingDatabase, stagingNote: String

    static var current: DemoText {
        let code = Bundle.main.preferredLocalizations.first ?? "en"
        return all[code] ?? all["en"]!
    }

    static let all: [String: DemoText] = [
        "en": .init(podLogs: "Follow pod logs", largeFiles: "Find large files", dockerShell: "Shell into Docker container", killPort: "Kill process on port", gitBranch: "New git branch", postgres: "Connect to Postgres", stagingDatabase: "Staging database", stagingNote: "Staging account 4821."),
        "es": .init(podLogs: "Seguir logs del pod", largeFiles: "Buscar archivos grandes", dockerShell: "Entrar en un contenedor Docker", killPort: "Matar proceso en un puerto", gitBranch: "Nueva rama de git", postgres: "Conectar a Postgres", stagingDatabase: "Base de datos de staging", stagingNote: "Cuenta de staging 4821."),
        "fr": .init(podLogs: "Suivre les logs du pod", largeFiles: "Trouver les gros fichiers", dockerShell: "Shell dans un conteneur Docker", killPort: "Tuer le processus d’un port", gitBranch: "Nouvelle branche git", postgres: "Se connecter à Postgres", stagingDatabase: "Base de données de staging", stagingNote: "Compte de staging 4821."),
        "de": .init(podLogs: "Pod-Logs verfolgen", largeFiles: "Große Dateien finden", dockerShell: "Shell im Docker-Container", killPort: "Prozess auf Port beenden", gitBranch: "Neuer Git-Branch", postgres: "Mit Postgres verbinden", stagingDatabase: "Staging-Datenbank", stagingNote: "Staging-Konto 4821."),
        "pt-BR": .init(podLogs: "Acompanhar logs do pod", largeFiles: "Encontrar arquivos grandes", dockerShell: "Shell em um contêiner Docker", killPort: "Encerrar processo na porta", gitBranch: "Nova branch do git", postgres: "Conectar ao Postgres", stagingDatabase: "Banco de dados de staging", stagingNote: "Conta de staging 4821."),
        "it": .init(podLogs: "Segui i log del pod", largeFiles: "Trova file grandi", dockerShell: "Shell in un container Docker", killPort: "Termina il processo sulla porta", gitBranch: "Nuovo branch git", postgres: "Connettiti a Postgres", stagingDatabase: "Database di staging", stagingNote: "Account di staging 4821."),
        "nl": .init(podLogs: "Pod-logs volgen", largeFiles: "Grote bestanden zoeken", dockerShell: "Shell in Docker-container", killPort: "Proces op poort stoppen", gitBranch: "Nieuwe git-branch", postgres: "Verbinden met Postgres", stagingDatabase: "Staging-database", stagingNote: "Staging-account 4821."),
        "pl": .init(podLogs: "Śledź logi poda", largeFiles: "Znajdź duże pliki", dockerShell: "Powłoka w kontenerze Docker", killPort: "Zabij proces na porcie", gitBranch: "Nowa gałąź git", postgres: "Połącz z Postgres", stagingDatabase: "Baza danych staging", stagingNote: "Konto staging 4821."),
        "tr": .init(podLogs: "Pod loglarını izle", largeFiles: "Büyük dosyaları bul", dockerShell: "Docker konteynerine bağlan", killPort: "Porttaki işlemi sonlandır", gitBranch: "Yeni git dalı", postgres: "Postgres’e bağlan", stagingDatabase: "Staging veritabanı", stagingNote: "Staging hesabı 4821."),
        "ru": .init(podLogs: "Следить за логами пода", largeFiles: "Найти большие файлы", dockerShell: "Shell в контейнере Docker", killPort: "Завершить процесс на порту", gitBranch: "Новая ветка git", postgres: "Подключиться к Postgres", stagingDatabase: "База данных staging", stagingNote: "Тестовый аккаунт 4821."),
        "uk": .init(podLogs: "Стежити за логами пода", largeFiles: "Знайти великі файли", dockerShell: "Shell у контейнері Docker", killPort: "Завершити процес на порту", gitBranch: "Нова гілка git", postgres: "Під’єднатися до Postgres", stagingDatabase: "База даних staging", stagingNote: "Тестовий акаунт 4821."),
        "ar": .init(podLogs: "متابعة سجلات الـ pod", largeFiles: "البحث عن الملفات الكبيرة", dockerShell: "الدخول إلى حاوية Docker", killPort: "إنهاء العملية على منفذ", gitBranch: "فرع git جديد", postgres: "الاتصال بـ Postgres", stagingDatabase: "قاعدة بيانات الاختبار", stagingNote: "حساب الاختبار 4821."),
        "he": .init(podLogs: "מעקב אחר לוגים של pod", largeFiles: "חיפוש קבצים גדולים", dockerShell: "Shell בתוך קונטיינר Docker", killPort: "סגירת תהליך בפורט", gitBranch: "ענף git חדש", postgres: "התחברות ל-Postgres", stagingDatabase: "מסד נתונים של staging", stagingNote: "חשבון staging 4821."),
        "hi": .init(podLogs: "पॉड लॉग फ़ॉलो करें", largeFiles: "बड़ी फ़ाइलें खोजें", dockerShell: "Docker कंटेनर में शेल", killPort: "पोर्ट पर प्रोसेस बंद करें", gitBranch: "नई git ब्रांच", postgres: "Postgres से कनेक्ट करें", stagingDatabase: "स्टेजिंग डेटाबेस", stagingNote: "स्टेजिंग खाता 4821."),
        "id": .init(podLogs: "Ikuti log pod", largeFiles: "Cari file besar", dockerShell: "Shell ke kontainer Docker", killPort: "Hentikan proses di port", gitBranch: "Branch git baru", postgres: "Hubungkan ke Postgres", stagingDatabase: "Database staging", stagingNote: "Akun staging 4821."),
        "vi": .init(podLogs: "Theo dõi log của pod", largeFiles: "Tìm tệp lớn", dockerShell: "Mở shell trong container Docker", killPort: "Dừng tiến trình trên cổng", gitBranch: "Nhánh git mới", postgres: "Kết nối Postgres", stagingDatabase: "Cơ sở dữ liệu staging", stagingNote: "Tài khoản staging 4821."),
        "ja": .init(podLogs: "Pod のログを追跡", largeFiles: "大きなファイルを検索", dockerShell: "Docker コンテナに入る", killPort: "ポートのプロセスを終了", gitBranch: "新しい git ブランチ", postgres: "Postgres に接続", stagingDatabase: "ステージング DB", stagingNote: "ステージング用アカウント 4821。"),
        "ko": .init(podLogs: "Pod 로그 따라가기", largeFiles: "큰 파일 찾기", dockerShell: "Docker 컨테이너 셸 접속", killPort: "포트의 프로세스 종료", gitBranch: "새 git 브랜치", postgres: "Postgres에 연결", stagingDatabase: "스테이징 데이터베이스", stagingNote: "스테이징 계정 4821."),
        "zh-Hans": .init(podLogs: "跟踪 Pod 日志", largeFiles: "查找大文件", dockerShell: "进入 Docker 容器", killPort: "结束端口上的进程", gitBranch: "新建 git 分支", postgres: "连接 Postgres", stagingDatabase: "预发布数据库", stagingNote: "预发布账号 4821。"),
        "zh-Hant": .init(podLogs: "追蹤 Pod 日誌", largeFiles: "尋找大型檔案", dockerShell: "進入 Docker 容器", killPort: "結束連接埠上的程序", gitBranch: "新增 git 分支", postgres: "連線到 Postgres", stagingDatabase: "預備環境資料庫", stagingNote: "預備環境帳號 4821。"),
    ]
}
#endif
