import Foundation
import SwiftTreeSitter

/// Анализ одного файла: подсчёт строк и сложности по синтаксическому дереву.
public struct FileAnalyzer {
    public init() {}

    /// `Parser` не потокобезопасен: каждый воркер использует свой экземпляр.
    public func analyze(source: String, path: String, spec: LanguageSpec, parser: Parser) -> FileMetrics {
        let units = Array(source.utf16)
        guard let tree = parser.parse(source), let root = tree.rootNode else {
            let c = Self.countLines(units: units, comments: [])
            return FileMetrics(path: path, language: spec.name, totalLines: c.total, codeLines: c.code,
                               commentLines: c.comment, blankLines: c.blank, functions: [], parseErrors: true)
        }
        let walker = Walker(spec: spec, source: source as NSString)
        walker.walk(root, ctx: nil, nesting: 0)
        let counts = Self.countLines(units: units, comments: walker.comments)
        return FileMetrics(path: path, language: spec.name, totalLines: counts.total, codeLines: counts.code,
                           commentLines: counts.comment, blankLines: counts.blank,
                           functions: walker.functions.sorted { $0.startLine < $1.startLine },
                           parseErrors: root.hasError,
                           imports: walker.imports, classes: walker.classMetrics(),
                           abstractTypes: walker.abstractTypeCount, concreteTypes: walker.concreteTypeCount)
    }

    static func countLines(units: [UInt16], comments: [NSRange]) -> (total: Int, code: Int, comment: Int, blank: Int) {
        var inComment = [Bool](repeating: false, count: units.count)
        for r in comments {
            let end = min(r.location + r.length, units.count)
            if r.location < end { for i in r.location..<end { inComment[i] = true } }
        }
        var total = 0, code = 0, comment = 0, blank = 0
        var i = 0
        let n = units.count
        while i < n {
            var hasCode = false, hasComment = false
            while i < n && units[i] != 10 {
                let u = units[i]
                if u != 32 && u != 9 && u != 13 {
                    if inComment[i] { hasComment = true } else { hasCode = true }
                }
                i += 1
            }
            i += 1
            total += 1
            if hasCode { code += 1 } else if hasComment { comment += 1 } else { blank += 1 }
        }
        return (total, code, comment, blank)
    }
}

private final class FnCtx {
    var cyclomatic = 1
    var cognitive = 0
    var maxNesting = 0
}

private final class Walker {
    let spec: LanguageSpec
    let source: NSString
    var comments: [NSRange] = []
    var functions: [FunctionMetrics] = []
    private var typeCache: [Int: String] = [:]

    // Архитектурные данные
    var imports: [String] = []
    private var importSet = Set<String>()
    /// Локальное имя → спецификатор импорта.
    private var bindings: [String: String] = [:]
    private var refs: [(name: String, line: Int)] = []
    private struct TypeDecl { let name: String; let kind: ClassKind?; let isAbstract: Bool; let start: Int; let end: Int }
    private var types: [TypeDecl] = []
    var abstractTypeCount: Int { types.filter(\.isAbstract).count }
    var concreteTypeCount: Int { types.filter { !$0.isAbstract }.count }

    init(spec: LanguageSpec, source: NSString) {
        self.spec = spec
        self.source = source
    }

    /// Имя типа узла кэшируется по номеру символа: создание String из C-строки на каждом узле заметно дорого.
    private func typeName(_ node: Node) -> String {
        let sym = node.symbol
        if let t = typeCache[sym] { return t }
        let t = node.nodeType ?? ""
        typeCache[sym] = t
        return t
    }

    func walk(_ node: Node, ctx: FnCtx?, nesting: Int) {
        let type = typeName(node)
        if spec.commentNodes.contains(type) { comments.append(node.range); return }

        if node.isNamed, collectStructure(node, type: type) { return }

        if node.isNamed && spec.functionNodes.contains(type) {
            let c = FnCtx()
            for i in 0..<node.childCount { if let ch = node.child(at: i) { walk(ch, ctx: c, nesting: 0) } }
            let pr = node.pointRange
            functions.append(FunctionMetrics(
                name: functionName(node), startLine: Int(pr.lowerBound.row) + 1, endLine: Int(pr.upperBound.row) + 1,
                cyclomatic: c.cyclomatic, cognitive: c.cognitive, parameters: parameterCount(node), maxNesting: c.maxNesting,
                isMethod: isMethod(node, type: type), owner: type == "method_declaration" ? receiverType(node) : nil))
            return
        }
        var nest = nesting
        if let ctx { apply(node, type: type, ctx: ctx, nesting: &nest) }
        for i in 0..<node.childCount { if let ch = node.child(at: i) { walk(ch, ctx: ctx, nesting: nest) } }
    }

