import AppKit

// ── Format ───────────────────────────────────────────────────────────────────
let W = 880.0, H = 420.0, S = 2.0        // S = suréchantillonnage
let FPS = 20.0, DUR = 6.0
let NFRAMES = Int(FPS * DUR)
let outDir = CommandLine.arguments[1]

// ── Palette ──────────────────────────────────────────────────────────────────
func rgb(_ r: Int, _ g: Int, _ b: Int, _ a: Double = 1) -> NSColor {
    NSColor(srgbRed: Double(r)/255, green: Double(g)/255, blue: Double(b)/255, alpha: a)
}
let BG      = rgb(0x15, 0x16, 0x1A)
let BLUE    = rgb(0x3B, 0x82, 0xF6)
let ORANGE  = rgb(0xF5, 0x9E, 0x0B)
let RED     = rgb(0xEF, 0x44, 0x44)
let TEXT    = rgb(0xF5, 0xF6, 0xF8)
let DIM     = rgb(0x8B, 0x92, 0x9E)
let FAINT   = rgb(0x2A, 0x2D, 0x35)

// ── Interpolations ───────────────────────────────────────────────────────────
func clamp(_ x: Double, _ a: Double = 0, _ b: Double = 1) -> Double { min(max(x, a), b) }
func lerp(_ a: Double, _ b: Double, _ t: Double) -> Double { a + (b - a) * t }
/// Progression normalisée à l'intérieur d'un segment temporel.
func seg(_ t: Double, _ from: Double, _ to: Double) -> Double { clamp((t - from) / (to - from)) }
func easeInOut(_ x: Double) -> Double {
    x < 0.5 ? 4*x*x*x : 1 - pow(-2*x + 2, 3)/2
}
func easeOut(_ x: Double) -> Double { 1 - pow(1 - x, 3) }
func mixColor(_ a: NSColor, _ b: NSColor, _ t: Double) -> NSColor {
    let t = clamp(t)
    return NSColor(srgbRed: lerp(a.redComponent, b.redComponent, t),
                   green:   lerp(a.greenComponent, b.greenComponent, t),
                   blue:    lerp(a.blueComponent, b.blueComponent, t),
                   alpha:   lerp(a.alphaComponent, b.alphaComponent, t))
}
/// Le chemin direct entre bleu et orange traverse un gris qui eteint la jauge ;
/// passer par la teinte la fait virer au magenta, hors charte. On traverse donc
/// le blanc : sur une bande etroite, la bascule se lit comme un eclat, et le
/// changement de couleur devient un evenement plutot qu'un degrade.
func flashMix(_ a: NSColor, _ b: NSColor, _ k: Double) -> NSColor {
    let k = clamp(k)
    return k < 0.5 ? mixColor(a, TEXT, k * 2) : mixColor(TEXT, b, (k - 0.5) * 2)
}

func severityColor(_ ratio: Double) -> NSColor {
    if ratio < 0.785 { return BLUE }
    if ratio < 0.845 { return flashMix(BLUE, ORANGE, (ratio - 0.785) / 0.06) }
    return mixColor(ORANGE, RED, clamp((ratio - 0.86) / 0.06))
}

// ── Texte ────────────────────────────────────────────────────────────────────
func font(_ size: Double, _ w: NSFont.Weight = .regular, mono: Bool = false) -> NSFont {
    mono ? NSFont.monospacedDigitSystemFont(ofSize: size, weight: w)
         : NSFont.systemFont(ofSize: size, weight: w)
}
enum Align { case left, right, center }
func draw(_ s: String, x: Double, y: Double, _ f: NSFont, _ c: NSColor,
          _ align: Align = .left, alpha: Double = 1) {
    guard alpha > 0.003 else { return }
    let at = NSAttributedString(string: s, attributes: [
        .font: f, .foregroundColor: c.withAlphaComponent(c.alphaComponent * alpha)])
    let sz = at.size()
    var px = x
    if align == .right  { px = x - sz.width }
    if align == .center { px = x - sz.width/2 }
    at.draw(at: NSPoint(x: px, y: y))
}

