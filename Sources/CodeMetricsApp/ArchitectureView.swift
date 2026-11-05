import SwiftUI
import Charts
import CodeMetricsCore

/// Архитектурные метрики: пакеты (Ca, Ce, I, A, D по Мартину) и классы (WMC, CBO).
struct ArchitectureView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model
        VStack(spacing: 0) {
            HStack {
                Picker("", selection: Binding(get: { model.archTab }, set: { model.archTab = $0 })) {
                    Text(tr("Пакеты")).tag(ArchTab.packages)
                    Text(tr("Классы")).tag(ArchTab.classes)
                }
                .pickerStyle(.segmented).labelsHidden().fixedSize()
                .help(tr("Пакеты — папки проекта (Ca, Ce, I, A, D); классы — WMC и CBO"))
                Spacer()
                if model.archTab == .packages {
                    MetricLegend(items: [("Ca", .ca), ("Ce", .ce), ("I", .instability), ("A", .abstractness), ("D", .distance)])
                } else {
                    MetricLegend(items: [("WMC", .wmc), ("CBO", .cbo)])
                }
            }.padding(.horizontal, 12).padding(.vertical, 8)
            Divider()
            if model.archTab == .packages { PackagesTable() } else { ClassesTable() }
        }
    }
}

private func dColor(_ d: Double) -> Color { badnessColor(d / 0.6) }

private struct PackagesTable: View {
    @Environment(AppModel.self) private var model

    private var rows: [PackageMetrics] {
        let q = model.search.trimmingCharacters(in: .whitespaces)
        return model.packages.filter { q.isEmpty || $0.path.localizedCaseInsensitiveContains(q) }.sorted(using: model.packagesSort)
    }

    var body: some View {
        @Bindable var model = model
        let rows = rows
        let points = model.packages.compactMap { p -> (id: String, i: Double, a: Double, d: Double)? in
            guard let i = p.instability, let a = p.abstractness, let d = p.distance else { return nil }
            return (p.path, i, a, d)
        }
        VStack(spacing: 0) {
            if !points.isEmpty {
                Chart {
                    LineMark(x: .value("I", 0), y: .value("A", 1), series: .value("s", "main"))
                        .foregroundStyle(.gray).lineStyle(StrokeStyle(lineWidth: 1, dash: [4]))
                    LineMark(x: .value("I", 1), y: .value("A", 0), series: .value("s", "main"))
                        .foregroundStyle(.gray).lineStyle(StrokeStyle(lineWidth: 1, dash: [4]))
                    ForEach(points, id: \.id) { p in
                        PointMark(x: .value("I", p.i), y: .value("A", p.a))
                            .foregroundStyle(dColor(p.d)).symbolSize(70)
                    }
                }
                .chartXScale(domain: 0...1).chartYScale(domain: 0...1)
                .chartXAxisLabel(tr("I — нестабильность")).chartYAxisLabel(tr("A — абстрактность"))
                .frame(height: 170).padding(.horizontal, 16).padding(.top, 10)
                .help(tr("Диаграмма главной последовательности: чем дальше точка от пунктирной линии, тем больше D"))
                Divider().padding(.top, 8)
            }
            Table(rows, sortOrder: $model.packagesSort) {
                TableColumn(tr("Пакет"), value: \.path) { p in
                    Text(p.path).fontWeight(.medium).lineLimit(1).truncationMode(.head)
                }.width(min: 200, ideal: 380)
                TableColumn(tr("Файлы"), value: \.files) { Text("\($0.files)").monospacedDigit() }.width(60)
                TableColumn("Ca", value: \.ca) { Text("\($0.ca)").monospacedDigit() }.width(50)
                TableColumn("Ce", value: \.ce) { Text("\($0.ce)").monospacedDigit() }.width(50)
                TableColumn("I", value: \.sortI) { p in
                    if let i = p.instability { Text(String(format: "%.2f", i)).monospacedDigit() } else { Text("—").foregroundStyle(.secondary) }
                }.width(55)
                TableColumn("A", value: \.sortA) { p in
                    if let a = p.abstractness { Text(String(format: "%.2f", a)).monospacedDigit() } else { Text("—").foregroundStyle(.secondary) }
                }.width(55)
                TableColumn("D", value: \.sortD) { p in
                    if let d = p.distance { Text(String(format: "%.2f", d)).monospacedDigit().bold().foregroundStyle(dColor(d)) }
                    else { Text("—").foregroundStyle(.secondary) }
                }.width(55)
            }
            .columnTooltips([
                tr("Пакет"): tr("Папка проекта (пакет в терминах Мартина)"),
                tr("Файлы"): tr("Количество файлов в пакете"),
                "Ca": metricTip(.ca), "Ce": metricTip(.ce), "I": metricTip(.instability),
                "A": metricTip(.abstractness), "D": metricTip(.distance),
            ])
        }
    }
}

private struct ClassesTable: View {
    @Environment(AppModel.self) private var model

    private var rows: [ClassRow] {
        let q = model.search.trimmingCharacters(in: .whitespaces)
        return model.classRows
            .filter { q.isEmpty || $0.name.localizedCaseInsensitiveContains(q) || $0.file.localizedCaseInsensitiveContains(q) }
            .sorted(using: model.classesSort)
    }

    var body: some View {
        @Bindable var model = model
        let rows = rows
        Table(rows, sortOrder: $model.classesSort) {
            TableColumn(tr("Класс"), value: \.name) { r in
                HStack(spacing: 4) {
                    Text(r.name).fontWeight(.medium)
                    if r.cls.kind == .abstractClass { Text("abstract").font(.caption2).foregroundStyle(.secondary) }
                    if r.cls.kind == .structType { Text("struct").font(.caption2).foregroundStyle(.secondary) }
                }
            }.width(min: 160, ideal: 240)
            TableColumn(tr("Файл"), value: \.file) { r in
                Text("\(r.file):\(r.line)").foregroundStyle(.secondary).lineLimit(1).truncationMode(.head)
            }.width(min: 200, ideal: 380)
            TableColumn(tr("Методы"), value: \.methods) { Text("\($0.methods)").monospacedDigit() }.width(70)
            TableColumn("WMC", value: \.wmc) { r in
                Text("\(r.wmc)").monospacedDigit().bold().foregroundStyle(Severity.wmc(r.wmc).color)
            }.width(60)
            TableColumn("CBO", value: \.cbo) { r in
                Text("\(r.cbo)").monospacedDigit().foregroundStyle(Severity.cbo(r.cbo).color)
            }.width(60)
        }
        .columnTooltips([
            tr("Класс"): tr("Имя класса или структуры (Go)"),
            tr("Файл"): tr("Файл и строка объявления"),
            tr("Методы"): tr("Число методов класса"),
            "WMC": metricTip(.wmc), "CBO": metricTip(.cbo),
        ])
        .contextMenu(forSelectionType: ClassRow.ID.self) { ids in
            if let r = model.classRows.first(where: { $0.id == ids.first }) {
                Button(tr("Открыть класс в %@", EditorSettings.shared.editor.name)) { model.openFile(r.file, line: r.line) }
                Button(tr("Открыть файл в %@", EditorSettings.shared.editor.name)) { model.openFile(r.file) }
                Button(tr("Показать в Finder")) { model.reveal(r.file) }
            }
        } primaryAction: { ids in
            if let r = model.classRows.first(where: { $0.id == ids.first }) { model.openFile(r.file, line: r.line) }
        }
    }
}
