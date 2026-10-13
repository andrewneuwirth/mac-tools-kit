// The family icon plate (design system › AppIcon), so every tool's icon has the same geometry.
//   swift icon.swift <accent hex> <SF Symbol name> <out.icns>
// Plate: 1024 canvas, 824 tile at inset 100, radius 185; accent sunk into ground #0e0f12
// (62% top → 22% bottom); white sheen .14→0 over the top half; 10pt inner stroke white .14;
// one white glyph at ~50% of the tile.
import AppKit

let args = CommandLine.arguments
guard args.count == 4, let hex = UInt32(args[1].trimmingCharacters(in: ["#"]), radix: 16) else {
    print("usage: swift icon.swift <accent hex> <SF Symbol name> <out.icns>"); exit(1)
}
let symbolName = args[2], out = URL(fileURLWithPath: args[3])

func mix(_ c: UInt32, _ amount: CGFloat) -> NSColor {
    let ground: [CGFloat] = [0x0e, 0x0f, 0x12].map { $0 / 255 }
    let rgb: [CGFloat] = [c >> 16 & 0xff, c >> 8 & 0xff, c & 0xff].map { CGFloat($0) / 255 }
    let m = zip(rgb, ground).map { $0 * amount + $1 * (1 - amount) }
    return NSColor(srgbRed: m[0], green: m[1], blue: m[2], alpha: 1)
}

func render(_ px: Int) -> Data {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px, bitsPerSample: 8,
                               samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
                               bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let s = CGFloat(px) / 1024
    let tile = NSRect(x: 100 * s, y: 100 * s, width: 824 * s, height: 824 * s)
    let plate = NSBezierPath(roundedRect: tile, xRadius: 185 * s, yRadius: 185 * s)
    NSGradient(starting: mix(hex, 0.22), ending: mix(hex, 0.62))!.draw(in: plate, angle: 90)

    // Glyph, white, centred.
    let config = NSImage.SymbolConfiguration(pointSize: 420 * s, weight: .medium)
        .applying(.init(paletteColors: [.white]))
    if let glyph = NSImage(systemSymbolName: symbolName, accessibilityDescription: nil)?.withSymbolConfiguration(config) {
        let fit = min(460 * s / glyph.size.width, 460 * s / glyph.size.height, 1)
        let size = NSSize(width: glyph.size.width * fit, height: glyph.size.height * fit)
        glyph.draw(in: NSRect(x: (CGFloat(px) - size.width) / 2, y: (CGFloat(px) - size.height) / 2,
                              width: size.width, height: size.height))
    }

    // Sheen over the top half, then the inner stroke.
    NSGraphicsContext.saveGraphicsState()
    plate.addClip()
    NSGradient(colors: [.white.withAlphaComponent(0), .white.withAlphaComponent(0.14)],
               atLocations: [0.5, 1], colorSpace: .sRGB)!.draw(in: tile, angle: 90)
    NSGraphicsContext.restoreGraphicsState()
    let inner = NSBezierPath(roundedRect: tile.insetBy(dx: 5 * s, dy: 5 * s), xRadius: 180 * s, yRadius: 180 * s)
    inner.lineWidth = 10 * s
    NSColor.white.withAlphaComponent(0.14).setStroke()
    inner.stroke()

    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

let set = FileManager.default.temporaryDirectory.appendingPathComponent("plate-\(getpid()).iconset")
try? FileManager.default.createDirectory(at: set, withIntermediateDirectories: true)
for base in [16, 32, 128, 256, 512] {
    try! render(base).write(to: set.appendingPathComponent("icon_\(base)x\(base).png"))
    try! render(base * 2).write(to: set.appendingPathComponent("icon_\(base)x\(base)@2x.png"))
}
let p = Process()
p.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
p.arguments = ["-c", "icns", set.path, "-o", out.path]
try! p.run(); p.waitUntilExit()
try? FileManager.default.removeItem(at: set)
print(p.terminationStatus == 0 ? "wrote \(out.path)" : "iconutil failed")