// ── Formes ───────────────────────────────────────────────────────────────────
func roundedRect(_ r: NSRect, _ radius: Double, _ c: NSColor, alpha: Double = 1) {
    guard alpha > 0.003 else { return }
    let p = NSBezierPath(roundedRect: r, xRadius: radius, yRadius: radius)
    c.withAlphaComponent(c.alphaComponent * alpha).setFill()
    p.fill()
}
func arc(center: NSPoint, radius: Double, width: Double,
         from: Double, to: Double, _ c: NSColor, alpha: Double = 1, round: Bool = true) {
    guard alpha > 0.003, abs(to - from) > 0.2 else { return }
    let p = NSBezierPath()
    p.appendArc(withCenter: center, radius: radius, startAngle: from, endAngle: to, clockwise: true)
    p.lineWidth = width
    if round { p.lineCapStyle = .round }
    c.withAlphaComponent(c.alphaComponent * alpha).setStroke()
    p.stroke()
}

// ── Contenu ──────────────────────────────────────────────────────────────────
struct Row { let name: String; let size: Double; let culprit: Bool }
let rows = [
    Row(name: "Developer/CoreSimulator", size: 46, culprit: true),
    Row(name: "node_modules · 26 projets", size: 31, culprit: false),
    Row(name: "~/.cache",                 size: 24, culprit: false),
    Row(name: "/var/folders",             size: 14, culprit: false),
    Row(name: "Docker",                   size: 13, culprit: false),
]
let maxSize = 46.0

