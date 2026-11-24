import AppKit
import Foundation

let args = CommandLine.arguments
let data = try! Data(contentsOf: URL(fileURLWithPath: args[1]))
let fontDir = args[2], outDir = args[3]
for f in ["BeVietnamPro-Bold", "BeVietnamPro-Medium"] {
    CTFontManagerRegisterFontsForURL(URL(fileURLWithPath: "\(fontDir)/\(f).ttf") as CFURL, .process, nil)
}
let movies = try! JSONSerialization.jsonObject(with: data) as! [[String: String]]

func color(_ hex: String) -> NSColor {
    var v: UInt64 = 0; Scanner(string: String(hex.dropFirst())).scanHexInt64(&v)
    return NSColor(srgbRed: CGFloat((v >> 16) & 0xFF) / 255, green: CGFloat((v >> 8) & 0xFF) / 255,
                   blue: CGFloat(v & 0xFF) / 255, alpha: 1)
}

func draw(_ text: String, font: String, size: CGFloat, in rect: NSRect, color: NSColor = .white,
          align: NSTextAlignment = .left) {
    let p = NSMutableParagraphStyle(); p.alignment = align; p.lineBreakMode = .byWordWrapping
    let shadow = NSShadow(); shadow.shadowColor = NSColor(white: 0, alpha: 0.5); shadow.shadowBlurRadius = 8
    NSAttributedString(string: text, attributes: [.font: NSFont(name: font, size: size)!,
        .foregroundColor: color, .paragraphStyle: p, .shadow: shadow]).draw(in: rect)
}

func render(_ m: [String: String], w: Int, h: Int, banner: Bool, to path: String) {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: w, pixelsHigh: h, bitsPerSample: 8,
        samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0,
        bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let W = CGFloat(w), H = CGFloat(h)
    NSGradient(starting: color(m["c2"]!), ending: color(m["c1"]!))!.draw(in: NSRect(x: 0, y: 0, width: W, height: H),
                                                                         angle: banner ? 200 : 250)
    // Soft circles for depth.
    for (i, r) in [0.55, 0.35, 0.2].enumerated() {
        NSColor(white: 1, alpha: 0.06 + 0.03 * CGFloat(i)).setFill()
        let d = min(W, H) * CGFloat(r) * 2
        NSBezierPath(ovalIn: NSRect(x: W * (banner ? 0.72 : 0.6) - d / 2, y: H * 0.7 - d / 2, width: d, height: d)).fill()
    }
    // Darken the text area.
    NSGradient(starting: NSColor(white: 0, alpha: 0.65), ending: NSColor(white: 0, alpha: 0))!
        .draw(in: NSRect(x: 0, y: 0, width: W, height: H * 0.55), angle: 90)
    let pad = W * 0.07
    if banner {
        draw(m["title"]!, font: "BeVietnamPro-Bold", size: 76, in: NSRect(x: pad, y: H * 0.2, width: W * 0.7, height: 200))
        draw(m["tag"]!, font: "BeVietnamPro-Medium", size: 32, in: NSRect(x: pad, y: H * 0.1, width: W * 0.8, height: 50),
             color: NSColor(white: 1, alpha: 0.85))
    } else {
        draw(m["title"]!.uppercased(), font: "BeVietnamPro-Bold", size: 64,
             in: NSRect(x: pad, y: H * 0.1, width: W - 2 * pad, height: 260), align: .center)
        draw(m["tag"]!, font: "BeVietnamPro-Medium", size: 24, in: NSRect(x: pad, y: H * 0.04, width: W - 2 * pad, height: 70),
             color: NSColor(white: 1, alpha: 0.85), align: .center)
        draw("CINEBOOK DEMO", font: "BeVietnamPro-Medium", size: 18, in: NSRect(x: 0, y: H - 50, width: W, height: 30),
             color: NSColor(white: 1, alpha: 0.7), align: .center)
    }
    NSGraphicsContext.restoreGraphicsState()
    let jpg = rep.representation(using: .jpeg, properties: [.compressionFactor: 0.78])!
    try! jpg.write(to: URL(fileURLWithPath: path))
}

for m in movies {
    render(m, w: 600, h: 900, banner: false, to: "\(outDir)/posters/\(m["slug"]!).jpg")
    render(m, w: 1280, h: 720, banner: true, to: "\(outDir)/banners/\(m["slug"]!).jpg")
}
print("rendered \(movies.count * 2)")
