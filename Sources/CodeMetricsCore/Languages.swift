import Foundation
import SwiftTreeSitter
import TreeSitterJavaScript
import TreeSitterTypeScript
import TreeSitterTSX
import TreeSitterGo

private let jsFunctions: Set<String> = [
    "function_declaration", "function_expression", "arrow_function",
    "method_definition", "generator_function_declaration", "generator_function",
]
private let jsBranches: Set<String> = [
    "if_statement", "for_statement", "for_in_statement", "while_statement", "do_statement",
    "switch_case", "catch_clause", "ternary_expression",
]
private let jsNesting: Set<String> = [
    "if_statement", "for_statement", "for_in_statement", "while_statement", "do_statement",
    "switch_statement", "catch_clause", "ternary_expression",
]

private func jsLike(name: String, exts: Set<String>, lang: @escaping @Sendable () -> Language) -> LanguageSpec {
    LanguageSpec(
        name: name, extensions: exts, makeLanguage: lang,
        functionNodes: jsFunctions, commentNodes: ["comment"],
        branchNodes: jsBranches, logicalOperators: ["&&", "||", "??"],
        nestingNodes: jsNesting, cognitiveStructural: jsNesting,
        binaryNode: ["binary_expression"], paramsField: "parameters",
        nameFields: ["name"], ignoredDirs: [])
}

extension LanguageSpec {
    public static let javascript = jsLike(name: "JavaScript", exts: ["js", "jsx", "mjs", "cjs"]) {
        Language(language: tree_sitter_javascript())
    }
    public static let typescript = jsLike(name: "TypeScript", exts: ["ts", "mts", "cts"]) {
        Language(language: tree_sitter_typescript())
    }
    public static let tsx = jsLike(name: "TypeScript", exts: ["tsx"]) {
        Language(language: tree_sitter_tsx())
    }
    public static let go = LanguageSpec(
        name: "Go", extensions: ["go"], makeLanguage: { Language(language: tree_sitter_go()) },
        functionNodes: ["function_declaration", "method_declaration", "func_literal"],
        commentNodes: ["comment"],
        branchNodes: ["if_statement", "for_statement", "expression_case", "type_case", "communication_case"],
        logicalOperators: ["&&", "||"],
        nestingNodes: ["if_statement", "for_statement", "expression_switch_statement", "type_switch_statement", "select_statement"],
        cognitiveStructural: ["if_statement", "for_statement", "expression_switch_statement", "type_switch_statement", "select_statement"],
        binaryNode: ["binary_expression"], paramsField: "parameters",
        nameFields: ["name"], ignoredDirs: ["testdata"])
}
