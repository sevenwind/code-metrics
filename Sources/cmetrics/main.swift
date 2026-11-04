import Foundation
import CodeMetricsCore

let args = CommandLine.arguments.dropFirst()
guard let path = args.first else { print("usage: cmetrics <folder>"); exit(1) }
let report = await ProjectScanner.scan(root: URL(fileURLWithPath: path))
print("files: \(report.files.count)  code: \(report.codeLines)  comments: \(report.commentLines)  blank: \(report.blankLines)")
print(String(format: "maintainability: %.1f  time: %.2fs  skipped: %d", report.avgMaintainability, report.duration, report.skipped))
for l in report.languages { print("  \(l.language): \(l.files) files, \(l.codeLines) LOC") }
print("top complexity:")
for (f, fn) in report.functions.sorted(by: { $0.fn.cyclomatic > $1.fn.cyclomatic }).prefix(10) {
    print("  CC \(fn.cyclomatic) cog \(fn.cognitive) len \(fn.length)  \(fn.name)  \(f.path):\(fn.startLine)")
}
