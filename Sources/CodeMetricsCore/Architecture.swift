import Foundation

/// Метрики пакета (папки) по Роберту Мартину.
public struct PackageMetrics: Identifiable, Sendable {
    public var id: String { path }
    /// Относительный путь папки ("." — корень проекта).
    public let path: String
    public let files: Int
    /// Афферентная связь: сколько других пакетов зависят от этого.
    public let ca: Int
    /// Эфферентная связь: от скольких других пакетов зависит этот.
    public let ce: Int
    public let abstractTypes: Int
    public let totalTypes: Int

    /// I = Ce / (Ca + Ce); nil, если связей нет.
    public let instability: Double?
    /// A = абстрактные типы / все типы; nil, если типов нет.
    public let abstractness: Double?
    /// D = |A + I − 1|; nil, если нет I или A.
    public let distance: Double?
    // Для сортировки в таблицах (nil → -1).
    public var sortI: Double { instability ?? -1 }
    public var sortA: Double { abstractness ?? -1 }
    public var sortD: Double { distance ?? -1 }

    init(path: String, files: Int, ca: Int, ce: Int, abstractTypes: Int, totalTypes: Int) {
        self.path = path; self.files = files; self.ca = ca; self.ce = ce
        self.abstractTypes = abstractTypes; self.totalTypes = totalTypes
        let i: Double? = ca + ce == 0 ? nil : Double(ce) / Double(ca + ce)
        let a: Double? = totalTypes == 0 ? nil : Double(abstractTypes) / Double(totalTypes)
        instability = i; abstractness = a
        distance = (i != nil && a != nil) ? abs(a! + i! - 1) : nil
    }
}

public enum ArchitectureAnalyzer {
    private static let jsExts = ["ts", "tsx", "js", "jsx", "mjs", "cjs", "mts", "cts"]

    /// Тестовые файлы в граф зависимостей не включаются: они искажают Ca production-кода.
    public static func isTestPath(_ p: String) -> Bool {
        let name = (p as NSString).lastPathComponent
        if name.contains(".test.") || name.contains(".spec.") || name.hasSuffix("_test.go") { return true }
        return p.split(separator: "/").dropLast().contains { ["test", "tests", "__tests__", "e2e", "testdata", "__mocks__"].contains(String($0)) }
    }

    private static func dir(_ path: String) -> String {
        let d = (path as NSString).deletingLastPathComponent
        return d.isEmpty ? "." : d
    }

    /// Нормализует путь ("a/b/../c" → "a/c"); nil, если выходит за корень проекта.
    private static func normalize(_ path: String) -> String? {
        var out: [Substring] = []
        for c in path.split(separator: "/", omittingEmptySubsequences: true) {
            if c == "." { continue }
            if c == ".." { if out.isEmpty { return nil }; out.removeLast() } else { out.append(c) }
        }
        return out.joined(separator: "/")
    }

    public static func analyze(report: ProjectReport) -> [PackageMetrics] {
        let files = report.files.filter { !isTestPath($0.path) }
        let paths = Set(files.map(\.path))
        var dirs = Set<String>()
        for f in files { dirs.insert(dir(f.path)) }
        // Директории-предки тоже считаются существующими для разрешения импортов `./foo` → foo/index.ts.
        let goModule = goModulePath(root: report.root)

        func resolveJS(_ candidate: String) -> String? {
            guard let c = normalize(candidate) else { return nil }
            var bases = [c]
            for e in [".js", ".jsx", ".mjs", ".cjs"] where c.hasSuffix(e) { bases.append(String(c.dropLast(e.count))) }
            for b in bases {
                if paths.contains(b) { return dir(b) }
                for e in jsExts where paths.contains("\(b).\(e)") { return dir("\(b).\(e)") }
                for e in jsExts where paths.contains("\(b)/index.\(e)") { return b.isEmpty ? "." : b }
            }
            return dirs.contains(c.isEmpty ? "." : c) ? (c.isEmpty ? "." : c) : nil
        }

        func target(of spec: String, from file: String, go: Bool) -> String? {
            if go {
                guard let m = goModule else { return nil }
                if spec == m { return dirs.contains(".") ? "." : nil }
                guard spec.hasPrefix(m + "/") else { return nil }
                let rel = String(spec.dropFirst(m.count + 1))
                return dirs.contains(rel) ? rel : nil
            }
            if spec.hasPrefix(".") {
                let base = dir(file) == "." ? "" : dir(file)
                return resolveJS(base.isEmpty ? spec : "\(base)/\(spec)")
            }
            // Алиасы (@/x, ~/x) и baseUrl-импорты (src/x). Внешние пакеты не совпадут ни с одним путём проекта.
            var rests = [spec]
            if spec.hasPrefix("@/") || spec.hasPrefix("~/") { rests = [String(spec.dropFirst(2))] }
            for r in rests { for prefix in ["", "src/"] { if let t = resolveJS(prefix + r) { return t } } }
            return nil
        }

        var deps: [String: Set<String>] = [:]
        var rdeps: [String: Set<String>] = [:]
        for f in files {
            let from = dir(f.path)
            let isGo = f.language == "Go"
            for spec in f.imports {
                guard let to = target(of: spec, from: f.path, go: isGo), to != from else { continue }
                deps[from, default: []].insert(to)
                rdeps[to, default: []].insert(from)
            }
        }

        var byDir: [String: [FileMetrics]] = [:]
        for f in files { byDir[dir(f.path), default: []].append(f) }
        return byDir.map { d, fs in
            let abs = fs.reduce(0) { $0 + $1.abstractTypes }
            let con = fs.reduce(0) { $0 + $1.concreteTypes }
            return PackageMetrics(path: d, files: fs.count, ca: rdeps[d]?.count ?? 0, ce: deps[d]?.count ?? 0,
                                  abstractTypes: abs, totalTypes: abs + con)
        }.sorted { ($0.distance ?? -1, $0.files) > ($1.distance ?? -1, $1.files) }
    }

    static func goModulePath(root: String) -> String? {
        guard let text = try? String(contentsOfFile: root + "/go.mod", encoding: .utf8) else { return nil }
        for line in text.split(whereSeparator: \.isNewline) where line.hasPrefix("module ") {
            return line.dropFirst(7).trimmingCharacters(in: .whitespaces).trimmingCharacters(in: CharacterSet(charactersIn: "\""))
        }
        return nil
    }
}
