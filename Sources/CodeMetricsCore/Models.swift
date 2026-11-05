import Foundation

/// Метрики одной функции/метода.
public struct FunctionMetrics: Identifiable, Hashable, Sendable {
    public var id: String { "\(name)@\(startLine)" }
    public let name: String
    public let startLine: Int
    public let endLine: Int
    public let cyclomatic: Int
    public let cognitive: Int
    public let parameters: Int
    public let maxNesting: Int
    /// Метод класса (JS/TS: method_definition и функции-свойства; Go: method_declaration).
    public var isMethod = false
    /// Go: имя типа-получателя метода.
    public var owner: String? = nil
    public var length: Int { endLine - startLine + 1 }
}

public enum ClassKind: String, Sendable { case classType, abstractClass, structType }

/// Класс (JS/TS) или структура с методами (Go).
public struct ClassMetrics: Identifiable, Hashable, Sendable {
    public var id: String { "\(name)@\(startLine)" }
    public let name: String
    public let kind: ClassKind
    public let startLine: Int
    public let endLine: Int
    public let methodCount: Int
    /// Weighted Methods per Class: сумма цикломатической сложности методов.
    public let wmc: Int
    /// Coupling Between Objects (приближённо): число разных импортированных имён, используемых внутри класса.
    public let cbo: Int
}

/// Метрики одного файла. Производные значения считаются один раз при создании (удобно для сортировки больших таблиц).
public struct FileMetrics: Identifiable, Hashable, Sendable {
    public var id: String { path }
    public let path: String          // относительный путь
    public let language: String
    public let totalLines: Int
    public let codeLines: Int
    public let commentLines: Int
    public let blankLines: Int
    public let functions: [FunctionMetrics]
    public let parseErrors: Bool
    /// Уникальные спецификаторы импортов (`./x`, `@nestjs/common`, Go-пути).
    public let imports: [String]
    public let classes: [ClassMetrics]
    /// Интерфейсы и абстрактные классы / конкретные классы и структуры (для метрики A).
    public let abstractTypes: Int
    public let concreteTypes: Int

    public let functionCount: Int
    public let maxCyclomatic: Int
    public let maxCognitive: Int
    public let totalCyclomatic: Int
    public let avgCyclomatic: Double
    /// Maintainability Index (0–100, как в Visual Studio). Чем выше, тем лучше.
    public let maintainability: Double
    /// Доля комментариев среди непустых строк (0–1).
    public let commentRatio: Double
    /// Покрытие строк тестами (0–1); -1 — нет данных. Заполняется после загрузки отчёта покрытия.
    public var coverage: Double = -1

    public init(path: String, language: String, totalLines: Int, codeLines: Int, commentLines: Int,
                blankLines: Int, functions: [FunctionMetrics], parseErrors: Bool,
                imports: [String] = [], classes: [ClassMetrics] = [], abstractTypes: Int = 0, concreteTypes: Int = 0) {
        self.imports = imports; self.classes = classes; self.abstractTypes = abstractTypes; self.concreteTypes = concreteTypes
        self.path = path; self.language = language; self.totalLines = totalLines
        self.codeLines = codeLines; self.commentLines = commentLines; self.blankLines = blankLines
        self.functions = functions; self.parseErrors = parseErrors
        functionCount = functions.count
        maxCyclomatic = functions.map(\.cyclomatic).max() ?? 0
        maxCognitive = functions.map(\.cognitive).max() ?? 0
        let sum = functions.reduce(0) { $0 + $1.cyclomatic }
        totalCyclomatic = sum + 1
        avgCyclomatic = functions.isEmpty ? 0 : Double(sum) / Double(functions.count)
        let nonBlank = codeLines + commentLines
        commentRatio = nonBlank == 0 ? 0 : Double(commentLines) / Double(nonBlank)
        if codeLines > 0 {
            let v = Double(codeLines)       // замена объёма Холстеда
            let raw = 171 - 5.2 * log(v * 8) - 0.23 * Double(sum + 1) - 16.2 * log(v)
            maintainability = max(0, min(100, raw * 100 / 171))
        } else {
            maintainability = 100
        }
    }
}

public struct LanguageSummary: Identifiable, Sendable {
    public var id: String { language }
    public let language: String
    public let files: Int
    public let codeLines: Int
}

public struct ProjectReport: Sendable {
    public let root: String
    public var files: [FileMetrics]
    public let duration: TimeInterval
    public let skipped: Int
    /// Папки, пропущенные автоматически (зависимости, сборочные артефакты).
    public let autoIgnored: [String]

    public init(root: String, files: [FileMetrics], duration: TimeInterval, skipped: Int, autoIgnored: [String]) {
        self.root = root; self.files = files; self.duration = duration; self.skipped = skipped; self.autoIgnored = autoIgnored
    }

    public var codeLines: Int { files.reduce(0) { $0 + $1.codeLines } }
    public var commentLines: Int { files.reduce(0) { $0 + $1.commentLines } }
    public var blankLines: Int { files.reduce(0) { $0 + $1.blankLines } }
    public var functions: [(file: FileMetrics, fn: FunctionMetrics)] {
        files.flatMap { f in f.functions.map { (f, $0) } }
    }
    public var avgMaintainability: Double {
        let w = files.reduce(0.0) { $0 + Double($1.codeLines) }
        guard w > 0 else { return 100 }
        return files.reduce(0.0) { $0 + $1.maintainability * Double($1.codeLines) } / w
    }
    public var languages: [LanguageSummary] {
        Dictionary(grouping: files, by: \.language).map {
            LanguageSummary(language: $0.key, files: $0.value.count, codeLines: $0.value.reduce(0) { $0 + $1.codeLines })
        }.sorted { $0.codeLines > $1.codeLines }
    }
}