    // MARK: Импорты, типы, ссылки

    private func line(_ node: Node) -> Int { Int(node.pointRange.lowerBound.row) + 1 }

    /// Диапазон строк объявления; для `@Decorator() export class` берётся диапазон export_statement, чтобы учесть декораторы.
    private func declLines(_ node: Node) -> (Int, Int) {
        var n = node
        if let p = node.parent, typeName(p) == "export_statement" { n = p }
        let pr = n.pointRange
        return (Int(pr.lowerBound.row) + 1, Int(pr.upperBound.row) + 1)
    }

    private func addImport(_ specifier: String) {
        if importSet.insert(specifier).inserted { imports.append(specifier) }
    }

    private func unquote(_ s: String) -> String {
        guard s.count >= 2, let f = s.first, "\"'`".contains(f) else { return s }
        return String(s.dropFirst().dropLast())
    }

    /// Имена, вводимые импортом (default, namespace, именованные с учётом `as`).
    private func collectBindings(_ node: Node, into names: inout [String]) {
        let t = typeName(node)
        if t == "import_specifier" {
            if let n = text(node.child(byFieldName: "alias") ?? node.child(byFieldName: "name")) { names.append(n) }
            return
        }
        if t == "identifier" || t == "shorthand_property_identifier_pattern" { if let n = text(node) { names.append(n) }; return }
        for i in 0..<node.childCount { if let ch = node.child(at: i) { collectBindings(ch, into: &names) } }
    }

    private func goPackageName(_ path: String) -> String {
        var parts = path.split(separator: "/").map(String.init)
        if let last = parts.last, last.range(of: "^v[0-9]+$", options: .regularExpression) != nil, parts.count > 1 { parts.removeLast() }
        var name = parts.last ?? path
        if let r = name.range(of: ".v[0-9]+$", options: .regularExpression) { name.removeSubrange(r) }
        return name.replacingOccurrences(of: "-", with: "_")
    }

    /// Собирает импорты, объявления типов и ссылки на импортированные имена.
    /// Возвращает true, если узел обработан полностью и спускаться в него не нужно.
    private func collectStructure(_ node: Node, type: String) -> Bool {
        switch type {
        case "import_statement":      // JS/TS
            if let src = text(node.child(byFieldName: "source")) {
                let spec = unquote(src)
                addImport(spec)
                var names: [String] = []
                for i in 0..<node.childCount {
                    if let ch = node.child(at: i), typeName(ch) == "import_clause" { collectBindings(ch, into: &names) }
                }
                for n in names { bindings[n] = spec }
            }
            return true
        case "export_statement":
            if let src = text(node.child(byFieldName: "source")) { addImport(unquote(src)) }
        case "call_expression":
            let fn = node.child(byFieldName: "function")
            if fn.map(typeName) == "import" || text(fn) == "require",
               let args = node.child(byFieldName: "arguments"),
               let first = args.namedChild(at: 0), typeName(first) == "string", let src = text(first) {
                let spec = unquote(src)
                addImport(spec)
                if let p = node.parent, typeName(p) == "variable_declarator", let nameNode = p.child(byFieldName: "name") {
                    var names: [String] = []
                    collectBindings(nameNode, into: &names)
                    for n in names { bindings[n] = spec }
                }
            }
        case "import_spec":           // Go
            if let p = text(node.child(byFieldName: "path")) {
                let path = unquote(p)
                addImport(path)
                let alias = text(node.child(byFieldName: "name"))
                if alias != "_" && alias != "." { bindings[alias ?? goPackageName(path)] = path }
            }
            return true
        case "class_declaration", "class":
            if let n = text(node.child(byFieldName: "name")) {
                let (s, e) = declLines(node)
                types.append(TypeDecl(name: n, kind: .classType, isAbstract: false, start: s, end: e))
            }
        case "abstract_class_declaration":
            if let n = text(node.child(byFieldName: "name")) {
                let (s, e) = declLines(node)
                types.append(TypeDecl(name: n, kind: .abstractClass, isAbstract: true, start: s, end: e))
            }
        case "interface_declaration":
            if let n = text(node.child(byFieldName: "name")) {
                let pr = node.pointRange
                types.append(TypeDecl(name: n, kind: nil, isAbstract: true, start: Int(pr.lowerBound.row) + 1, end: Int(pr.upperBound.row) + 1))
            }
        case "type_spec":             // Go
            if let n = text(node.child(byFieldName: "name")), let t = node.child(byFieldName: "type") {
                let pr = node.pointRange
                let s = Int(pr.lowerBound.row) + 1, e = Int(pr.upperBound.row) + 1
                switch typeName(t) {
                case "struct_type": types.append(TypeDecl(name: n, kind: .structType, isAbstract: false, start: s, end: e))
                case "interface_type": types.append(TypeDecl(name: n, kind: nil, isAbstract: true, start: s, end: e))
                default: break
                }
            }
        case "identifier", "type_identifier", "package_identifier":
            if !bindings.isEmpty, let t = text(node), bindings[t] != nil { refs.append((t, line(node))) }
        default: break
        }
        return false
    }

