import SwiftUI
import CodeMetricsCore

struct FilesView: View {
    let report: ProjectReport
    @Environment(AppModel.self) private var model

    private var rows: [FileMetrics] {
        let q = model.search.trimmingCharacters(in: .whitespaces)
        return report.files
            .filter { (model.languageFilter == "Все" || $0.language == model.languageFilter) && (q.isEmpty || $0.path.localizedCaseInsensitiveContains(q)) }
            .sorted(using: model.filesSort)
    }

    var body: some View {
        @Bindable var model = model
        let rows = rows
        VStack(spacing: 0) {
            HStack {
                Picker(tr("Язык"), selection: $model.languageFilter) {
                    Text(tr("Все языки")).tag("Все")
                    ForEach(report.languages) { Text($0.language).tag($0.language) }
                }.pickerStyle(.menu).fixedSize().help(tr("Показывать файлы только выбранного языка"))
                Spacer()
                MetricLegend(items: [(tr("Код"), .loc), (tr("Комм."), .commentRatio), ("Max CC", .maxCC), ("Cov", .coverage), ("Max Cog", .maxCog), ("MI", .maintainability)])
                Spacer()
                Text(tr("%@ из %@", format(rows.count), format(report.files.count))).foregroundStyle(.secondary).font(.callout).help(tr("Показано файлов из общего числа"))
            }.padding(.horizontal, 12).padding(.vertical, 8)
            Divider()
            Table(rows, selection: $model.filesSelection, sortOrder: $model.filesSort) {
                TableColumn(tr("Файл"), value: \.path) { f in
                    HStack(spacing: 4) {
                        Text((f.path as NSString).lastPathComponent).fontWeight(.medium)
                        Text((f.path as NSString).deletingLastPathComponent).foregroundStyle(.secondary).lineLimit(1).truncationMode(.head)
                        if f.parseErrors { Image(systemName: "exclamationmark.circle").foregroundStyle(.orange).help(tr("Файл разобран с синтаксическими ошибками")) }
                    }
                }.width(min: 220, ideal: 400)
                TableColumn(tr("Язык"), value: \.language) { Text($0.language) }.width(80)
                TableColumn(tr("Код"), value: \.codeLines) { Text(format($0.codeLines)).monospacedDigit() }.width(65)
                TableColumn(tr("Комм."), value: \.commentRatio) { Text(String(format: "%.0f%%", $0.commentRatio * 100)).monospacedDigit() }.width(55)
                TableColumn("Cov", value: \.coverage) { f in
                    if f.coverage < 0 { Text("—").foregroundStyle(.secondary) }
                    else { Text(String(format: "%.0f%%", f.coverage * 100)).monospacedDigit().foregroundStyle(Severity.coverage(f.coverage).color) }
                }.width(55)
                TableColumn(tr("Функц."), value: \.functionCount) { Text("\($0.functionCount)").monospacedDigit() }.width(60)
                TableColumn("Max CC", value: \.maxCyclomatic) { f in
                    Text("\(f.maxCyclomatic)").monospacedDigit().foregroundStyle(Severity.cyclomatic(f.maxCyclomatic).color)
                }.width(65)
                TableColumn("Max Cog", value: \.maxCognitive) { f in
                    Text("\(f.maxCognitive)").monospacedDigit().foregroundStyle(Severity.cognitive(f.maxCognitive).color)
                }.width(65)
                TableColumn("MI", value: \.maintainability) { f in
                    Text(String(format: "%.0f", f.maintainability)).monospacedDigit().bold()
                        .foregroundStyle(Severity.maintainability(f.maintainability).color)
                }.width(50)
            }
            .columnTooltips([
                tr("Код"): metricTip(.loc), tr("Комм."): metricTip(.commentRatio), "Max CC": metricTip(.maxCC),
                "Cov": metricTip(.coverage), tr("Функц."): metricTip(.functions), "Max Cog": metricTip(.maxCog),
                "MI": metricTip(.maintainability), tr("Язык"): metricTip(.language),
            ])
            .contextMenu(forSelectionType: FileMetrics.ID.self) { ids in
                if let p = ids.first {
                    Button(tr("Открыть в %@", EditorSettings.shared.editor.name)) { model.openFile(p) }
                    Button(tr("Показать в Finder")) { model.reveal(p) }
                    Divider()
                    Button(tr("Исключить из анализа")) { model.exclude(Array(ids)) }
                    Button(tr("Копировать путь")) { NSPasteboard.general.clearContents(); NSPasteboard.general.setString(p, forType: .string) }
                }
            } primaryAction: { ids in if let p = ids.first { model.openFile(p) } }
        }
        .inspector(isPresented: .constant(selectedFile != nil)) {
            if let f = selectedFile { FileDetail(file: f).inspectorColumnWidth(min: 280, ideal: 340, max: 480) }
        }
    }

    private var selectedFile: FileMetrics? { model.filesSelection.flatMap { id in report.files.first { $0.id == id } } }
}

private struct FileDetail: View {
    let file: FileMetrics
    @Environment(AppModel.self) private var model
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text((file.path as NSString).lastPathComponent).font(.headline)
            Text(file.path).font(.caption).foregroundStyle(.secondary).textSelection(.enabled)
            Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 4) {
                GridRow { Text(tr("Строк всего")).foregroundStyle(.secondary); Text("\(file.totalLines)") }
                GridRow { Text(tr("Код / комм. / пустых")).foregroundStyle(.secondary); Text("\(file.codeLines) / \(file.commentLines) / \(file.blankLines)") }
                GridRow { Text(tr("Средняя CC")).foregroundStyle(.secondary); Text(String(format: "%.1f", file.avgCyclomatic)) }
                GridRow { Text("Maintainability").foregroundStyle(.secondary); Text(String(format: "%.0f", file.maintainability)) }
            }.font(.callout)
            Divider()
            Text(tr("Функции (%ld)", file.functions.count)).font(.subheadline.bold())
            List(file.functions.sorted { $0.cyclomatic > $1.cyclomatic }) { fn in
                HStack {
                    VStack(alignment: .leading) {
                        Text(fn.name).lineLimit(1)
                        Text(tr("строка %ld · %ld стр. · %ld парам.", fn.startLine, fn.length, fn.parameters)).font(.caption2).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text("CC \(fn.cyclomatic)").monospacedDigit().bold().foregroundStyle(Severity.cyclomatic(fn.cyclomatic).color)
                }
                .contentShape(Rectangle())
                .onTapGesture(count: 2) { model.openFile(file.path, line: fn.startLine) }
                .contextMenu {
                    Button(tr("Открыть функцию в %@", EditorSettings.shared.editor.name)) { model.openFile(file.path, line: fn.startLine) }
                }
            }.listStyle(.plain)
        }.padding(12)
    }
}
