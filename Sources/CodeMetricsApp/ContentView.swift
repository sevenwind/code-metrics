import SwiftUI
import CodeMetricsCore

struct ContentView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model
        NavigationSplitView {
            List(NavSection.allCases, selection: $model.section) { s in
                Label(s.title, systemImage: s.icon).tag(s)
            }
            .navigationSplitViewColumnWidth(min: 160, ideal: 180, max: 220)
            .safeAreaInset(edge: .bottom) { ProjectBadge() }
        } detail: {
            ZStack {
                if model.report == nil && !model.isScanning {
                    WelcomeView()
                } else if let report = model.report {
                    switch model.section {
                    case .overview: OverviewView(report: report)
                    case .files: FilesView(report: report)
                    case .functions: FunctionsView()
                    case .architecture: ArchitectureView()
                    case .folders: FoldersView(report: report)
                    }
                }
                if model.isScanning { ScanOverlay() }
            }
            .navigationTitle(model.root?.lastPathComponent ?? "Code Metrics")
            .navigationSubtitle(model.report.map { tr("%ld файлов · %@ строк кода", $0.files.count, format($0.codeLines)) } ?? "")
        }
        .searchable(text: $model.search, placement: .toolbar, prompt: tr("Поиск по файлам и функциям"))
        .toolbar {
            ToolbarItemGroup {
                Button { model.closeProject() } label: { Label(tr("К выбору проекта"), systemImage: "chevron.backward") }
                    .disabled(model.root == nil)
                    .help(tr("Закрыть проект и вернуться к выбору папки"))
                Button { model.openProjectInEditor() } label: {
                    Label(tr("Открыть в редакторе"), systemImage: "chevron.left.forwardslash.chevron.right")
                }
                .disabled(model.root == nil)
                .help(tr("Открыть проект в %@", EditorSettings.shared.editor.name))
                Button { model.chooseFolder() } label: { Label(tr("Открыть папку"), systemImage: "folder") }
                    .help(tr("Открыть папку проекта для анализа (⌘O)"))
                Button { model.rescan() } label: { Label(tr("Пересканировать"), systemImage: "arrow.clockwise") }
                    .disabled(model.root == nil || model.isScanning)
                    .help(tr("Пересканировать проект заново (⌘R)"))
                Menu {
                    Button(tr("Выбрать файл отчёта…")) { model.chooseCoverageFile() }.help(tr("Указать lcov.info, coverage-final.json или coverage.out вручную"))
                    Button(tr("Запустить тесты и создать отчёт о покрытии")) { model.runTestsWithCoverage() }
                        .disabled(model.coverageRunning)
                    Button(tr("Найти автоматически")) { model.loadCoverage() }.help(tr("Искать отчёт в стандартных местах проекта (coverage/lcov.info и т. п.)"))
                } label: { Label(tr("Покрытие тестами"), systemImage: "shield.checkered") }
                    .disabled(model.report == nil)
                    .help(tr("Загрузить отчёт покрытия тестами (lcov.info, coverage-final.json, coverage.out)"))
                Toggle(isOn: $model.includeTests) { Label(tr("Тесты"), systemImage: "checkmark.seal") }
                    .help(tr("Учитывать тестовые файлы (*.test.*, *.spec.*, *_test.go) при следующем сканировании"))
            }
        }
        .dropDestination(for: URL.self) { urls, _ in
            guard let u = urls.first, (try? u.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true else { return false }
            model.open(u); return true
        } isTargeted: { model.dropTargeted = $0 }
        .overlay { if model.dropTargeted { RoundedRectangle(cornerRadius: 12).strokeBorder(.tint, style: StrokeStyle(lineWidth: 3, dash: [8])).padding(8) } }
    }
}

func format(_ n: Int) -> String { n.formatted(.number.grouping(.automatic)) }

private struct ProjectBadge: View {
    @Environment(AppModel.self) private var model
    var body: some View {
        if let r = model.report {
            VStack(alignment: .leading, spacing: 2) {
                Text(String(format: tr("Просканировано за %.1f с"), r.duration)).font(.caption)
                if r.skipped > 0 { Text(tr("Пропущено: %ld", r.skipped)).font(.caption2).foregroundStyle(.secondary) }
            }
            .foregroundStyle(.secondary).frame(maxWidth: .infinity, alignment: .leading).padding(10)
        }
    }
}

private struct ScanOverlay: View {
    @Environment(AppModel.self) private var model
    var body: some View {
        VStack(spacing: 12) {
            ProgressView(value: model.progress).frame(width: 280).help(tr("Прогресс анализа файлов"))
            Text(tr("Анализ… %ld%%", Int(model.progress * 100))).font(.headline)
            Text(model.currentFile).font(.caption).foregroundStyle(.secondary).lineLimit(1).truncationMode(.middle).frame(width: 360)
            Button(tr("Отмена")) { model.cancel() }.help(tr("Прервать анализ"))
        }
        .padding(28)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
        .shadow(radius: 12)
    }
}

private struct WelcomeView: View {
    @Environment(AppModel.self) private var model
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "chart.bar.doc.horizontal").font(.system(size: 54)).foregroundStyle(.tint)
            Text(tr("Метрики кода")).font(.largeTitle.bold())
            Text(tr("Перетащите папку проекта в окно или выберите её вручную.\nTypeScript, JavaScript, Go."))
                .multilineTextAlignment(.center).foregroundStyle(.secondary)
            Button(tr("Открыть папку…")) { model.chooseFolder() }.help(tr("Выбрать папку проекта для анализа")).buttonStyle(.borderedProminent).controlSize(.large)
            if !model.recents.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text(tr("Недавние")).font(.caption).foregroundStyle(.secondary)
                    ForEach(model.recents.prefix(5), id: \.self) { u in
                        Button { model.open(u) } label: {
                            Label(u.path.replacingOccurrences(of: NSHomeDirectory(), with: "~"), systemImage: "clock")
                        }.buttonStyle(.link).help(tr("Открыть недавний проект: %@", u.path))
                    }
                }.padding(.top, 8)
            }
        }.padding(40)
    }
}
