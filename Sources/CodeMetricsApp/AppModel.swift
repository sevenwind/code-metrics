import SwiftUI
import CodeMetricsCore
import AppKit

enum NavSection: String, CaseIterable, Identifiable {
    case overview = "Обзор"
    case files = "Файлы"
    case functions = "Функции"
    case folders = "Папки"
    var id: String { rawValue }
    var title: String { tr(rawValue) }
    var icon: String {
        switch self {
        case .overview: "chart.pie"
        case .files: "doc.text"
        case .functions: "function"
        case .folders: "folder.badge.gearshape"
        }
    }
}

/// Цвет по индексу CRAP: плавно от зелёного (≤ 1) к красному (≥ 30).
func crapColor(_ v: Double) -> Color {
    let t = min(1, max(0, (v - 1) / 29))
    return Color(hue: 0.33 * (1 - t), saturation: 0.75, brightness: 0.85)
}

/// Градиент «хорошо → плохо» (зелёный → красный) для доли t: 0 — хорошо, 1 — плохо.
func badnessColor(_ t: Double) -> Color { crapColor(1 + min(1, max(0, t)) * 29) }

/// Пороги оценки, общие для всех экранов.
enum Severity {
    case good, warn, bad
    var color: Color {
        switch self { case .good: .green; case .warn: .orange; case .bad: .red }
    }
    static func cyclomatic(_ v: Int) -> Severity { v > 20 ? .bad : v > 10 ? .warn : .good }
    static func cognitive(_ v: Int) -> Severity { v > 25 ? .bad : v > 15 ? .warn : .good }
    static func length(_ v: Int) -> Severity { v > 100 ? .bad : v > 50 ? .warn : .good }
    static func coverage(_ v: Double) -> Severity { v < 0.5 ? .bad : v < 0.8 ? .warn : .good }
    static func maintainability(_ v: Double) -> Severity { v < 20 ? .bad : v < 40 ? .warn : .good }
}

struct FunctionRow: Identifiable, Hashable {
    let id: String
    let file: String
    let language: String
    let fn: FunctionMetrics
    var name: String { fn.name }
    var cyclomatic: Int { fn.cyclomatic }
    var cognitive: Int { fn.cognitive }
    var length: Int { fn.length }
    var parameters: Int { fn.parameters }
    var nesting: Int { fn.maxNesting }
    var line: Int { fn.startLine }
    /// Покрытие функции (0–1); -1 — нет данных.
    var coverage: Double = -1
    /// CRAP = CC² · (1 − покрытие)³ + CC; -1, если нет данных о покрытии.
    var crap: Double { coverage < 0 ? -1 : pow(Double(cyclomatic), 2) * pow(1 - coverage, 3) + Double(cyclomatic) }
}

@MainActor
@Observable
final class AppModel {
    var root: URL?
    var report: ProjectReport?
    var functionRows: [FunctionRow] = []
    var isScanning = false
    var progress: Double = 0
    var currentFile = ""
    var section: NavSection = .overview
    var search = ""
    var includeTests = true
    var recents: [URL] = []

    // Состояние экранов. @State недоступен без полного Xcode (нет плагина SwiftUIMacros), поэтому оно живёт здесь.
    var dropTargeted = false
    var filesSort = [KeyPathComparator(\FileMetrics.maxCyclomatic, order: .reverse)]
    var filesSelection: FileMetrics.ID?
    var languageFilter = "Все"
    var functionsSort = [KeyPathComparator(\FunctionRow.cyclomatic, order: .reverse)]
    var functionsSelection: FunctionRow.ID?
    var minCC = 1
    var infoShown: Metric?
    var errorDetailShown = false
    var coverage: CoverageReport?
    var coverageNote = ""
    var coverageLog = ""
    var coverageRunning = false
    var coverageProgress = 0.0

    /// Исключения для текущего проекта: относительные пути папок и отдельных файлов.
    var excluded: Set<String> = []
    /// Папки из списка «по умолчанию пропускаются» (node_modules и т.п.), которые пользователь вернул в анализ.
    var forceIncluded: Set<String> = []

    private var task: Task<Void, Never>?
    private static let recentsKey = "recentFolders"

    init() {
        recents = (UserDefaults.standard.stringArray(forKey: Self.recentsKey) ?? []).map { URL(fileURLWithPath: $0) }
            .filter { FileManager.default.fileExists(atPath: $0.path) }
    }

