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
