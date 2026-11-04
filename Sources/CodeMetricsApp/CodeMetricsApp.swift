import SwiftUI

@main
struct CodeMetricsApp: App {
    private let model = AppModel()

    var body: some Scene {
        WindowGroup("Code Metrics") {
            ContentView()
                .environment(model)
                .frame(minWidth: 960, minHeight: 600)
        }
        .defaultSize(width: 1240, height: 780)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button(tr("Открыть папку…")) { model.chooseFolder() }.keyboardShortcut("o")
                Button(tr("К выбору проекта")) { model.closeProject() }.keyboardShortcut("w", modifiers: [.command, .shift]).disabled(model.root == nil)
                Menu(tr("Недавние")) {
                    ForEach(model.recents, id: \.self) { u in
                        Button(u.path.replacingOccurrences(of: NSHomeDirectory(), with: "~")) { model.open(u) }
                    }
                }.disabled(model.recents.isEmpty)
            }
            CommandGroup(after: .newItem) {
                Button(tr("Пересканировать")) { model.rescan() }.keyboardShortcut("r").disabled(model.root == nil)
                Button(tr("Экспорт в CSV…")) { model.exportCSV() }.keyboardShortcut("e").disabled(model.report == nil)
            }
        }
        Settings { SettingsView() }
    }
}

struct SettingsView: View {
    var body: some View {
        @Bindable var loc = Localizer.shared
        @Bindable var ed = EditorSettings.shared
        Form {
            Picker(tr("Язык интерфейса"), selection: $loc.language) {
                ForEach(AppLanguage.allCases) { Text($0.name).tag($0) }
            }
            .pickerStyle(.radioGroup)
            Picker(tr("Редактор"), selection: $ed.editor) {
                ForEach(CodeEditor.allCases) { e in
                    Text(e.isInstalled ? e.name : e.name + " " + tr("(не установлен)")).tag(e)
                }
            }
        }
        .padding(24).frame(width: 400)
    }
}
