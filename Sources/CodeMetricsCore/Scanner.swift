import Foundation
import SwiftTreeSitter

public struct ScanProgress: Sendable {
    public let processed: Int
    public let total: Int
    public let currentFile: String
}

public struct ScanOptions: Sendable {
    public var maxFileSize: Int = 2_000_000       // файлы больше пропускаются (минифицированные бандлы и т.п.)
    public var extraIgnoredDirs: Set<String> = []
    public var includeTests: Bool = true
    /// Относительные пути папок, исключённых пользователем.
    public var excludedPaths: Set<String> = []
    /// Относительные пути папок, которые обычно пропускаются (node_modules и т.п.), но пользователь хочет их включить.
    public var includedPaths: Set<String> = []
    public init() {}
}

public enum ProjectScanner {
    /// Рекурсивный обход папки: сначала собираем список файлов, затем разбираем их параллельно.
    public static func scan(root: URL, options: ScanOptions = ScanOptions(),
                            progress: (@Sendable (ScanProgress) -> Void)? = nil) async -> ProjectReport {
        let start = Date()
        let ignored = LanguageRegistry.ignoredDirs.union(options.extraIgnoredDirs)
        let (candidates, skipped, autoIgnored) = collect(root: root, ignored: ignored, options: options)
        let total = candidates.count
        let rootPath = root.standardizedFileURL.path
        let workers = max(2, ProcessInfo.processInfo.activeProcessorCount)

        let counter = Counter()
        var results: [FileMetrics] = []
        results.reserveCapacity(total)

        await withTaskGroup(of: [FileMetrics].self) { group in
            let chunk = max(1, (total + workers * 4 - 1) / (workers * 4))
            var idx = 0
            while idx < total {
                let slice = Array(candidates[idx..<min(idx + chunk, total)])
                idx += chunk
                group.addTask {
                    var out: [FileMetrics] = []
                    var parsers: [String: Parser] = [:]
                    let analyzer = FileAnalyzer()
                    for (url, spec) in slice {
                        if Task.isCancelled { break }
                        guard let data = try? Data(contentsOf: url, options: .mappedIfSafe),
                              let text = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .isoLatin1) else { continue }
                        if Self.looksMinified(text) { counter.skip(); continue }
                        let key = url.pathExtension.lowercased()
                        let parser: Parser
                        if let p = parsers[key] { parser = p } else {
                            let p = Parser()
                            try? p.setLanguage(spec.makeLanguage())
                            parsers[key] = p
                            parser = p
                        }
                        let rel = String(url.standardizedFileURL.path.dropFirst(rootPath.count + 1))
                        out.append(analyzer.analyze(source: text, path: rel, spec: spec, parser: parser))
                        let n = counter.increment()
                        if n % 25 == 0 || n == total { progress?(ScanProgress(processed: n, total: total, currentFile: rel)) }
                    }
                    return out
                }
            }
            for await part in group { results.append(contentsOf: part) }
        }
        results.sort { $0.path < $1.path }
        return ProjectReport(root: rootPath, files: results, duration: Date().timeIntervalSince(start), skipped: skipped + counter.skipped, autoIgnored: autoIgnored)
    }

    private static func collect(root: URL, ignored: Set<String>, options: ScanOptions) -> ([(URL, LanguageSpec)], Int, [String]) {
        var found: [(URL, LanguageSpec)] = []
        var skipped = 0
        var autoIgnored: [String] = []
        let rootPath = root.standardizedFileURL.path
        let keys: [URLResourceKey] = [.isDirectoryKey, .fileSizeKey, .isRegularFileKey]
        guard let en = FileManager.default.enumerator(at: root, includingPropertiesForKeys: keys,
                                                      options: [.skipsPackageDescendants]) else { return ([], 0, []) }
        for case let url as URL in en {
            let fileName = url.lastPathComponent
            if SensitiveFiles.matches(fileName: fileName) { skipped += 1; continue }
            let v = try? url.resourceValues(forKeys: Set(keys))
            if v?.isDirectory == true {
                if fileName.hasPrefix(".") && fileName != "." { en.skipDescendants(); continue }  // скрытые папки
                let rel = String(url.standardizedFileURL.path.dropFirst(rootPath.count + 1))
                if options.excludedPaths.contains(rel) {
                    en.skipDescendants()
                } else if ignored.contains(url.lastPathComponent) && !options.includedPaths.contains(rel) {
                    autoIgnored.append(rel)
                    en.skipDescendants()
                }
                continue
            }
            if fileName.hasPrefix(".") { continue }  // скрытые файлы не анализируем
            guard v?.isRegularFile == true, let spec = LanguageRegistry.spec(forExtension: url.pathExtension) else { continue }
            if !options.excludedPaths.isEmpty,
               options.excludedPaths.contains(String(url.standardizedFileURL.path.dropFirst(rootPath.count + 1))) {
                skipped += 1; continue
            }
            let name = url.lastPathComponent
            if name.hasSuffix(".d.ts") || name.hasSuffix(".min.js") { skipped += 1; continue }
            if !options.includeTests && isTest(name) { skipped += 1; continue }
            if (v?.fileSize ?? 0) > options.maxFileSize { skipped += 1; continue }
            found.append((url, spec))
        }
        return (found, skipped, autoIgnored.sorted())
    }

    /// Минифицированный код (очень длинные строки) искажает метрики, поэтому такие файлы пропускаются.
    static func looksMinified(_ text: String) -> Bool {
        let bytes = text.utf8.count
        guard bytes > 20_000 else { return false }
        var lines = 1
        for b in text.utf8 where b == 10 { lines += 1 }
        return bytes / lines > 300
    }

    private static func isTest(_ name: String) -> Bool {
        name.contains(".test.") || name.contains(".spec.") || name.hasSuffix("_test.go")
    }
}

private final class Counter: @unchecked Sendable {
    private var n = 0
    private let lock = NSLock()
    private(set) var skipped = 0
    func skip() { lock.lock(); skipped += 1; lock.unlock() }
    func increment() -> Int { lock.lock(); defer { lock.unlock() }; n += 1; return n }
}
