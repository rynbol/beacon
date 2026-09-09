#!/usr/bin/env swift
// Renders Beacon's existing lighthouse geometry at every macOS icon size.
import AppKit

let output = CommandLine.arguments.dropFirst().first ?? "build/Beacon.iconset"
try FileManager.default.createDirectory(atPath: output, withIntermediateDirectories: true)
for size in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let pixels = size * scale
        let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
            colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
        let context = NSGraphicsContext.current!.cgContext
        context.scaleBy(x: CGFloat(pixels) / 1024, y: CGFloat(pixels) / 1024)
        NSColor(srgbRed: 43/255, green: 101/255, blue: 104/255, alpha: 1).setFill()
        NSBezierPath(roundedRect: NSRect(x: 64, y: 64, width: 896, height: 896),
                     xRadius: 200, yRadius: 200).fill()
        context.translateBy(x: 188, y: 836)
        context.scaleBy(x: 27, y: -27)
        NSColor(srgbRed: 249/255, green: 247/255, blue: 242/255, alpha: 1).setStroke()
        let path = NSBezierPath()
        path.lineWidth = 1.65
        path.lineCapStyle = .round
        path.lineJoinStyle = .round
        func line(_ points: [(CGFloat, CGFloat)]) {
            path.move(to: NSPoint(x: points[0].0, y: points[0].1))
            for point in points.dropFirst() { path.line(to: NSPoint(x: point.0, y: point.1)) }
        }
        line([(8,21),(10,10),(14,10),(16,21)])
        line([(6,21),(18,21)])
        path.appendRoundedRect(NSRect(x: 9, y: 5, width: 6, height: 5), xRadius: 1, yRadius: 1)
        line([(12,2),(12,3)])
        line([(3,5),(6,7)]); line([(18,7),(21,5)])
        line([(3,11),(6,10)]); line([(18,10),(21,11)])
        line([(10,16),(14,16)])
        path.stroke()
        NSGraphicsContext.restoreGraphicsState()
        let suffix = scale == 2 ? "@2x" : ""
        let url = URL(fileURLWithPath: output).appendingPathComponent("icon_\(size)x\(size)\(suffix).png")
        try bitmap.representation(using: .png, properties: [:])!.write(to: url)
    }
}
