import AppKit
import Observation

/// Редакторы, в которых можно открыть проект или файл.
enum CodeEditor: String, CaseIterable, Identifiable {
    case vscode, cursor, windsurf, zed, sublime, webstorm, idea, xcode, system
    var id: String { rawValue }

    var name: String {
        switch self {
        case .vscode: "Visual Studio Code"
        case .cursor: "Cursor"
        case .windsurf: "Windsurf"
        case .zed: "Zed"
        case .sublime: "Sublime Text"
        case .webstorm: "WebStorm"
        case .idea: "IntelliJ IDEA"
        case .xcode: "Xcode"
        case .system: tr("Приложение по умолчанию")
        }
    }

    var bundleID: String? {
        switch self {
        case .vscode: "com.microsoft.VSCode"
        case .cursor: "com.todesktop.230313mzl4w4u92"
        case .windsurf: "com.exafunction.windsurf"
        case .zed: "dev.zed.Zed"
        case .sublime: "com.sublimetext.4"
        case .webstorm: "com.jetbrains.WebStorm"
        case .idea: "com.jetbrains.intellij"
        case .xcode: "com.apple.dt.Xcode"
        case .system: nil
        }
    }

    /// URL для открытия файла на строке (nil — редактор не поддерживает переход по URL).
    func lineURL(path: String, line: Int) -> URL? {
        var allowed = CharacterSet.urlPathAllowed
        allowed.remove(charactersIn: "&?#")
        let enc = path.addingPercentEncoding(withAllowedCharacters: allowed) ?? path
        switch self {
        case .vscode: return URL(string: "vscode://file\(enc):\(line)")
        case .cursor: return URL(string: "cursor://file\(enc):\(line)")
        case .windsurf: return URL(string: "windsurf://file\(enc):\(line)")
        case .zed: return URL(string: "zed://file\(enc):\(line)")
        case .webstorm: return URL(string: "webstorm://open?file=\(enc)&line=\(line)")
        case .idea: return URL(string: "idea://open?file=\(enc)&line=\(line)")
        case .xcode: return URL(string: "xcode://open?url=file://\(enc)&line=\(line)")
        case .sublime, .system: return nil
        }
    }

    var appURL: URL? { bundleID.flatMap { NSWorkspace.shared.urlForApplication(withBundleIdentifier: $0) } }
    var isInstalled: Bool { self == .system || appURL != nil }
}

/// Выбранный редактор (по умолчанию VS Code), хранится в UserDefaults.
@Observable
final class EditorSettings {
    static let shared = EditorSettings()
    private static let key = "codeEditor"
    var editor: CodeEditor {
        didSet { UserDefaults.standard.set(editor.rawValue, forKey: Self.key) }
    }
    private init() {
        editor = CodeEditor(rawValue: UserDefaults.standard.string(forKey: Self.key) ?? "") ?? .vscode
    }

    /// Открывает файл или папку в выбранном редакторе; если он не установлен — в приложении по умолчанию.
    /// `line` — перейти на строку (где редактор это умеет: URL-схемы VS Code/Cursor/Windsurf/Zed/JetBrains/Xcode, CLI Sublime).
    func open(_ url: URL, line: Int? = nil) {
        guard let app = editor.appURL else { NSWorkspace.shared.open(url); return }
        if let line, let target = editor.lineURL(path: url.path, line: line) {
            NSWorkspace.shared.open([target], withApplicationAt: app, configuration: NSWorkspace.OpenConfiguration())
            return
        }
        if let line, editor == .sublime {
            let subl = app.appendingPathComponent("Contents/SharedSupport/bin/subl")
            if FileManager.default.isExecutableFile(atPath: subl.path) {
                let p = Process()
                p.executableURL = subl
                p.arguments = ["\(url.path):\(line)"]
                if (try? p.run()) != nil { return }
            }
        }
        NSWorkspace.shared.open([url], withApplicationAt: app, configuration: NSWorkspace.OpenConfiguration())
    }
}
