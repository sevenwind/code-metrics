import Foundation
import SwiftTreeSitter

/// Описание языка: расширения, грамматика и правила для узлов синтаксического дерева.
/// Чтобы добавить язык, достаточно создать новое значение `LanguageSpec` и зарегистрировать его в `LanguageRegistry`.
public struct LanguageSpec: @unchecked Sendable {
    public let name: String
    public let extensions: Set<String>
    public let makeLanguage: @Sendable () -> Language
    /// Типы узлов, являющиеся функциями/методами.
    public let functionNodes: Set<String>
    /// Типы узлов-комментариев.
    public let commentNodes: Set<String>
    /// Узлы, добавляющие +1 к цикломатической сложности.
    public let branchNodes: Set<String>
    /// Бинарные операторы ветвления (&&, ||, ??).
    public let logicalOperators: Set<String>
    /// Узлы, увеличивающие вложенность (для когнитивной сложности и глубины).
    public let nestingNodes: Set<String>
    /// Узлы, которые считаются «структурными» для когнитивной сложности (+1 + уровень вложенности).
    public let cognitiveStructural: Set<String>
    /// Тип узла бинарного выражения и имя поля оператора.
    public let binaryNode: Set<String>
    public let paramsField: String
    public let nameFields: [String]
    public let ignoredDirs: Set<String>
}

public enum LanguageRegistry {
    public static let all: [LanguageSpec] = [.javascript, .typescript, .tsx, .go]
    private static let byExt: [String: LanguageSpec] = {
        var d: [String: LanguageSpec] = [:]
        for s in all { for e in s.extensions { d[e] = s } }
        return d
    }()
    public static func spec(forExtension ext: String) -> LanguageSpec? { byExt[ext.lowercased()] }
    public static var ignoredDirs: Set<String> {
        var s: Set<String> = [".git", "node_modules", "vendor", "dist", "build", ".next", ".nuxt", "out",
                              "coverage", ".build", ".idea", ".vscode", "DerivedData", ".svn", ".hg", "target", ".cache"]
        for l in all { s.formUnion(l.ignoredDirs) }
        return s
    }
}