    private func isMethod(_ node: Node, type: String) -> Bool {
        if type == "method_definition" || type == "method_declaration" { return true }
        if let p = node.parent, ["public_field_definition", "field_definition"].contains(typeName(p)) { return true }
        return false
    }

    private func receiverType(_ node: Node) -> String? {
        func find(_ n: Node) -> String? {
            if typeName(n) == "type_identifier" { return text(n) }
            for i in 0..<n.childCount { if let c = n.child(at: i), let r = find(c) { return r } }
            return nil
        }
        return node.child(byFieldName: "receiver").flatMap(find)
    }

    /// WMC и CBO по каждому классу/структуре файла.
    func classMetrics() -> [ClassMetrics] {
        let decls = types.filter { $0.kind != nil }
        var out: [ClassMetrics] = []
        for d in decls {
            var methods: [FunctionMetrics]
            var ranges = [d.start...max(d.start, d.end)]
            if d.kind == .structType {
                methods = functions.filter { $0.isMethod && $0.owner == d.name }
                ranges += methods.map { $0.startLine...max($0.startLine, $0.endLine) }
            } else {
                methods = functions.filter { f in
                    guard f.isMethod, f.startLine >= d.start, f.endLine <= d.end else { return false }
                    // метод принадлежит самому вложенному из содержащих его классов
                    let inner = decls.filter { $0.kind != .structType && $0.start <= f.startLine && f.endLine <= $0.end }
                        .min { ($0.end - $0.start) < ($1.end - $1.start) }
                    return inner?.start == d.start && inner?.name == d.name
                }
            }
            var coupled = Set<String>()
            for r in refs where ranges.contains(where: { $0.contains(r.line) }) { coupled.insert(r.name) }
            out.append(ClassMetrics(name: d.name, kind: d.kind ?? .classType, startLine: d.start, endLine: d.end,
                                    methodCount: methods.count, wmc: methods.reduce(0) { $0 + $1.cyclomatic }, cbo: coupled.count))
        }
        return out.sorted { $0.startLine < $1.startLine }
    }

    private func apply(_ node: Node, type: String, ctx: FnCtx, nesting: inout Int) {
        if spec.branchNodes.contains(type) { ctx.cyclomatic += 1 }
        if spec.binaryNode.contains(type), let op = node.child(byFieldName: "operator"), case let t = typeName(op),
           spec.logicalOperators.contains(t) {
            ctx.cyclomatic += 1
            ctx.cognitive += 1
        }
        if spec.nestingNodes.contains(type) {
            let parentType = node.parent.map(typeName) ?? ""
            let isElseIf = type == "if_statement" && (parentType == "else_clause" || parentType == "if_statement")
            if isElseIf {
                ctx.cognitive += 1
            } else {
                ctx.cognitive += 1 + nesting
                nesting += 1
                ctx.maxNesting = max(ctx.maxNesting, nesting)
            }
        }
    }

    private func parameterCount(_ node: Node) -> Int {
        if let p = node.child(byFieldName: spec.paramsField) {
            // Go: `a, b int` — одна декларация с несколькими именами
            var n = 0
            for i in 0..<p.namedChildCount {
                guard let c = p.namedChild(at: i) else { continue }
                var names = 0
                for j in 0..<c.childCount where c.fieldNameForChild(at: j) == "name" { names += 1 }
                n += max(1, names)
            }
            return n
        }
        if node.child(byFieldName: "parameter") != nil { return 1 }
        return 0
    }

    private func text(_ n: Node?) -> String? {
        guard let r = n?.range, r.location >= 0, r.location + r.length <= source.length, r.length > 0, r.length < 200 else { return nil }
        return source.substring(with: r)
    }

    private func functionName(_ node: Node) -> String {
        for f in spec.nameFields { if let t = text(node.child(byFieldName: f)) { return t } }
        if let parent = node.parent {
            switch parent.nodeType ?? "" {
            case "variable_declarator": if let t = text(parent.child(byFieldName: "name")) { return t }
            case "pair": if let t = text(parent.child(byFieldName: "key")) { return t }
            case "assignment_expression": if let t = text(parent.child(byFieldName: "left")) { return t }
            case "public_field_definition", "field_definition":
                if let t = text(parent.child(byFieldName: "name") ?? parent.child(byFieldName: "property")) { return t }
            default: break
            }
        }
        return "<anonymous>"
    }
}