    func chooseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.prompt = tr("Сканировать")
        panel.message = tr("Выберите папку проекта")
        if panel.runModal() == .OK, let url = panel.url { open(url) }
    }

    private func key(_ kind: String) -> String { "\(kind):\(root?.path ?? "")" }

    private func saveRules() {
        UserDefaults.standard.set(Array(excluded), forKey: key("excluded"))
        UserDefaults.standard.set(Array(forceIncluded), forKey: key("included"))
    }

    func exclude(_ paths: [String]) {
        excluded.formUnion(paths); forceIncluded.subtract(paths); saveRules(); rescan()
    }

    /// Возвращает путь в анализ: снимает пользовательское исключение и, для автопропущенных папок, форсирует включение.
    func include(_ path: String) {
        excluded.remove(path)
        if report?.autoIgnored.contains(path) == true { forceIncluded.insert(path) }
        saveRules(); rescan()
    }

    func open(_ url: URL) {
        root = url
        excluded = Set(UserDefaults.standard.stringArray(forKey: key("excluded")) ?? [])
        forceIncluded = Set(UserDefaults.standard.stringArray(forKey: key("included")) ?? [])
        recents.removeAll { $0 == url }
        recents.insert(url, at: 0)
        recents = Array(recents.prefix(8))
        UserDefaults.standard.set(recents.map(\.path), forKey: Self.recentsKey)
        rescan()
    }

    func rescan() {
        guard let root else { return }
        task?.cancel()
        isScanning = true
        progress = 0
        currentFile = ""
        var options = ScanOptions()
        options.includeTests = includeTests
        options.excludedPaths = excluded
        options.includedPaths = forceIncluded
        task = Task {
            let result = await ProjectScanner.scan(root: root, options: options) { p in
                Task { @MainActor in
                    guard self.isScanning else { return }
                    self.progress = p.total == 0 ? 1 : Double(p.processed) / Double(p.total)
                    self.currentFile = p.currentFile
                }
            }
            if Task.isCancelled { return }
            self.report = result
            self.functionRows = result.files.flatMap { f in
                f.functions.map { FunctionRow(id: "\(f.path)#\($0.id)", file: f.path, language: f.language, fn: $0) }
            }
            self.isScanning = false
            self.loadCoverage()
        }
    }

    // MARK: Покрытие тестами

    /// Читает отчёт покрытия: сохранённый для проекта файл или найденный автоматически.
    func loadCoverage(from picked: URL? = nil) {
        guard let report, let root else { return }
        if let picked { UserDefaults.standard.set(picked.path, forKey: key("coverage")) }
        let saved = UserDefaults.standard.string(forKey: key("coverage")).map { URL(fileURLWithPath: $0) }
        let url = picked ?? saved.flatMap { FileManager.default.fileExists(atPath: $0.path) ? $0 : nil } ?? CoverageLoader.discover(root: root)
        guard let url else { applyCoverage(nil, note: tr("Отчёт не найден")); return }
        let paths = report.files.map(\.path), rootPath = report.root
        Task {
            let cov = await Task.detached { CoverageLoader.load(report: url, projectPaths: paths, root: rootPath) }.value
            let usable = cov.map { !$0.files.isEmpty } ?? false
            applyCoverage(usable ? cov : nil, note: usable ? "" : tr("Не удалось разобрать %@", url.lastPathComponent))
            if !usable {
                coverageLog = tr("Файл %@ найден, но его не удалось разобрать или ни одна запись не совпала с файлами проекта (поддерживаются lcov, Istanbul coverage-final.json и Go coverage.out).", url.path)
            }
        }
    }

    func applyCoverage(_ cov: CoverageReport?, note: String) {
        coverage = cov
        coverageNote = note
        guard var report else { return }
        for i in report.files.indices {
            report.files[i].coverage = cov?.files[report.files[i].path]?.ratio() ?? -1
        }
        self.report = report
        for i in functionRows.indices {
            let r = functionRows[i]
            functionRows[i].coverage = cov?.files[r.file]?.ratio(in: r.fn.startLine...r.fn.endLine) ?? -1
        }
    }

    /// Команда запуска тестов с генерацией отчёта покрытия по типу проекта (nil — тип не определён).
    private func coverageCommand(root: URL) -> String? {
        let fm = FileManager.default
        let hasGo = fm.fileExists(atPath: root.appendingPathComponent("go.mod").path)
        let pkg = root.appendingPathComponent("package.json")
        let hasJS = fm.fileExists(atPath: pkg.path)
        let goTop = report?.languages.first?.language.lowercased().hasPrefix("go") == true
        func js() -> String {
            let text = (try? String(contentsOf: pkg, encoding: .utf8)) ?? ""
            if text.contains("\"vitest\"") { return "npx vitest run --coverage --coverage.reportsDirectory=coverage --coverage.reporter=lcov --coverage.reporter=json" }
            return "npx jest --coverage --coverageDirectory=coverage --coverageReporters=lcov --coverageReporters=json"
        }
        if hasGo && (goTop || !hasJS) { return "go test -coverprofile=coverage.out ./..." }
        if hasJS { return js() }
        return nil
    }

    /// Сколько «единиц» ожидается в выводе тестов: тестовые файлы (JS/TS) или папки с *_test.go (Go). Нужно для процентов прогресса.
    nonisolated private static func countTestUnits(root: URL, go: Bool) -> Int {
        let skip: Set<String> = ["node_modules", ".git", "vendor", "dist", "build", "coverage", ".build"]
        guard let en = FileManager.default.enumerator(at: root, includingPropertiesForKeys: [.isDirectoryKey]) else { return 0 }
        var files = 0
        var dirs = Set<String>()
        for case let url as URL in en {
            let name = url.lastPathComponent
            if skip.contains(name) { en.skipDescendants(); continue }
            if go { if name.hasSuffix("_test.go") { dirs.insert(url.deletingLastPathComponent().path) } }
            else if (name.contains(".test.") || name.contains(".spec."))
                        && ["ts", "tsx", "js", "jsx", "mjs", "cjs"].contains(url.pathExtension) { files += 1 }
        }
        return go ? dirs.count : files
    }

    /// Считает завершённые «единицы» в выводе: jest (PASS/FAIL file), vitest (✓/❯ file.test.ts), go (ok/FAIL/? package).
    nonisolated private static func isProgressLine(_ raw: String) -> Bool {
        let line = raw.replacingOccurrences(of: "\u{1B}\\[[0-9;]*m", with: "", options: .regularExpression)
        if line.range(of: "^(PASS|FAIL) +\\S", options: .regularExpression) != nil { return true }
        if line.range(of: "^\\s*[✓❯×↓] +\\S+\\.(test|spec)\\.", options: .regularExpression) != nil { return true }
        if line.range(of: "^(ok|FAIL)[ \\t]+\\S+[ \\t]", options: .regularExpression) != nil { return true }
        return false
    }

    /// Разбор причины неудачи: краткая заметка + подробное описание для тултипа.
    private func diagnose(status: Int32, log: String, cmd: String, reportFound: Bool) -> (note: String, detail: String) {
        let tail = log.split(whereSeparator: \.isNewline).suffix(12).joined(separator: "\n")
        let searched = CoverageLoader.candidates.joined(separator: ", ")
        var parts = [tr("Команда: %@", cmd), tr("Код завершения: %ld", Int(status))]
        let note: String
        if status != 0 {
            note = tr("Тесты завершились с ошибкой (%ld)", Int(status))
            if status == 127 { parts.append(tr("Команда не найдена: node/npx или go недоступны в PATH приложения.")) }
            else if log.contains("coverage-v8") || log.contains("@vitest/coverage") || log.contains("coverage-istanbul") {
                parts.append(tr("Не установлен провайдер покрытия для vitest. Установите его: npm i -D @vitest/coverage-v8"))
            } else if log.contains("No tests found") || log.contains("no test files") {
                parts.append(tr("Тесты не найдены: проверьте, что в проекте есть тестовые файлы и настроен тест-раннер."))
            } else if log.contains("Cannot find module") || log.contains("command not found") {
                parts.append(tr("Не найден модуль или команда: выполните установку зависимостей (npm install)."))
            } else {
                parts.append(tr("Тесты упали или команда завершилась с ошибкой. Подробности — в выводе ниже."))
            }
        } else if !reportFound {
            note = tr("Тесты прошли, но отчёт не создан")
            parts.append(tr("Команда завершилась успешно, но ни одного файла отчёта не появилось. Искали: %@.", searched))
            parts.append(tr("Возможные причины: используется другой тест-раннер (мы запускаем jest/vitest/go test), в конфиге покрытия указан свой каталог или формат (нужен lcov, json или coverage.out), либо покрытие отключено. Укажите готовый отчёт вручную: меню «Покрытие тестами» → «Выбрать файл отчёта…»."))
        } else {
            note = tr("Отчёт найден, но не подошёл")
            parts.append(tr("Файл отчёта найден, но не удалось сопоставить его с файлами проекта или разобрать формат."))
        }
        if !tail.isEmpty { parts.append(tr("Конец вывода:") + "\n" + tail) }
        return (note, parts.joined(separator: "\n\n"))
    }

    /// Запускает тесты с покрытием в папке проекта (через login-shell, чтобы был PATH с node/go) и подхватывает отчёт.
    func runTestsWithCoverage() {
        guard let root, !coverageRunning else { return }
        guard let cmd = coverageCommand(root: root) else {
            coverageNote = tr("Не найден go.mod или package.json")
            coverageLog = tr("Тип проекта не определён: в корне нет ни go.mod, ни package.json. Укажите готовый отчёт вручную.")
            return
        }
        coverageRunning = true
        coverageProgress = 0
        coverageNote = ""
        coverageLog = ""
        let isGo = cmd.hasPrefix("go ")
        Task {
            let (status, log) = await Task.detached { [weak self] () -> (Int32, String) in
                let total = Self.countTestUnits(root: root, go: isGo)
                let p = Process()
                p.executableURL = URL(fileURLWithPath: "/bin/zsh")
                // -i: подхватить .zshrc (там обычно nvm/PATH); GUI-приложение стартует с минимальным PATH.
                p.arguments = ["-ilc", cmd]
                var env = ProcessInfo.processInfo.environment
                env["PATH"] = ["/opt/homebrew/bin", "/usr/local/bin", "/usr/local/go/bin", env["PATH"] ?? ""].joined(separator: ":")
                env["CI"] = "1"   // без интерактивных запросов jest/vitest (watch и т. п.)
                p.environment = env
                p.currentDirectoryURL = root
                p.standardInput = FileHandle.nullDevice
                let pipe = Pipe()
                p.standardOutput = pipe; p.standardError = pipe
                let state = OutputState()
                pipe.fileHandleForReading.readabilityHandler = { h in
                    let data = h.availableData
                    guard !data.isEmpty else { return }
                    let done = state.append(String(decoding: data, as: UTF8.self), isProgress: Self.isProgressLine)
                    if total > 0 {
                        let value = min(0.99, Double(done) / Double(total))
                        Task { @MainActor [weak self] in self?.coverageProgress = value }
                    }
                }
                do { try p.run() } catch { return (-1, "\(error)") }
                p.waitUntilExit()
                pipe.fileHandleForReading.readabilityHandler = nil
                let rest = pipe.fileHandleForReading.readDataToEndOfFile()
                return (p.terminationStatus, state.finish(String(decoding: rest, as: UTF8.self)))
            }.value
            coverageProgress = 1
            coverageRunning = false
            let found = CoverageLoader.discover(root: root) != nil
            if found { UserDefaults.standard.removeObject(forKey: key("coverage")); loadCoverage() }
            if status != 0 || !found {
                let d = diagnose(status: status, log: log, cmd: cmd, reportFound: found)
                coverageNote = d.note; coverageLog = d.detail
            } else {
                coverageLog = log   // запасной вариант: если отчёт не разобрался, loadCoverage перепишет заметку
            }
        }
    }

    func chooseCoverageFile() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.message = tr("Выберите отчёт покрытия: lcov.info, coverage-final.json или coverage.out (Go)")
        panel.directoryURL = root
        panel.showsHiddenFiles = true
        if panel.runModal() == .OK, let url = panel.url { loadCoverage(from: url) }
    }

    func cancel() { task?.cancel(); isScanning = false }

    /// Возврат к экрану выбора проекта.
    func closeProject() {
        task?.cancel()
        isScanning = false
        report = nil
        root = nil
        functionRows = []
        coverage = nil
        coverageNote = ""
        coverageLog = ""
        coverageRunning = false
        filesSelection = nil
        functionsSelection = nil
        languageFilter = "Все"
        search = ""
        section = .overview
    }

    func absoluteURL(_ relative: String) -> URL? {
        guard let report else { return nil }
        return URL(fileURLWithPath: report.root).appendingPathComponent(relative)
    }

    func reveal(_ relative: String) {
        if let u = absoluteURL(relative) { NSWorkspace.shared.activateFileViewerSelecting([u]) }
    }
    func openFile(_ relative: String) {
        if let u = absoluteURL(relative) { EditorSettings.shared.open(u) }
    }
    func openProjectInEditor() {
        if let root { EditorSettings.shared.open(root) }
    }

    func exportCSV() {
        guard let report else { return }
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "code-metrics.csv"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        var csv = "path,language,total_lines,code,comments,blank,functions,max_cyclomatic,max_cognitive,maintainability\n"
        for f in report.files {
            let p = f.path.contains(",") ? "\"\(f.path)\"" : f.path
            csv += "\(p),\(f.language),\(f.totalLines),\(f.codeLines),\(f.commentLines),\(f.blankLines),\(f.functionCount),\(f.maxCyclomatic),\(f.maxCognitive),\(String(format: "%.1f", f.maintainability))\n"
        }
        try? csv.write(to: url, atomically: true, encoding: .utf8)
    }
}


/// Потокобезопасный накопитель вывода процесса: считает строки прогресса и хранит хвост лога.
private final class OutputState: @unchecked Sendable {
    private let lock = NSLock()
    private var partial = ""
    private var done = 0
    private var tail = ""
    func append(_ chunk: String, isProgress: (String) -> Bool) -> Int {
        lock.lock(); defer { lock.unlock() }
        tail = String((tail + chunk).suffix(6000))
        var text = partial + chunk
        var lines = text.components(separatedBy: "\n")
        partial = lines.removeLast()
        text = ""
        for l in lines where isProgress(l) { done += 1 }
        return done
    }
    func finish(_ rest: String) -> String {
        lock.lock(); defer { lock.unlock() }
        return String((tail + rest).suffix(6000))
    }
}
