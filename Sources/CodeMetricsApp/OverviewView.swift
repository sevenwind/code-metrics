import SwiftUI
import Charts
import CodeMetricsCore

struct OverviewView: View {
    let report: ProjectReport
    @Environment(AppModel.self) private var model

    private var buckets: [(label: String, count: Int, severity: Severity)] {
        let rows = model.functionRows
        func n(_ r: ClosedRange<Int>) -> Int { rows.filter { r.contains($0.cyclomatic) }.count }
        return [("1–5", n(1...5), .good), ("6–10", n(6...10), .good), ("11–20", n(11...20), .warn),
                ("21–50", n(21...50), .bad), ("50+", rows.filter { $0.cyclomatic > 50 }.count, .bad)]
    }

    /// Цвет по доле сложных функций: 0% — зелёный, ≥ 15% — красный.
    private var complexColor: Color {
        let total = max(1, model.functionRows.count)
        let share = Double(model.functionRows.filter { $0.cyclomatic > 10 }.count) / Double(total)
        return badnessColor(share / 0.15)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 170), spacing: 12)], spacing: 12) {
                    StatCard(title: tr("Файлы"), metric: .files, value: format(report.files.count), icon: "doc.on.doc")
                    StatCard(title: tr("Строки кода"), metric: .loc, value: format(report.codeLines), icon: "chevron.left.forwardslash.chevron.right")
                    StatCard(title: tr("Комментарии"), metric: .comments, value: format(report.commentLines),
                             subtitle: String(format: tr("%.1f%% от непустых"), 100 * Double(report.commentLines) / Double(max(1, report.codeLines + report.commentLines))), icon: "text.bubble")
                    StatCard(title: tr("Функции"), metric: .functions, value: format(model.functionRows.count), icon: "function")
                    StatCard(title: "Maintainability", metric: .maintainability, value: String(format: "%.0f", report.avgMaintainability),
                             subtitle: tr("из 100, средневзвешенно"), icon: "heart.text.square",
                             tint: Severity.maintainability(report.avgMaintainability).color)
                    CoverageCard()
                    CrapStat()
                    StatCard(title: tr("Сложных функций"), metric: .complexFunctions, value: format(model.functionRows.filter { $0.cyclomatic > 10 }.count),
                             subtitle: tr("цикломатика > 10"), icon: "exclamationmark.triangle",
                             tint: complexColor, valueColor: complexColor)
                }

                HStack(alignment: .top, spacing: 16) {
                    Card(title: tr("Языки (строки кода)"), metric: .languagesChart) {
                        Chart(report.languages) { l in
                            BarMark(x: .value("LOC", l.codeLines), y: .value(tr("Язык"), l.language))
                                .annotation(position: .trailing) { Text(tr("%@ · %ld ф.", format(l.codeLines), l.files)).font(.caption).foregroundStyle(.secondary) }
                        }
                        .chartXAxis(.hidden).frame(height: CGFloat(max(1, report.languages.count)) * 44 + 10)
                    }
                    Card(title: tr("Распределение сложности функций"), metric: .complexityChart) {
                        Chart(buckets, id: \.label) { b in
                            BarMark(x: .value("CC", b.label), y: .value(tr("Функций"), b.count))
                                .foregroundStyle(b.severity.color.gradient)
                        }
                        .frame(height: 150)
                    }
                }

                if model.coverage != nil {
                    HStack(alignment: .top, spacing: 16) {
                        Card(title: tr("Сложные функции без покрытия"), metric: .coverage) {
                            let rows = model.functionRows.filter { $0.cyclomatic > 5 && $0.coverage >= 0 && $0.coverage < 0.5 }
                                .sorted { $0.cyclomatic > $1.cyclomatic }.prefix(8)
                            if rows.isEmpty { Text(tr("Таких нет")).foregroundStyle(.secondary) }
                            VStack(spacing: 0) {
                                ForEach(Array(rows)) { r in
                                    HotspotRow(title: r.name, subtitle: "\(r.file):\(r.line)",
                                               value: String(format: "CC %d · %.0f%%", r.cyclomatic, r.coverage * 100),
                                               color: Severity.coverage(r.coverage).color).onTapGesture(count: 2) { model.openFile(r.file) }
                                }
                            }
                        }
                        Card(title: tr("Файлы с худшим покрытием"), metric: .coverage) {
                            VStack(spacing: 0) {
                                ForEach(report.files.filter { $0.coverage >= 0 && $0.codeLines >= 30 }.sorted { $0.coverage < $1.coverage }.prefix(8)) { f in
                                    HotspotRow(title: (f.path as NSString).lastPathComponent, subtitle: f.path,
                                               value: String(format: "%.0f%%", f.coverage * 100),
                                               color: Severity.coverage(f.coverage).color).onTapGesture(count: 2) { model.openFile(f.path) }
                                }
                            }
                        }
                    }
                }

                HStack(alignment: .top, spacing: 16) {
                    Card(title: tr("Самые сложные функции")) {
                        VStack(spacing: 0) {
                            ForEach(model.functionRows.sorted { $0.cyclomatic > $1.cyclomatic }.prefix(8)) { r in
                                HotspotRow(title: r.name, subtitle: "\(r.file):\(r.line)", value: "CC \(r.cyclomatic)",
                                           color: Severity.cyclomatic(r.cyclomatic).color).onTapGesture(count: 2) { model.openFile(r.file) }
                            }
                        }
                    }
                    Card(title: tr("Файлы с худшей поддерживаемостью")) {
                        VStack(spacing: 0) {
                            ForEach(report.files.filter { $0.codeLines >= 30 }.sorted { $0.maintainability < $1.maintainability }.prefix(8)) { f in
                                HotspotRow(title: (f.path as NSString).lastPathComponent, subtitle: f.path,
                                           value: String(format: "MI %.0f", f.maintainability),
                                           color: Severity.maintainability(f.maintainability).color).onTapGesture(count: 2) { model.openFile(f.path) }
                            }
                        }
                    }
                }
            }
            .padding(20)
        }
    }
}

