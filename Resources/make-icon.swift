// Fabrique l'icone de l'application : une jauge annulaire sur fond degrade,
// le meme signe que dans la barre de menus. Rendu en 1024 px, puis iconutil.
import AppKit

let size: CGFloat = 1024
let img = NSImage(size: NSSize(width: size, height: size))
img.lockFocus()
guard let ctx = NSGraphicsContext.current?.cgContext else { exit(1) }

// Fond : squircle approxime par un rectangle arrondi au rayon d'Apple (22,37 %).
let inset: CGFloat = size * 0.085
let rect = NSRect(x: inset, y: inset, width: size - inset*2, height: size - inset*2)
let radius = rect.width * 0.2237
let shape = NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)

ctx.saveGState()
shape.addClip()
let bg = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                    colors: [NSColor(srgbRed: 0.27, green: 0.55, blue: 1.00, alpha: 1).cgColor,
                             NSColor(srgbRed: 0.09, green: 0.32, blue: 0.85, alpha: 1).cgColor] as CFArray,
                    locations: [0, 1])!
ctx.drawLinearGradient(bg, start: CGPoint(x: 0, y: size), end: CGPoint(x: size, y: 0), options: [])
ctx.restoreGState()

// Jauge : arc de 78 %, comme un disque bien rempli.
let center = NSPoint(x: size/2, y: size/2)
let ringRadius = size * 0.255
let line = size * 0.105

let track = NSBezierPath()
track.appendArc(withCenter: center, radius: ringRadius, startAngle: 0, endAngle: 360)
track.lineWidth = line
NSColor(white: 1, alpha: 0.22).setStroke()
track.stroke()

let gauge = NSBezierPath()
gauge.appendArc(withCenter: center, radius: ringRadius,
                startAngle: 90, endAngle: 90 - 360 * 0.78, clockwise: true)
gauge.lineWidth = line
gauge.lineCapStyle = .round
NSColor.white.setStroke()
gauge.stroke()

// Point central : le repere de lecture.
let dot = NSBezierPath(ovalIn: NSRect(x: center.x - size*0.052, y: center.y - size*0.052,
                                      width: size*0.104, height: size*0.104))
NSColor(white: 1, alpha: 0.92).setFill()
dot.fill()

img.unlockFocus()

guard let tiff = img.tiffRepresentation,
      let rep = NSBitmapImageRep(data: tiff),
      let png = rep.representation(using: .png, properties: [:]) else { exit(1) }
try! png.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
