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
                           parseErrors: root.hasError)
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

        if node.isNamed && spec.functionNodes.contains(type) {
            let c = FnCtx()
            for i in 0..<node.childCount { if let ch = node.child(at: i) { walk(ch, ctx: c, nesting: 0) } }
            let pr = node.pointRange
            functions.append(FunctionMetrics(
                name: functionName(node), startLine: Int(pr.lowerBound.row) + 1, endLine: Int(pr.upperBound.row) + 1,
                cyclomatic: c.cyclomatic, cognitive: c.cognitive, parameters: parameterCount(node), maxNesting: c.maxNesting))
            return
        }
        var nest = nesting
        if let ctx { apply(node, type: type, ctx: ctx, nesting: &nest) }
        for i in 0..<node.childCount { if let ch = node.child(at: i) { walk(ch, ctx: ctx, nesting: nest) } }
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
