import Foundation
import SwiftTreeSitter
import SwiftTreeSitter
import CodeMetricsCore

var failures = 0
func check(_ ok: Bool, _ msg: String = "", line: Int = #line) { if !ok { failures += 1; print("FAIL line \(line) \(msg)") } }

enum T {
    static func analyze(_ src: String, _ spec: LanguageSpec, path: String = "a.x") -> FileMetrics {
        let p = Parser(); try! p.setLanguage(spec.makeLanguage())
        return FileAnalyzer().analyze(source: src, path: path, spec: spec, parser: p)
    }

    static func typeScriptComplexityAndLines() {
        let src = """
        // header
        /* block
           comment */
        export function f(a: number, b: number) {
          if (a > 0 && b > 0) {
            for (let i = 0; i < a; i++) { if (i % 2) continue }
          } else if (b) { return 1 }
          return a ? 1 : 2
        }

        const g = (x) => x || 0
        """
        let m = analyze(src, .typescript)
        check(m.commentLines == 3)
        check(m.blankLines == 1)
        check(m.codeLines == 7)
        check(m.functions.count == 2, "\(m.functions)")
        let f = m.functions.first { $0.name == "f" }!
        // 1 + if + && + for + if + else-if + ternary
        check(f.cyclomatic == 7)
        check(f.parameters == 2)
        check(f.maxNesting == 3)
        let g = m.functions.first { $0.name == "g" }!
        check(g.cyclomatic == 2)
        check(g.parameters == 1)
    }

    static func go() {
        let src = """
        package main

        // doc
        func (s *Srv) Handle(a, b int) error {
            switch a {
            case 1:
                return nil
            case 2, 3:
                for i := 0; i < b; i++ {
                    if i > 1 || b > 3 { return nil }
                }
            default:
            }
            return nil
        }
        """
        let m = analyze(src, .go)
        check(m.functions.count == 1)
        let f = m.functions[0]
        check(f.name == "Handle")
        // 1 + case + case + for + if + ||
        check(f.cyclomatic == 6)
        check(f.parameters == 2)
        check(m.commentLines == 1)
    }

    static func nestedFunctionsAreSeparate() {
        let m = analyze("function outer(){ function inner(){ if (a) {} } return 1 }", .javascript)
        check(m.functions.first { $0.name == "outer" }?.cyclomatic == 1)
        check(m.functions.first { $0.name == "inner" }?.cyclomatic == 2)
    }

    static func scannerSkipsIgnoredDirs() async throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("cm-\(UUID())")
        try FileManager.default.createDirectory(at: dir.appendingPathComponent("node_modules/x"), withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: dir.appendingPathComponent("src"), withIntermediateDirectories: true)
        try "function a(){}".write(to: dir.appendingPathComponent("node_modules/x/i.js"), atomically: true, encoding: .utf8)
        try "func A() {}".write(to: dir.appendingPathComponent("src/m.go"), atomically: true, encoding: .utf8)
        try "export const a = 1".write(to: dir.appendingPathComponent("src/m.ts"), atomically: true, encoding: .utf8)
        let r = await ProjectScanner.scan(root: dir)
        check(r.autoIgnored == ["node_modules"], "autoIgnored \(r.autoIgnored)")
        check(r.files.map(\.path) == ["src/m.go", "src/m.ts"])
        try? FileManager.default.removeItem(at: dir)
    }
}

extension T {
    static func scannerHonoursExclusions() async throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("cm-\(UUID())")
        try FileManager.default.createDirectory(at: dir.appendingPathComponent("lib"), withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: dir.appendingPathComponent("node_modules"), withIntermediateDirectories: true)
        try "function a(){}".write(to: dir.appendingPathComponent("lib/a.js"), atomically: true, encoding: .utf8)
        try "function b(){}".write(to: dir.appendingPathComponent("b.js"), atomically: true, encoding: .utf8)
        try "function c(){}".write(to: dir.appendingPathComponent("node_modules/c.js"), atomically: true, encoding: .utf8)
        var o = ScanOptions(); o.excludedPaths = ["lib"]
        check(await ProjectScanner.scan(root: dir, options: o).files.map(\.path) == ["b.js"], "dir exclusion")
        o.excludedPaths = ["b.js"]
        check(await ProjectScanner.scan(root: dir, options: o).files.map(\.path) == ["lib/a.js"], "file exclusion")
        o.excludedPaths = []; o.includedPaths = ["node_modules"]
        check(await ProjectScanner.scan(root: dir, options: o).files.count == 3, "force include")
        try? FileManager.default.removeItem(at: dir)
    }
}

