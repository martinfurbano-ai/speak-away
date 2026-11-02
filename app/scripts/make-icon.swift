// Draws the Speak Away icon (1024 px PNG): dark tile, white voice bars, red recording dot.
// Usage: swift make-icon.swift out.png
import AppKit

let size: CGFloat = 1024
let image = NSImage(size: NSSize(width: size, height: size))
image.lockFocus()
let ctx = NSGraphicsContext.current!.cgContext

// macOS icon grid: 824 px tile centred on a 1024 canvas.
let tile = CGRect(x: 100, y: 100, width: 824, height: 824)
let path = CGPath(roundedRect: tile, cornerWidth: 186, cornerHeight: 186, transform: nil)
ctx.saveGState()
ctx.setShadow(offset: CGSize(width: 0, height: -12), blur: 28, color: NSColor.black.withAlphaComponent(0.35).cgColor)
ctx.addPath(path)
ctx.setFillColor(NSColor(red: 0.08, green: 0.085, blue: 0.095, alpha: 1).cgColor)
ctx.fillPath()
ctx.restoreGState()

ctx.saveGState()
ctx.addPath(path)
ctx.clip()
let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                          colors: [NSColor(white: 0.17, alpha: 1).cgColor, NSColor(white: 0.055, alpha: 1).cgColor] as CFArray,
                          locations: [0, 1])!
ctx.drawLinearGradient(gradient, start: CGPoint(x: 0, y: 924), end: CGPoint(x: 0, y: 100), options: [])
ctx.restoreGState()

// Voice bars.
let heights: [CGFloat] = [150, 300, 430, 250, 360, 190, 110]
let barWidth: CGFloat = 52, gap: CGFloat = 34
let total = CGFloat(heights.count) * barWidth + CGFloat(heights.count - 1) * gap
var x = (size - total) / 2
ctx.setFillColor(NSColor(white: 0.96, alpha: 1).cgColor)
for h in heights {
    let bar = CGRect(x: x, y: size / 2 - h / 2, width: barWidth, height: h)
    ctx.addPath(CGPath(roundedRect: bar, cornerWidth: barWidth / 2, cornerHeight: barWidth / 2, transform: nil))
    ctx.fillPath()
    x += barWidth + gap
}

// Recording dot.
ctx.setFillColor(NSColor(red: 0.90, green: 0.28, blue: 0.30, alpha: 1).cgColor)
ctx.fillEllipse(in: CGRect(x: 724, y: 724, width: 92, height: 92))

image.unlockFocus()
let rep = NSBitmapImageRep(data: image.tiffRepresentation!)!
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
