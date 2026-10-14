#!/usr/bin/env swift
// Draws the Nota app icon in code and writes packaging/Nota.icns.
// Re-run after tweaking the artwork:  swift scripts/make_icon.swift
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
let output = root.appendingPathComponent("packaging/Nota.icns")
let sRGB = CGColorSpace(name: CGColorSpace.sRGB)!

func color(_ hex: UInt32, _ alpha: CGFloat = 1) -> CGColor {
    CGColor(
        srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
        green: CGFloat((hex >> 8) & 0xFF) / 255,
        blue: CGFloat(hex & 0xFF) / 255,
        alpha: alpha
    )
}

func gradient(_ colors: CGColor...) -> CGGradient {
    CGGradient(colorsSpace: sRGB, colors: colors as CFArray, locations: nil)!
}

func roundedRect(_ rect: CGRect, _ radius: CGFloat) -> CGPath {
    CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil)
}

/// Draws the artwork on Apple's 1024-unit icon grid. `k` is device pixels per unit:
/// the CTM is scaled by it, but shadow offset/blur ignore the CTM so they use it directly.
func drawIcon(_ ctx: CGContext, k: CGFloat) {
    ctx.scaleBy(x: k, y: k)

    // Background tile — the standard macOS 824×824 rounded square.
    let tile = CGRect(x: 100, y: 100, width: 824, height: 824)
    let tilePath = roundedRect(tile, 185)

    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -10 * k), blur: 22 * k, color: color(0x000000, 0.3))
    ctx.addPath(tilePath)
    ctx.setFillColor(color(0x3F5BE8))
    ctx.fillPath()
    ctx.restoreGState()

    ctx.saveGState()
    ctx.addPath(tilePath)
    ctx.clip()
    ctx.drawLinearGradient(
        gradient(color(0x62A0FF), color(0x3D4FE0), color(0x3A2FB8)),
        start: CGPoint(x: 512, y: 924), end: CGPoint(x: 512, y: 100), options: []
    )
    ctx.drawRadialGradient(
        gradient(color(0xFFFFFF, 0.28), color(0xFFFFFF, 0)),
        startCenter: CGPoint(x: 300, y: 900), startRadius: 0,
        endCenter: CGPoint(x: 300, y: 900), endRadius: 560, options: []
    )
    ctx.restoreGState()

    ctx.saveGState()
    ctx.addPath(roundedRect(tile.insetBy(dx: 2, dy: 2), 183))
    ctx.setStrokeColor(color(0xFFFFFF, 0.18))
    ctx.setLineWidth(4)
    ctx.strokePath()
    ctx.restoreGState()

    // The note — a tilted dark-glass card, like the app's own windows.
    ctx.saveGState()
    ctx.translateBy(x: 512, y: 500)
    ctx.rotate(by: 5 * .pi / 180)
    drawNote(ctx, k: k)
    ctx.restoreGState()
}

func drawNote(_ ctx: CGContext, k: CGFloat) {
    let card = CGRect(x: -270, y: -280, width: 540, height: 560)
    let cardPath = roundedRect(card, 64)

    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -24 * k), blur: 48 * k, color: color(0x0B0E3A, 0.55))
    ctx.addPath(cardPath)
    ctx.setFillColor(color(0x1D2030))
    ctx.fillPath()
    ctx.restoreGState()

    ctx.saveGState()
    ctx.addPath(cardPath)
    ctx.clip()
    ctx.drawLinearGradient(
        gradient(color(0x343849), color(0x1B1D29)),
        start: CGPoint(x: 0, y: card.maxY), end: CGPoint(x: 0, y: card.minY), options: []
    )
    ctx.restoreGState()

    ctx.saveGState()
    ctx.addPath(roundedRect(card.insetBy(dx: 2, dy: 2), 62))
    ctx.setStrokeColor(color(0xFFFFFF, 0.14))
    ctx.setLineWidth(4)
    ctx.strokePath()
    ctx.restoreGState()

    // Window controls.
    for (i, hex) in [0xFF5F57, 0xFEBC2E, 0x28C840].enumerated() {
        let center = CGPoint(x: card.minX + 62 + CGFloat(i) * 44, y: card.maxY - 58)
        ctx.addEllipse(in: CGRect(x: center.x - 14, y: center.y - 14, width: 28, height: 28))
        ctx.setFillColor(color(UInt32(hex)))
        ctx.fillPath()
    }

    // Heading.
    ctx.addPath(roundedRect(CGRect(x: -200, y: 116, width: 260, height: 38), 19))
    ctx.setFillColor(color(0xFFFFFF, 0.95))
    ctx.fillPath()

    // Checklist: one done item, two open ones.
    let rows: [(y: CGFloat, length: CGFloat, done: Bool)] = [
        (20, 250, true),
        (-80, 290, false),
        (-180, 200, false),
    ]
    let box: CGFloat = 60
    for row in rows {
        let boxRect = CGRect(x: -200, y: row.y - box / 2, width: box, height: box)
        if row.done {
            ctx.addPath(roundedRect(boxRect, 16))
            ctx.setFillColor(color(0x4C8DFF))
            ctx.fillPath()

            let check = CGMutablePath()
            check.move(to: CGPoint(x: boxRect.minX + 15, y: boxRect.minY + 31))
            check.addLine(to: CGPoint(x: boxRect.minX + 26, y: boxRect.minY + 19))
            check.addLine(to: CGPoint(x: boxRect.minX + 46, y: boxRect.minY + 43))
            ctx.addPath(check)
            ctx.setStrokeColor(color(0xFFFFFF))
            ctx.setLineWidth(9)
            ctx.setLineCap(.round)
            ctx.setLineJoin(.round)
            ctx.strokePath()
        } else {
            ctx.addPath(roundedRect(boxRect.insetBy(dx: 4.5, dy: 4.5), 13))
            ctx.setStrokeColor(color(0xFFFFFF, 0.55))
            ctx.setLineWidth(9)
            ctx.strokePath()
        }

        ctx.addPath(roundedRect(CGRect(x: -110, y: row.y - 14, width: row.length, height: 28), 14))
        ctx.setFillColor(color(0xFFFFFF, row.done ? 0.35 : 0.8))
        ctx.fillPath()
    }
}

func render(pixels: Int) -> CGImage {
    let ctx = CGContext(
        data: nil, width: pixels, height: pixels, bitsPerComponent: 8, bytesPerRow: 0,
        space: sRGB, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    )!
    drawIcon(ctx, k: CGFloat(pixels) / 1024)
    return ctx.makeImage()!
}

func writePNG(_ image: CGImage, to url: URL) {
    let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(destination, image, nil)
    guard CGImageDestinationFinalize(destination) else { fatalError("Could not write \(url.path)") }
}

let iconset = FileManager.default.temporaryDirectory
    .appendingPathComponent("Nota-\(UUID().uuidString).iconset")
try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)
defer { try? FileManager.default.removeItem(at: iconset) }

for points in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let name = "icon_\(points)x\(points)\(scale == 2 ? "@2x" : "").png"
        writePNG(render(pixels: points * scale), to: iconset.appendingPathComponent(name))
    }
}

let iconutil = Process()
iconutil.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
iconutil.arguments = ["-c", "icns", iconset.path, "-o", output.path]
try iconutil.run()
iconutil.waitUntilExit()
guard iconutil.terminationStatus == 0 else { fatalError("iconutil failed") }
print("✅ Wrote \(output.path)")
