import SwiftUI
import CodeMetricsCore

struct DirNode: Identifiable, Hashable {
    let id: String            // относительный путь
    let name: String
    var files = 0
    var loc = 0
    var children: [DirNode]? = nil
}

/// Строит дерево папок с накопленными итогами по файлам.
private func buildTree(_ files: [FileMetrics]) -> [DirNode] {
    final class N { var files = 0, loc = 0; var kids: [String: N] = [:] }
    let root = N()
    for f in files {
        var node = root
        let parts = f.path.split(separator: "/").dropLast()
        node.files += 1; node.loc += f.codeLines
        for p in parts {
            let next = node.kids[String(p)] ?? N()
            node.kids[String(p)] = next
            node = next
            node.files += 1; node.loc += f.codeLines
        }
    }
    func convert(_ n: N, prefix: String) -> [DirNode] {
        n.kids.map { name, kid in
            let path = prefix.isEmpty ? name : "\(prefix)/\(name)"
            let sub = convert(kid, prefix: path)
            return DirNode(id: path, name: name, files: kid.files, loc: kid.loc, children: sub.isEmpty ? nil : sub)
        }.sorted { $0.loc > $1.loc }
    }
    return convert(root, prefix: "")
}

struct FoldersView: View {
    let report: ProjectReport
    @Environment(AppModel.self) private var model

    var body: some View {
        let tree = buildTree(report.files)
        let skipped = Set(report.autoIgnored).subtracting(model.forceIncluded)
        List {
            Section {
                if model.excluded.isEmpty && skipped.isEmpty {
                    Text(tr("Ничего не исключено")).foregroundStyle(.secondary)
                }
                ForEach(model.excluded.sorted(), id: \.self) { p in
                    row(p, note: tr("исключено вами"), action: tr("Вернуть"))
                }
                ForEach(skipped.sorted(), id: \.self) { p in
                    row(p, note: tr("зависимости/артефакты, по умолчанию"), action: tr("Включить"))
                }
            } header: { Text(tr("Не анализируется")) }

            Section {
                OutlineGroup(tree, children: \.children) { node in
                    HStack {
                        Image(systemName: "folder").foregroundStyle(.secondary).help(tr("Папка"))
                        Text(node.name)
                        Spacer()
                        Text(tr("%@ ф.", format(node.files))).foregroundStyle(.secondary).font(.caption).help(tr("Файлов в папке (с вложенными)"))
                        Text("\(format(node.loc)) LOC").monospacedDigit().frame(width: 100, alignment: .trailing).help(tr("Строк кода в папке (с вложенными)"))
                    }
                    .contextMenu {
                        Button(tr("Исключить папку из анализа")) { model.exclude([node.id]) }
                        Button(tr("Показать в Finder")) { model.reveal(node.id) }
                    }
                }
            } header: { Text(tr("Проанализировано — правый клик по папке, чтобы исключить")) }
        }
    }

    private func row(_ path: String, note: String, action: String) -> some View {
        HStack {
            Image(systemName: "nosign").foregroundStyle(.orange).help(tr("Не анализируется"))
            VStack(alignment: .leading) {
                Text(path)
                Text(note).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Button(action) { model.include(path) }.help(tr("Вернуть путь в анализ и пересканировать"))
        }
    }
}
