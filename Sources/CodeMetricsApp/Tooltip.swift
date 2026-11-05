import SwiftUI
import AppKit

/// Нативный тултип через NSView.toolTip — срабатывает и там, где SwiftUI `.help` молчит (многострочный текст, вложенные карточки).
private struct TooltipOverlay: NSViewRepresentable {
    let text: String
    func makeNSView(context: Context) -> NSView { PassThroughView() }
    func updateNSView(_ view: NSView, context: Context) { view.toolTip = text }
}

private final class PassThroughView: NSView {
    override func hitTest(_ point: NSPoint) -> NSView? { nil }   // клики проходят к кнопке под ним
}

extension View {
    func nativeTooltip(_ text: String) -> some View { overlay(TooltipOverlay(text: text)) }
}

/// Тултипы на заголовки колонок `Table`: SwiftUI не даёт вешать `.help` на заголовок, поэтому
/// находим нижележащий NSTableView и вешаем тултип на прямоугольник всей ячейки заголовка
/// (`NSTableHeaderView.addToolTip`), а не только на текст. Прямоугольники обновляются при смене ширины колонок.
private struct ColumnTooltips: NSViewRepresentable {
    let tips: [String: String]

    func makeCoordinator() -> Coordinator { Coordinator() }
    func makeNSView(context: Context) -> NSView { NSView() }

    func updateNSView(_ view: NSView, context: Context) {
        let tips = tips, coordinator = context.coordinator
        // Таблица может появиться в иерархии не сразу — повторяем попытку.
        for delay in [0.05, 0.4, 1.2] {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak view] in
                guard let root = view?.window?.contentView else { return }
                coordinator.apply(root, tips)
            }
        }
    }

    final class Coordinator {
        private var owners: [ObjectIdentifier: [NSString]] = [:]   // NSToolTipOwner не удерживается AppKit
        private var observed = Set<ObjectIdentifier>()
        private var tipsByTable: [ObjectIdentifier: [String: String]] = [:]

        func apply(_ view: NSView, _ tips: [String: String]) {
            if let table = view as? NSTableView, table.tableColumns.contains(where: { tips[$0.title] != nil }) {
                tipsByTable[ObjectIdentifier(table)] = tips
                configure(table)
                observe(table)
            }
            for sub in view.subviews { apply(sub, tips) }
        }

        private func configure(_ table: NSTableView) {
            guard let header = table.headerView, let tips = tipsByTable[ObjectIdentifier(table)] else { return }
            header.removeAllToolTips()
            var list: [NSString] = []
            for (i, c) in table.tableColumns.enumerated() {
                c.headerToolTip = nil
                guard let tip = tips[c.title] else { continue }
                let owner = tip as NSString
                list.append(owner)
                header.addToolTip(header.headerRect(ofColumn: i), owner: owner, userData: nil)
            }
            owners[ObjectIdentifier(table)] = list
        }

        private func observe(_ table: NSTableView) {
            let id = ObjectIdentifier(table)
            guard observed.insert(id).inserted else { return }
            let reconfigure: (Notification) -> Void = { [weak self, weak table] _ in
                guard let self, let table else { return }
                self.configure(table)
            }
            let nc = NotificationCenter.default
            nc.addObserver(forName: NSTableView.columnDidResizeNotification, object: table, queue: .main, using: reconfigure)
            nc.addObserver(forName: NSTableView.columnDidMoveNotification, object: table, queue: .main, using: reconfigure)
            if let header = table.headerView {
                header.postsFrameChangedNotifications = true
                nc.addObserver(forName: NSView.frameDidChangeNotification, object: header, queue: .main, using: reconfigure)
            }
        }
    }
}

extension View {
    /// `tips`: название колонки → текст подсказки.
    func columnTooltips(_ tips: [String: String]) -> some View { background(ColumnTooltips(tips: tips)) }
}

/// Подсказка по метрике: название и описание.
func metricTip(_ m: Metric) -> String { m.title + "\n" + m.text }
