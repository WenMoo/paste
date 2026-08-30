import AppKit
import Foundation

let size: CGFloat = 1024
let image = NSImage(size: NSSize(width: size, height: size))
image.lockFocus()

let rect = NSRect(x: 0, y: 0, width: size, height: size)
let path = NSBezierPath(roundedRect: rect.insetBy(dx: 80, dy: 80), xRadius: 220, yRadius: 220)
let gradient = NSGradient(colors: [
    NSColor(calibratedRed: 0.33, green: 0.48, blue: 0.98, alpha: 1),
    NSColor(calibratedRed: 0.55, green: 0.30, blue: 0.98, alpha: 1),
])
gradient?.draw(in: path, angle: -70)

let card = NSBezierPath(roundedRect: NSRect(x: 300, y: 250, width: 424, height: 540), xRadius: 56, yRadius: 56)
NSColor.white.withAlphaComponent(0.96).setFill()
card.fill()

let clipTop = NSBezierPath(roundedRect: NSRect(x: 390, y: 700, width: 244, height: 90), xRadius: 28, yRadius: 28)
NSColor(calibratedRed: 0.45, green: 0.38, blue: 0.98, alpha: 1).setFill()
clipTop.fill()

let line1 = NSBezierPath(roundedRect: NSRect(x: 360, y: 540, width: 304, height: 28), xRadius: 10, yRadius: 10)
let line2 = NSBezierPath(roundedRect: NSRect(x: 360, y: 470, width: 240, height: 28), xRadius: 10, yRadius: 10)
let line3 = NSBezierPath(roundedRect: NSRect(x: 360, y: 400, width: 270, height: 28), xRadius: 10, yRadius: 10)
NSColor(calibratedRed: 0.33, green: 0.48, blue: 0.98, alpha: 0.35).setFill()
line1.fill()
line2.fill()
line3.fill()

image.unlockFocus()

let dest = URL(fileURLWithPath: CommandLine.arguments[1])
guard let tiff = image.tiffRepresentation,
      let rep = NSBitmapImageRep(data: tiff),
      let png = rep.representation(using: .png, properties: [:]) else {
    fatalError("icon render failed")
}
try png.write(to: dest)
print("wrote \(dest.path)")