for n in [".env", ".env.local", "prod.env", "credentials.json", "serviceAccount.json", "my-service-account-key.json", "id_rsa", "cert.pem", "app.key", ".npmrc", "secrets.ts", ".dev.vars"] {
    check(SensitiveFiles.matches(fileName: n), n)
}
for n in ["index.ts", "main.go", "package.json", "tsconfig.json", "environment.ts", "keyboard.ts", "monkey.js"] {
    check(!SensitiveFiles.matches(fileName: n), n)
}
extension T {
    static func sensitiveNeverRead() async throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("cm-\(UUID())")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try "function a(){}".write(to: dir.appendingPathComponent("secrets.js"), atomically: true, encoding: .utf8)
        try "function a(){}".write(to: dir.appendingPathComponent("credentials.ts"), atomically: true, encoding: .utf8)
        try "function b(){}".write(to: dir.appendingPathComponent("ok.js"), atomically: true, encoding: .utf8)
        var o = ScanOptions(); o.includedPaths = ["secrets.js", "credentials.ts"]
        let r = await ProjectScanner.scan(root: dir, options: o)
        check(r.files.map(\.path) == ["ok.js"], "sensitive not skipped: \(r.files.map(\.path))")
        try? FileManager.default.removeItem(at: dir)
    }
}
try await T.sensitiveNeverRead()

enum A {
    static func classesAndImports() {
        let src = """
        import { Injectable } from '@nestjs/common';
        import * as path from 'path';
        import { Repo } from './repo';
        const fs = require('fs');

        export interface IFoo { run(): void }
        export abstract class Base { abstract go(): void }
        @Injectable()
        export class Svc extends Base {
          constructor(private repo: Repo) { super() }
          go() { if (this.repo) { return path.join('a') } }
          other(x: number) { return x > 1 ? fs.readFileSync('x') : 0 }
          noRefs() { return 1 }
        }
        """
        let m = T.analyze(src, .typescript, path: "src/a.ts")
        check(Set(m.imports) == ["@nestjs/common", "path", "./repo", "fs"], "imports \(m.imports)")
        check(m.abstractTypes == 2 && m.concreteTypes == 1, "types \(m.abstractTypes)/\(m.concreteTypes)")
        let svc = m.classes.first { $0.name == "Svc" }
        // constructor 1 + go (1 + if) 2 + other (1 + ternary) 2 + noRefs 1
        check(svc?.wmc == 6, "wmc \(String(describing: svc?.wmc))")
        check(svc?.methodCount == 4, "methods \(String(describing: svc?.methodCount))")
        // Injectable, Repo, path, fs
        check(svc?.cbo == 4, "cbo \(String(describing: svc?.cbo))")
        check(m.classes.contains { $0.name == "Base" && $0.kind == .abstractClass })
        check(!m.classes.contains { $0.name == "IFoo" })
    }

    static func goStructs() {
        let src = """
        package svc

        import (
            "fmt"
            "net/http"
            log "github.com/x/y/logger"
            "github.com/x/y/store"
        )

        type Reader interface { Read() }
        type Srv struct{ c http.Client }
        func (s *Srv) A(x int) { if x > 0 { fmt.Println(store.Get()) } }
        func (s Srv) B() { log.Info("b") }
        func helper() {}
        """
        let m = T.analyze(src, .go, path: "svc/s.go")
        check(Set(m.imports) == ["fmt", "net/http", "github.com/x/y/logger", "github.com/x/y/store"], "imports \(m.imports)")
        check(m.abstractTypes == 1 && m.concreteTypes == 1)
        let srv = m.classes.first { $0.name == "Srv" }
        check(srv?.methodCount == 2 && srv?.wmc == 3, "srv \(String(describing: srv))")
        check(srv?.cbo == 4, "cbo \(String(describing: srv?.cbo))")   // http, fmt, store, log
    }