/// Карточка CRAP в стиле «Покрытие тестами»: цвет значения — по градации зелёный → красный; без отчёта покрытия неактивна.
private struct CrapStat: View {
    @Environment(AppModel.self) private var model
    var body: some View {
        let vals = model.functionRows.map(\.crap).filter { $0 >= 0 }
        let has = model.coverage != nil && !vals.isEmpty
        let avg = has ? vals.reduce(0, +) / Double(vals.count) : 0
        let worst = vals.max() ?? 0
        let risky = vals.filter { $0 > 30 }.count
        StatCard(title: tr("Индекс CRAP"), metric: .crap,
                 value: has ? String(format: "%.1f", avg) : "—",
                 subtitle: has ? tr("макс. %@ · функций > 30: %ld", String(format: "%.0f", worst), risky) : nil,
                 icon: "speedometer",
                 tint: has ? crapColor(avg) : .secondary,
                 valueColor: has ? crapColor(avg) : nil,
                 dimmed: !has,
                 footer: AnyView(footer(has: has, avg: avg)))
    }

    @ViewBuilder private func footer(has: Bool, avg: Double) -> some View {
        if has {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(LinearGradient(colors: stride(from: 0.0, through: 1.0, by: 0.25).map { crapColor(1 + $0 * 29) },
                                             startPoint: .leading, endPoint: .trailing))
                        .frame(height: 5)
                    Circle().fill(.background).overlay(Circle().stroke(crapColor(avg), lineWidth: 2))
                        .frame(width: 10, height: 10)
                        .offset(x: max(0, min(1, (avg - 1) / 29)) * (geo.size.width - 10))
                }
            }
            .frame(height: 10).frame(maxWidth: 140)
            .help(tr("≤ 1 — зелёный, ≥ 30 — красный"))
        } else {
            Label(tr("Неактивно: нужен отчёт покрытия"), systemImage: "moon.zzz.fill")
                .font(.caption2).foregroundStyle(.secondary)
                .help(tr("Индекс CRAP считается по покрытию тестами: запустите тесты или выберите отчёт покрытия."))
        }
    }
}

