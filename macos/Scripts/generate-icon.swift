import AppKit
import Foundation
let directory = URL(fileURLWithPath: CommandLine.arguments[1])
let sizes: [(Int, Int)] = [(16,1),(16,2),(32,1),(32,2),(128,1),(128,2),(256,1),(256,2),(512,1),(512,2)]
var entries: [[String: String]] = []
for (base, scale) in sizes {
    let pixels = base * scale
    let image = NSImage(size: NSSize(width: pixels, height: pixels))
    image.lockFocus()
    let factor = CGFloat(pixels) / 1024
    let transform = AffineTransform(scale: factor); (transform as NSAffineTransform).concat()
    let rect = NSRect(x: 62, y: 62, width: 900, height: 900)
    let shape = NSBezierPath(roundedRect: rect, xRadius: 202, yRadius: 202)
    NSColor(srgbRed: 0.057, green: 0.073, blue: 0.090, alpha: 1).setFill(); shape.fill()
    NSColor(white: 0.4, alpha: 0.24).setStroke(); shape.lineWidth = 3; shape.stroke()
    let inner = NSBezierPath(roundedRect: NSRect(x: 177, y: 177, width: 670, height: 670), xRadius: 140, yRadius: 140)
    NSColor(srgbRed: 0.40, green: 0.85, blue: 0.68, alpha: 0.10).setStroke(); inner.lineWidth = 2; inner.stroke()
    let line = NSBezierPath(); line.move(to: NSPoint(x: 268, y: 644)); line.line(to: NSPoint(x: 268, y: 350)); line.line(to: NSPoint(x: 442, y: 350)); line.line(to: NSPoint(x: 524, y: 546)); line.line(to: NSPoint(x: 615, y: 428)); line.line(to: NSPoint(x: 757, y: 674))
    line.lineWidth = 37; line.lineCapStyle = .round; line.lineJoinStyle = .round
    NSColor(srgbRed: 0.40, green: 0.85, blue: 0.68, alpha: 1).setStroke(); line.stroke()
    NSColor(srgbRed: 0.40, green: 0.85, blue: 0.68, alpha: 0.6).setFill(); NSBezierPath(ovalIn: NSRect(x: 737, y: 654, width: 40, height: 40)).fill()
    image.unlockFocus()
    let bitmap = NSBitmapImageRep(data: image.tiffRepresentation!)!
    let filename = "icon_\(base)x\(base)@\(scale)x.png"
    try bitmap.representation(using: .png, properties: [:])!.write(to: directory.appendingPathComponent(filename))
    entries.append(["idiom": "mac", "size": "\(base)x\(base)", "scale": "\(scale)x", "filename": filename])
}
let json: [String: Any] = ["images": entries, "info": ["author": "xcode", "version": 1]]
try JSONSerialization.data(withJSONObject: json, options: [.prettyPrinted, .sortedKeys]).write(to: directory.appendingPathComponent("Contents.json"))
print("Generated 10 native app icon sizes")
