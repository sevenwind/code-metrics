// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "CodeMetrics",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "CodeMetrics", targets: ["CodeMetricsApp"]),
        .executable(name: "cmetrics", targets: ["cmetrics"]),
    ],
    dependencies: [
        .package(url: "https://github.com/tree-sitter/swift-tree-sitter", from: "0.9.0"),
        .package(path: "Vendor/tree-sitter-javascript"),
        .package(url: "https://github.com/tree-sitter/tree-sitter-typescript", from: "0.23.0"),
        .package(url: "https://github.com/tree-sitter/tree-sitter-go", from: "0.23.0"),
    ],
    targets: [
        .target(name: "CodeMetricsCore", dependencies: [
            .product(name: "SwiftTreeSitter", package: "swift-tree-sitter"),
            .product(name: "TreeSitterJavaScript", package: "tree-sitter-javascript"),
            .product(name: "TreeSitterTypeScript", package: "tree-sitter-typescript"),
            .product(name: "TreeSitterGo", package: "tree-sitter-go"),
        ]),
        .executableTarget(name: "CodeMetricsApp", dependencies: ["CodeMetricsCore"]),
        .executableTarget(name: "cmetrics", dependencies: ["CodeMetricsCore"]),
        .executableTarget(name: "selftest", dependencies: ["CodeMetricsCore", .product(name: "SwiftTreeSitter", package: "swift-tree-sitter")]),
    ]
)
