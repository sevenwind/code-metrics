import Foundation

/// Покрытие строк одного файла: номер строки → число попаданий (только «измеряемые» строки).
public struct FileCoverage: Sendable {
    public var lines: [Int: Int] = [:]
    public init() {}
    public mutating func hit(_ line: Int, _ count: Int) { lines[line] = max(lines[line] ?? 0, count) }

    /// Доля покрытых строк в диапазоне (nil — в диапазоне нет измеряемых строк).
    public func ratio(in range: ClosedRange<Int>? = nil) -> Double? {
        var total = 0, covered = 0
        for (l, h) in lines where range?.contains(l) ?? true {
            total += 1; if h > 0 { covered += 1 }
        }
        return total == 0 ? nil : Double(covered) / Double(total)
    }
    public var counts: (covered: Int, total: Int) {
        (lines.values.filter { $0 > 0 }.count, lines.count)
    }
}

/// Отчёт покрытия, сопоставленный с путями проекта.
public struct CoverageReport: Sendable {
    public let source: String                       // имя файла отчёта
    public let files: [String: FileCoverage]        // ключ — относительный путь файла проекта
    public let unmatched: Int                       // записей отчёта, не найденных в проекте

    /// Покрытие проекта: покрытые / измеряемые строки по всем файлам отчёта.
    public var overall: Double? {
        var c = 0, t = 0
        for f in files.values { let k = f.counts; c += k.covered; t += k.total }
        return t == 0 ? nil : Double(c) / Double(t)
    }
}

public enum CoverageLoader {
    /// Типичные места отчётов относительно корня проекта.
    public static let candidates = ["coverage/lcov.info", "lcov.info", "coverage/coverage-final.json", "coverage-final.json",
                             "coverage.out", "cover.out", "coverage/coverage.out", "coverage/cover.out", "c.out"]

    public static func discover(root: URL) -> URL? {
        candidates.map { root.appendingPathComponent($0) }.first { FileManager.default.fileExists(atPath: $0.path) }
    }

    /// Разбирает отчёт (lcov / Istanbul JSON / Go coverprofile) и сопоставляет пути с файлами проекта.
    public static func load(report url: URL, projectPaths: [String], root: String) -> CoverageReport? {
        guard let data = try? Data(contentsOf: url), let text = String(data: data, encoding: .utf8) else { return nil }
        let raw: [String: FileCoverage]
        let head = text.drop { $0.isWhitespace }.first
        if head == "{" { raw = parseIstanbul(data) }
        else if text.hasPrefix("mode:") { raw = parseGo(text) }
        else { raw = parseLcov(text) }
        guard !raw.isEmpty else { return nil }

        // Индекс: путь проекта → по суффиксам.
        let projectSet = Set(projectPaths)
        var mapped: [String: FileCoverage] = [:]
        var unmatched = 0
        for (path, cov) in raw {
            var p = path
            if p.hasPrefix(root + "/") { p = String(p.dropFirst(root.count + 1)) }
            if p.hasPrefix("./") { p = String(p.dropFirst(2)) }
            var target: String? = projectSet.contains(p) ? p : nil
            if target == nil {
                // Go указывает путь модуля (github.com/x/y/pkg/f.go), JS в монорепо — путь от другого корня.
                target = projectPaths.filter { p.hasSuffix("/" + $0) }.max { $0.count < $1.count }
                    ?? projectPaths.filter { $0.hasSuffix("/" + p) }.first
            }
            if let t = target { mapped[t] = cov } else { unmatched += 1 }
        }
        return CoverageReport(source: url.lastPathComponent, files: mapped, unmatched: unmatched)
    }

    static func parseLcov(_ text: String) -> [String: FileCoverage] {
        var out: [String: FileCoverage] = [:]
        var cur: String?
        var cov = FileCoverage()
        for sub in text.split(whereSeparator: \.isNewline) {
            if sub.hasPrefix("SF:") { cur = String(sub.dropFirst(3)); cov = FileCoverage() }
            else if sub.hasPrefix("DA:") {
                let p = sub.dropFirst(3).split(separator: ",")
                if p.count >= 2, let l = Int(p[0]), let h = Int(p[1]) { cov.hit(l, h) }
            } else if sub == "end_of_record", let c = cur { out[c] = cov; cur = nil }
        }
        return out
    }

    /// Формат: `path/file.go:12.3,15.2 numStmts count`.
    static func parseGo(_ text: String) -> [String: FileCoverage] {
        var out: [String: FileCoverage] = [:]
        for sub in text.split(whereSeparator: \.isNewline).dropFirst() {
            let parts = sub.split(separator: " ")
            guard parts.count == 3, let count = Int(parts[2]), let colon = parts[0].lastIndex(of: ":") else { continue }
            let file = String(parts[0][..<colon])
            let range = parts[0][parts[0].index(after: colon)...].split(separator: ",")
            guard range.count == 2,
                  let s = Int(range[0].split(separator: ".")[0]), let e = Int(range[1].split(separator: ".")[0]) else { continue }
            var c = out[file] ?? FileCoverage()
            for l in s...max(s, e) { c.hit(l, count) }
            out[file] = c
        }
        return out
    }

    /// coverage-final.json (Istanbul: jest, vitest, nyc, c8).
    static func parseIstanbul(_ data: Data) -> [String: FileCoverage] {
        guard let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return [:] }
        var out: [String: FileCoverage] = [:]
        for (key, value) in obj {
            guard let f = value as? [String: Any], let smap = f["statementMap"] as? [String: Any],
                  let s = f["s"] as? [String: Any] else { continue }
            let path = (f["path"] as? String) ?? key
            var c = FileCoverage()
            for (id, loc) in smap {
                guard let start = (loc as? [String: Any])?["start"] as? [String: Any], let line = start["line"] as? Int,
                      let n = s[id] as? Int else { continue }
                c.hit(line, n)
            }
            out[path] = c
        }
        return out
    }
}