/// Карточка покрытия: без отчёта затемнена, под значением — небольшая ссылка «Запустить тесты».
private struct CoverageCard: View {
    @Environment(AppModel.self) private var model
    var body: some View {
        let has = model.coverage != nil
        StatCard(title: tr("Покрытие тестами"), metric: .coverage,
                 value: model.coverage?.overall.map { String(format: "%.0f%%", $0 * 100) } ?? "—",
                 subtitle: model.coverage.map { tr("%@ · файлов: %ld", $0.source, $0.files.count) },
                 icon: "shield.checkered",
                 tint: model.coverage?.overall.map { badnessColor(1 - min(1, $0 / 0.8)) } ?? .secondary,
                 valueColor: model.coverage?.overall.map { badnessColor(1 - min(1, $0 / 0.8)) },
                 dimmed: !has,
                 footer: has ? nil : AnyView(footer))
    }

    @ViewBuilder private var footer: some View {
        if model.coverageRunning {
            HStack(spacing: 6) {
                ProgressView(value: model.coverageProgress).frame(maxWidth: 110)
                Text(String(format: "%.0f%%", model.coverageProgress * 100)).font(.caption2.monospacedDigit()).foregroundStyle(.secondary)
            }
            .help(tr("Идёт запуск тестов и сбор покрытия"))
        } else {
            VStack(alignment: .leading, spacing: 1) {
                Button { model.runTestsWithCoverage() } label: {
                    Label(tr("Запустить тесты"), systemImage: "play.fill").font(.caption2)
                }
                .buttonStyle(.link)
                .nativeTooltip(tr("Запустить тесты и создать отчёт о покрытии"))
                if !model.coverageNote.isEmpty {
                    let detail = model.coverageLog.isEmpty ? model.coverageNote : model.coverageLog
                    let shown = Binding<Bool>(get: { model.errorDetailShown }, set: { model.errorDetailShown = $0 })
                    Button { shown.wrappedValue.toggle() } label: {
                        Label(model.coverageNote, systemImage: "exclamationmark.circle").font(.caption2).foregroundStyle(.red)
                    }
                    .buttonStyle(.plain)
                    .nativeTooltip(detail)
                    .popover(isPresented: shown, arrowEdge: .bottom) {
                        ScrollView {
                            Text(detail).font(.callout).textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(12).frame(width: 460, height: 280)
                    }
                }
            }
        }
    }
}

struct StatCard: View {
    let title: String
    var metric: Metric? = nil
    let value: String
    var subtitle: String? = nil
    let icon: String
    var tint: Color = .accentColor
    var valueColor: Color? = nil
    var dimmed = false
    var footer: AnyView? = nil
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon).font(.title2).foregroundStyle(tint).frame(width: 30).help(title).opacity(dimmed ? 0.35 : 1)
            VStack(alignment: .leading, spacing: 2) {
                Group {
                    HStack(spacing: 4) {
                        Text(title).font(.caption).foregroundStyle(.secondary)
                        if let metric { InfoButton(metric: metric).font(.caption) }
                    }
                    Text(value).font(.title2.bold().monospacedDigit()).foregroundStyle(valueColor ?? .primary)
                    if let subtitle { Text(subtitle).font(.caption2).foregroundStyle(.secondary) }
                }.opacity(dimmed ? 0.35 : 1)
                if let footer { footer }
            }
            Spacer(minLength: 0)
        }
        .padding(14).frame(maxWidth: .infinity, minHeight: 74, alignment: .leading)
        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 12))
    }
}

struct Card<Content: View>: View {
    let title: String
    var metric: Metric? = nil
    @ViewBuilder let content: Content
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Text(title).font(.headline)
                if let metric { InfoButton(metric: metric) }
            }
            content
        }
        .padding(14).frame(maxWidth: .infinity, alignment: .topLeading)
        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 12))
    }
}

private struct HotspotRow: View {
    let title: String, subtitle: String, value: String, color: Color
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 1) {
                Text(title).lineLimit(1)
                Text(subtitle).font(.caption2).foregroundStyle(.secondary).lineLimit(1).truncationMode(.head)
            }
            Spacer()
            Text(value).font(.callout.monospacedDigit().bold()).foregroundStyle(color)
        }
        .padding(.vertical, 5).contentShape(Rectangle()).help(tr("Двойной клик — открыть файл"))
    }
}
