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
print("architecture (packages by distance D):")
for p in ArchitectureAnalyzer.analyze(report: report).prefix(8) {
    let i = p.instability.map { String(format: "%.2f", $0) } ?? "—", a = p.abstractness.map { String(format: "%.2f", $0) } ?? "—"
    let d = p.distance.map { String(format: "%.2f", $0) } ?? "—"
    print("  D \(d)  I \(i)  A \(a)  Ca \(p.ca)  Ce \(p.ce)  files \(p.files)  \(p.path)")
}
print("top classes by WMC:")
for (f, c) in report.files.flatMap({ f in f.classes.map { (f, $0) } }).sorted(by: { $0.1.wmc > $1.1.wmc }).prefix(5) {
    print("  WMC \(c.wmc) CBO \(c.cbo) methods \(c.methodCount)  \(c.name)  \(f.path):\(c.startLine)")
}