    static func martinMetrics() async throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("arch-\(UUID().uuidString)")
        let fm = FileManager.default
        for d in ["core", "app", "util"] { try fm.createDirectory(at: dir.appendingPathComponent(d), withIntermediateDirectories: true) }
        try "export interface Port { f(): void }\nexport abstract class Base {}\n".write(to: dir.appendingPathComponent("core/port.ts"), atomically: true, encoding: .utf8)
        try "import { Port } from '../core/port';\nimport { h } from '../util';\nexport class Impl implements Port { f() {} }\n".write(to: dir.appendingPathComponent("app/impl.ts"), atomically: true, encoding: .utf8)
        try "export function h() { return 1 }\n".write(to: dir.appendingPathComponent("util/index.ts"), atomically: true, encoding: .utf8)
        try "import { Impl } from './impl';\nimport x from 'react';\nexport const y = Impl;\n".write(to: dir.appendingPathComponent("app/other.spec.ts"), atomically: true, encoding: .utf8)
        let report = await ProjectScanner.scan(root: dir)
        let pk = Dictionary(uniqueKeysWithValues: ArchitectureAnalyzer.analyze(report: report).map { ($0.path, $0) })
        check(pk["core"]?.ca == 1 && pk["core"]?.ce == 0, "core \(String(describing: pk["core"]))")
        check(pk["core"]?.instability == 0 && pk["core"]?.abstractness == 1, "core I/A")
        check(pk["core"]?.distance == 0, "core D")
        check(pk["app"]?.ca == 0 && pk["app"]?.ce == 2, "app \(String(describing: pk["app"]))")
        check(pk["app"]?.instability == 1 && pk["app"]?.abstractness == 0 && pk["app"]?.distance == 0, "app")
        check(pk["util"]?.ca == 1 && pk["util"]?.ce == 0, "util")
        try? fm.removeItem(at: dir)
    }
}
A.classesAndImports()
A.goStructs()
try await A.martinMetrics()

T.typeScriptComplexityAndLines()
T.go()
T.nestedFunctionsAreSeparate()
try await T.scannerSkipsIgnoredDirs()
try await T.scannerHonoursExclusions()
do {
    let d = FileManager.default.temporaryDirectory.appendingPathComponent("cov-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: d, withIntermediateDirectories: true)
    let lcov = d.appendingPathComponent("lcov.info")
    try "SF:/proj/src/a.ts\nDA:1,1\nDA:2,0\nDA:3,4\nend_of_record\n".write(to: lcov, atomically: true, encoding: .utf8)
    let r1 = CoverageLoader.load(report: lcov, projectPaths: ["src/a.ts"], root: "/proj")
    check(abs((r1?.files["src/a.ts"]?.ratio() ?? -1) - 2.0 / 3) < 1e-9, "lcov ratio")
    check(r1?.files["src/a.ts"]?.ratio(in: 2...2) == 0, "lcov range")
    let go = d.appendingPathComponent("coverage.out")
    try "mode: set\ngithub.com/x/y/pkg/f.go:3.2,5.3 2 1\ngithub.com/x/y/pkg/f.go:6.2,7.3 1 0\n".write(to: go, atomically: true, encoding: .utf8)
    let r2 = CoverageLoader.load(report: go, projectPaths: ["pkg/f.go"], root: "/proj")
    check(abs((r2?.overall ?? -1) - 3.0 / 5) < 1e-9, "go ratio \(String(describing: r2?.overall))")
    let js = d.appendingPathComponent("coverage-final.json")
    try #"{"/proj/b.js":{"path":"/proj/b.js","statementMap":{"0":{"start":{"line":1},"end":{"line":1}},"1":{"start":{"line":2},"end":{"line":2}}},"s":{"0":1,"1":0}}}"#.write(to: js, atomically: true, encoding: .utf8)
    let r3 = CoverageLoader.load(report: js, projectPaths: ["b.js"], root: "/proj")
    check(r3?.overall == 0.5, "istanbul")
    try? FileManager.default.removeItem(at: d)
}
print(failures == 0 ? "OK: all checks passed" : "\(failures) FAILED")
exit(failures == 0 ? 0 : 1)