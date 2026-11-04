import SwiftUI
import CodeMetricsCore

struct FunctionsView: View {
    @Environment(AppModel.self) private var model

    private var rows: [FunctionRow] {
        let q = model.search.trimmingCharacters(in: .whitespaces)
        return model.functionRows
            .filter { $0.cyclomatic >= model.minCC && (q.isEmpty || $0.name.localizedCaseInsensitiveContains(q) || $0.file.localizedCaseInsensitiveContains(q)) }
            .sorted(using: model.functionsSort)
    }

    var body: some View {
        @Bindable var model = model
        let rows = rows
        VStack(spacing: 0) {
            HStack {
                Stepper(tr("Цикломатика ≥ %ld", model.minCC), value: $model.minCC, in: 1...100)
                    .help(tr("Показывать только функции с цикломатической сложностью не ниже этого порога"))
                Spacer()
                MetricLegend(items: [("CC", .cc), ("Cog", .cog), (tr("Длина"), .length), ("Cov", .coverage), ("CRAP", .crap), (tr("Парам."), .params), (tr("Вложен."), .nesting)])
                Spacer()
                Text(tr("%@ из %@", format(rows.count), format(model.functionRows.count))).foregroundStyle(.secondary).font(.callout).help(tr("Показано функций из общего числа"))
            }.padding(.horizontal, 12).padding(.vertical, 8)
            Divider()
            Table(rows, selection: $model.functionsSelection, sortOrder: $model.functionsSort) {
                TableColumn(tr("Функция"), value: \.name) { Text($0.name).fontWeight(.medium) }.width(min: 140, ideal: 220)
                TableColumn(tr("Файл"), value: \.file) { r in
                    Text("\(r.file):\(r.line)").foregroundStyle(.secondary).lineLimit(1).truncationMode(.head)
                }.width(min: 200, ideal: 380)
                TableColumn("CC", value: \.cyclomatic) { r in
                    Text("\(r.cyclomatic)").monospacedDigit().bold().foregroundStyle(Severity.cyclomatic(r.cyclomatic).color)
                }.width(50)
                TableColumn("Cog", value: \.cognitive) { r in
                    Text("\(r.cognitive)").monospacedDigit().foregroundStyle(Severity.cognitive(r.cognitive).color)
                }.width(50)
                TableColumn(tr("Длина"), value: \.length) { r in
                    Text("\(r.length)").monospacedDigit().foregroundStyle(Severity.length(r.length).color)
                }.width(60)
                TableColumn("Cov", value: \.coverage) { r in
                    if r.coverage < 0 { Text("—").foregroundStyle(.secondary) }
                    else { Text(String(format: "%.0f%%", r.coverage * 100)).monospacedDigit().foregroundStyle(Severity.coverage(r.coverage).color) }
                }.width(55)
                TableColumn("CRAP", value: \.crap) { r in
                    if r.crap < 0 { Text("—").foregroundStyle(.secondary) }
                    else { Text(String(format: r.crap < 100 ? "%.1f" : "%.0f", r.crap)).monospacedDigit().bold().foregroundStyle(crapColor(r.crap)) }
                }.width(60)
                TableColumn(tr("Парам."), value: \.parameters) { Text("\($0.parameters)").monospacedDigit() }.width(55)
                TableColumn(tr("Вложен."), value: \.nesting) { Text("\($0.nesting)").monospacedDigit() }.width(60)
            }
            .contextMenu(forSelectionType: FunctionRow.ID.self) { ids in
                if let r = model.functionRows.first(where: { $0.id == ids.first }) {
                    Button(tr("Открыть файл")) { model.openFile(r.file) }
                    Button(tr("Показать в Finder")) { model.reveal(r.file) }
                    Divider()
                    Button(tr("Исключить файл из анализа")) { model.exclude([r.file]) }
                }
            } primaryAction: { ids in
                if let r = model.functionRows.first(where: { $0.id == ids.first }) { model.openFile(r.file) }
            }
        }
    }
}
