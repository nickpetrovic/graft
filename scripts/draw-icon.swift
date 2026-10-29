import AppKit

let output = URL(fileURLWithPath: CommandLine.arguments[1])
let size = 1024.0
let center = NSPoint(x: size / 2, y: size / 2)

func color(_ hex: UInt32, _ alpha: Double = 1) -> NSColor {
    NSColor(srgbRed: Double((hex >> 16) & 0xff) / 255, green: Double((hex >> 8) & 0xff) / 255,
            blue: Double(hex & 0xff) / 255, alpha: alpha)
}

let basaltTop = color(0x2B3A36)
let basaltBottom = color(0x121918)
let jade = color(0x4FE6B8)

func plate(centerY: Double, width: Double, depth: Double) -> NSBezierPath {
    let path = NSBezierPath()
    path.move(to: NSPoint(x: center.x, y: centerY + depth / 2))
    path.line(to: NSPoint(x: center.x + width / 2, y: centerY))
    path.line(to: NSPoint(x: center.x, y: centerY - depth / 2))
    path.line(to: NSPoint(x: center.x - width / 2, y: centerY))
    path.close()
    path.lineJoinStyle = .round
    return path
}

let image = NSImage(size: NSSize(width: size, height: size))
image.lockFocus()
guard let context = NSGraphicsContext.current else { exit(1) }

let inset = 100.0
let tile = NSBezierPath(roundedRect: NSRect(x: inset, y: inset, width: size - 2 * inset, height: size - 2 * inset),
                        xRadius: 185, yRadius: 185)

context.saveGraphicsState()
let dropShadow = NSShadow()
dropShadow.shadowColor = NSColor.black.withAlphaComponent(0.45)
dropShadow.shadowBlurRadius = 28
dropShadow.shadowOffset = NSSize(width: 0, height: -12)
dropShadow.set()
NSGradient(starting: basaltTop, ending: basaltBottom)!.draw(in: tile, angle: -90)
context.restoreGraphicsState()

context.saveGraphicsState()
tile.addClip()
let ring = NSBezierPath(ovalIn: NSRect(x: center.x - 300, y: center.y - 300, width: 600, height: 600))
ring.lineWidth = 10
jade.withAlphaComponent(0.10).setStroke()
ring.stroke()
let innerRing = NSBezierPath(ovalIn: NSRect(x: center.x - 248, y: center.y - 248, width: 496, height: 496))
innerRing.lineWidth = 4
jade.withAlphaComponent(0.07).setStroke()
innerRing.stroke()
context.restoreGraphicsState()

let width = 470.0
let depth = 272.0
let step = 92.0

let bottom = plate(centerY: center.y - step - 16, width: width, depth: depth)
bottom.lineWidth = 18
jade.withAlphaComponent(0.28).setStroke()
bottom.stroke()

let middle = plate(centerY: center.y - 16, width: width, depth: depth)
basaltBottom.setFill()
middle.fill()
middle.lineWidth = 18
jade.withAlphaComponent(0.55).setStroke()
middle.stroke()

let top = plate(centerY: center.y + step - 16, width: width, depth: depth)
context.saveGraphicsState()
let glow = NSShadow()
glow.shadowColor = jade.withAlphaComponent(0.85)
glow.shadowBlurRadius = 60
glow.shadowOffset = .zero
glow.set()
jade.setFill()
top.fill()
context.restoreGraphicsState()
NSGradient(starting: color(0x8FF5D6), ending: jade)!.draw(in: top, angle: -90)

image.unlockFocus()

guard let tiff = image.tiffRepresentation, let bitmap = NSBitmapImageRep(data: tiff),
      let png = bitmap.representation(using: .png, properties: [:]) else { exit(1) }
try png.write(to: output)
