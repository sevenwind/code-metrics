// swift-tools-version:5.9
// Локальная копия tree-sitter-javascript v0.25.0: в оригинальном манифесте scanner.c подключается
// через FileManager.fileExists относительно cwd, из-за чего линковка падает.
import PackageDescription

let package = Package(
    name: "TreeSitterJavaScript",
    products: [.library(name: "TreeSitterJavaScript", targets: ["TreeSitterJavaScript"])],
    targets: [
        .target(name: "TreeSitterJavaScript", path: "src", sources: ["parser.c", "scanner.c"],
                publicHeadersPath: "include", cSettings: [.headerSearchPath(".")])
    ],
    cLanguageStandard: .c11
)