// ── Une image ────────────────────────────────────────────────────────────────
func render(_ t: Double) -> NSBitmapImageRep {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil,
        pixelsWide: Int(W*S), pixelsHigh: Int(H*S), bitsPerSample: 8,
        samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    let ctx = NSGraphicsContext(bitmapImageRep: rep)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = ctx
    ctx.cgContext.scaleBy(x: S, y: S)
    ctx.cgContext.setAllowsAntialiasing(true)

    BG.setFill(); NSRect(x: 0, y: 0, width: W, height: H).fill()

    // Ouverture et fermeture en fondu, pour que la boucle ne claque pas.
    let fadeIn  = easeOut(seg(t, 0.00, 0.55))
    let fadeOut = 1 - easeInOut(seg(t, 5.70, 6.00))
    let A = fadeIn * fadeOut

    // Phases
    let fill    = easeInOut(seg(t, 0.55, 3.00))   // le disque se remplit
    let alert   = easeOut(seg(t, 3.00, 3.55))     // l'alerte arrive
    let clean   = easeInOut(seg(t, 3.95, 4.95))   // le nettoyage
    let chipOut = easeInOut(seg(t, 5.05, 5.45))

    let ratio  = lerp(lerp(0.42, 0.885, fill), 0.46, clean)
    let freeGo = lerp(lerp(520, 112, fill), 498, clean)
    let color  = severityColor(ratio)

    // ── Signature ────────────────────────────────────────────────────────────
    let markY = 364.0
    let ringMark = NSPoint(x: 70, y: markY + 8)
    arc(center: ringMark, radius: 11, width: 4.2, from: 90, to: -190, BLUE, alpha: A, round: true)
    draw("DiskWatch", x: 92, y: markY, font(19, .semibold), TEXT, .left, alpha: A)
    draw("surveille ce que les agents laissent derrière eux",
         x: 92, y: markY - 19, font(12.5), DIM, .left, alpha: A * 0.95)

    // ── Jauge ────────────────────────────────────────────────────────────────
    let c = NSPoint(x: 152, y: 176)
    let R = 76.0, LW = 17.0
    arc(center: c, radius: R, width: LW, from: 0, to: -359.9, FAINT, alpha: A, round: false)
    arc(center: c, radius: R, width: LW, from: 90, to: 90 - 360*ratio, color, alpha: A)

    // Halo quand ça devient critique
    if ratio > 0.80 {
        let pulse = 0.5 + 0.5*sin(t*6.5)
        let g = clamp((ratio - 0.80)/0.09) * (0.18 + 0.12*pulse) * (1 - clean)
        arc(center: c, radius: R, width: LW + 13, from: 90, to: 90 - 360*ratio, color, alpha: A*g, round: true)
    }

    draw("\(Int(ratio*100).description) %", x: c.x, y: c.y - 11,
         font(23, .semibold, mono: true), TEXT, .center, alpha: A)
    draw("occupé", x: c.x, y: c.y - 31, font(11), DIM, .center, alpha: A * 0.9)

    // ── Chiffres ─────────────────────────────────────────────────────────────
    let tx = 262.0
    draw("\(Int(freeGo.rounded())) Go", x: tx, y: 186,
         font(46, .semibold, mono: true), TEXT, .left, alpha: A)
    draw("libres sur 995 Go", x: tx, y: 160, font(14), DIM, .left, alpha: A)

    let verdict = ratio > 0.86 ? "Espace critique" : (ratio > 0.70 ? "Espace à surveiller" : "Espace confortable")
    draw(verdict, x: tx, y: 134, font(13, .medium), color, .left, alpha: A)

    // ── Dossiers ─────────────────────────────────────────────────────────────
    let rx = 486.0, rw = 338.0
    var y = 300.0
    for (i, row) in rows.enumerated() {
        let delay = 0.58 + Double(i) * 0.22
        let grow  = easeOut(seg(t, delay, delay + 0.80))
        // Le fautif part en dernier : l'oeil suit l'alerte, puis sa resolution.
        let shrink = row.culprit
            ? lerp(1.0, 0.22, easeInOut(seg(t, 4.25, 5.15)))
            : lerp(1.0, 0.34, clean)
        let w = rw * (row.size / maxSize) * grow * shrink

        let isHot = row.culprit && alert > 0
        let bar = isHot ? mixColor(BLUE, ORANGE, alert) : BLUE

        draw(row.name, x: rx, y: y + 9, font(12.5, isHot ? .semibold : .regular),
             isHot ? mixColor(TEXT, ORANGE, alert*0.8) : TEXT, .left, alpha: A * grow)
        draw("\(Int(row.size * shrink)) Go", x: rx + rw, y: y + 9,
             font(12.5, .medium, mono: true), DIM, .right, alpha: A * grow)

        roundedRect(NSRect(x: rx, y: y, width: rw, height: 4), 2, FAINT, alpha: A * grow)
        roundedRect(NSRect(x: rx, y: y, width: max(4, w), height: 4), 2, bar, alpha: A * grow)
        y -= 40
    }

    // ── Bandeau d'alerte ─────────────────────────────────────────────────────
    let chipA = A * alert * (1 - chipOut)
    if chipA > 0.004 {
        let slide = (1 - alert) * 26
        let r = NSRect(x: rx + slide, y: 62, width: rw, height: 54)
        roundedRect(r, 13, ORANGE.withAlphaComponent(0.14), alpha: chipA)
        roundedRect(NSRect(x: r.minX, y: r.minY, width: 3.5, height: r.height), 2, ORANGE, alpha: chipA)
        draw("Developer/CoreSimulator", x: r.minX + 18, y: r.minY + 30,
             font(13, .semibold), TEXT, .left, alpha: chipA)
        draw("+6,9 Go depuis la dernière mesure", x: r.minX + 18, y: r.minY + 12,
             font(12), ORANGE, .left, alpha: chipA)
        let pulse = 1 + 0.07*sin(t*9)
        arc(center: NSPoint(x: r.maxX - 28, y: r.midY), radius: 9*pulse, width: 2.4,
            from: 0, to: -359.9, ORANGE, alpha: chipA, round: false)
        draw("!", x: r.maxX - 28, y: r.midY - 7, font(12, .bold), ORANGE, .center, alpha: chipA)
    }

    NSGraphicsContext.restoreGraphicsState()
    return rep
}

// ── Rendu ────────────────────────────────────────────────────────────────────
for i in 0..<NFRAMES {
    let rep = render(Double(i) / FPS)
    let png = rep.representation(using: .png, properties: [:])!
    let name = String(format: "%s/f%03d.png", (outDir as NSString).utf8String!, i)
    try! png.write(to: URL(fileURLWithPath: name))
}
print("\(NFRAMES) images rendues dans \(outDir)")
