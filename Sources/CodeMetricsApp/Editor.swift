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
    func open(_ url: URL) {
        if let app = editor.appURL {
            NSWorkspace.shared.open([url], withApplicationAt: app, configuration: NSWorkspace.OpenConfiguration())
        } else {
            NSWorkspace.shared.open(url)
        }
    }
}
