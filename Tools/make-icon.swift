// Рисует иконку приложения (лупа с диаграммой) и собирает AppIcon.icns. Запуск: swift Tools/make-icon.swift <out-dir>
import AppKit

func draw(into ctx: CGContext, size: CGFloat) {
    let s = size / 1024
    ctx.scaleBy(x: s, y: s)
    // Координаты SVG: начало сверху слева, поэтому переворачиваем ось Y.
    ctx.translateBy(x: 0, y: 1024); ctx.scaleBy(x: 1, y: -1)

    let bg = CGPath(roundedRect: CGRect(x: 100, y: 100, width: 824, height: 824), cornerWidth: 185, cornerHeight: 185, transform: nil)
    ctx.saveGState(); ctx.addPath(bg); ctx.clip()
    let grad = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
        colors: [CGColor(red: 0.169, green: 0.424, blue: 0.965, alpha: 1), CGColor(red: 0.075, green: 0.769, blue: 0.639, alpha: 1)] as CFArray,
        locations: [0, 1])!
    ctx.drawLinearGradient(grad, start: CGPoint(x: 100, y: 100), end: CGPoint(x: 924, y: 924), options: [])
    ctx.restoreGState()

    let c = CGPoint(x: 460, y: 454)
    ctx.setFillColor(CGColor(gray: 1, alpha: 0.16))
    ctx.fillEllipse(in: CGRect(x: c.x - 215, y: c.y - 215, width: 430, height: 430))
    for (x, h, a) in [(368.0, 110.0, 0.95), (437.0, 190.0, 0.8), (506.0, 150.0, 0.95)] {
        ctx.setFillColor(CGColor(gray: 1, alpha: a))
        ctx.addPath(CGPath(roundedRect: CGRect(x: x, y: 540 - h, width: 46, height: h), cornerWidth: 10, cornerHeight: 10, transform: nil)); ctx.fillPath()
    }
    ctx.setStrokeColor(CGColor(gray: 1, alpha: 1))
    ctx.setLineWidth(56)
    ctx.strokeEllipse(in: CGRect(x: c.x - 215, y: c.y - 215, width: 430, height: 430))
    ctx.setLineWidth(84); ctx.setLineCap(.round)
    ctx.move(to: CGPoint(x: 636, y: 630)); ctx.addLine(to: CGPoint(x: 772, y: 766)); ctx.strokePath()
}

func png(size: Int) -> Data {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size, bitsPerSample: 8, samplesPerPixel: 4,
                               hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    let g = NSGraphicsContext(bitmapImageRep: rep)!
    g.cgContext.setShouldAntialias(true)
    draw(into: g.cgContext, size: CGFloat(size))
    return rep.representation(using: .png, properties: [:])!
}

let out = URL(fileURLWithPath: CommandLine.arguments.dropFirst().first ?? "AppIcon.iconset")
try FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)
for base in [16, 32, 128, 256, 512] {
    try png(size: base).write(to: out.appendingPathComponent("icon_\(base)x\(base).png"))
    try png(size: base * 2).write(to: out.appendingPathComponent("icon_\(base)x\(base)@2x.png"))
}
