// The Dispatch-style tile: one colour as a soft top-to-bottom gradient, a big bold white SF Symbol, Apple's grid.
//   swift icon-tile.swift <hex> <SF Symbol> <out.icns | out.png>
// Same geometry as Dispatch's IconArt: an 824 tile inset 100 on the 1024 canvas, radius 185, a faint edge and shadow.
import AppKit
import SwiftUI

let args = CommandLine.arguments
guard args.count == 4, let hex = UInt32(args[1].trimmingCharacters(in: ["#"]), radix: 16) else {
    print("usage: swift icon-tile.swift <hex> <SF Symbol> <out.icns|out.png>"); exit(1)
}
let base = Color(red: Double(hex >> 16 & 0xff) / 255, green: Double(hex >> 8 & 0xff) / 255, blue: Double(hex & 0xff) / 255)
let symbol = args[2], out = URL(fileURLWithPath: args[3])

@MainActor func tile() -> some View {
    ZStack {
        RoundedRectangle(cornerRadius: 185, style: .continuous)
            // Lighter at the top, a touch deeper at the bottom, like light falling on it.
            .fill(LinearGradient(colors: [base.mix(with: .white, by: 0.22), base.mix(with: .black, by: 0.10)], startPoint: .top, endPoint: .bottom))
            .overlay(RoundedRectangle(cornerRadius: 185, style: .continuous).strokeBorder(Color.white.opacity(0.18), lineWidth: 6))
            .shadow(color: .black.opacity(0.22), radius: 14, y: 8)
            .frame(width: 824, height: 824)
        Image(systemName: symbol)
            .font(.system(size: 400, weight: .semibold))
            .foregroundStyle(.white)
            .shadow(color: .black.opacity(0.12), radius: 6, y: 3)
    }
    .frame(width: 1024, height: 1024)
}

@MainActor func png(_ px: Int) -> Data? {
    let r = ImageRenderer(content: tile())
    r.scale = CGFloat(px) / 1024
    guard let cg = r.cgImage else { return nil }
    return NSBitmapImageRep(cgImage: cg).representation(using: .png, properties: [:])
}

MainActor.assumeIsolated {
    if out.pathExtension == "png" { try? png(512)?.write(to: out); exit(0) }
    let set = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString + ".iconset")
    try? FileManager.default.createDirectory(at: set, withIntermediateDirectories: true)
    for (px, name) in [(16, "16x16"), (32, "16x16@2x"), (32, "32x32"), (64, "32x32@2x"), (128, "128x128"), (256, "128x128@2x"),
                       (256, "256x256"), (512, "256x256@2x"), (512, "512x512"), (1024, "512x512@2x")] {
        try? png(px)?.write(to: set.appendingPathComponent("icon_\(name).png"))
    }
    let p = Process()
    p.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
    p.arguments = ["-c", "icns", set.path, "-o", out.path]
    try? p.run(); p.waitUntilExit()
    try? FileManager.default.removeItem(at: set)
}
