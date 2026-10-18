// Bubble shape and content rendering. Geometry follows the original widget's SVG
// (1026 × 700 canvas): main ellipse, tail, two small "thought" bubbles, stroke #203170.
import AppKit
import SwiftUI

extension Color {
    init?(hexString: String) {
        var s = hexString.trimmingCharacters(in: .whitespaces)
        if s.hasPrefix("#") { s.removeFirst() }
        if s.count == 3 { s = s.map { "\($0)\($0)" }.joined() }
        guard s.count == 6, let v = UInt32(s, radix: 16) else { return nil }
        self.init(.sRGB, red: Double((v >> 16) & 0xFF) / 255, green: Double((v >> 8) & 0xFF) / 255,
                  blue: Double(v & 0xFF) / 255, opacity: 1)
    }
    static let bubbleInk = Color(.sRGB, red: 0x53 / 255.0, green: 0x6b / 255.0, blue: 0xa9 / 255.0, opacity: 1)
    static let bubbleStroke = Color(.sRGB, red: 0x20 / 255.0, green: 0x31 / 255.0, blue: 0x70 / 255.0, opacity: 1)

    var hexString: String {
        let c = NSColor(self).usingColorSpace(.sRGB) ?? .black
        return String(format: "#%02x%02x%02x", Int(c.redComponent * 255), Int(c.greenComponent * 255), Int(c.blueComponent * 255))
    }
}

struct BubbleShapeView: View {
    var u: CGFloat
    var body: some View {
        Canvas { ctx, _ in
            let s = u
            func ell(_ cx: CGFloat, _ cy: CGFloat, _ rx: CGFloat, _ ry: CGFloat) -> Path {
                Path(ellipseIn: CGRect(x: (cx - rx) * s, y: (cy - ry) * s, width: rx * 2 * s, height: ry * 2 * s))
            }
            let main = ell(454, 247, 373, 232)
            var tail = Path()
            tail.addEllipse(in: CGRect(x: -62 * s, y: -26 * s, width: 124 * s, height: 52 * s))
            tail = tail.applying(CGAffineTransform(rotationAngle: .pi / 18).concatenating(CGAffineTransform(translationX: 356 * s, y: 462 * s)))
            let b1 = ell(352, 561, 37.5, 26)
            let b2 = ell(442, 646, 24.5, 18)
            let stroke = StrokeStyle(lineWidth: 36 * s, lineJoin: .round)
            // Stroke twice as wide, then fill on top: the union keeps an 18u outline.
            ctx.stroke(main, with: .color(.bubbleStroke), style: stroke)
            ctx.stroke(tail, with: .color(.bubbleStroke), style: stroke)
            ctx.fill(main, with: .color(.white))
            ctx.fill(tail, with: .color(.white))
            for b in [b1, b2] {
                ctx.stroke(b, with: .color(.bubbleStroke), style: StrokeStyle(lineWidth: 18 * s))
                ctx.fill(b, with: .color(.white))
            }
        }
        .frame(width: 1026 * u, height: 700 * u)
    }
}

/// Animated "marquee" gradient fill for text or backgrounds.
struct MarqueeGradient: View {
    var preset: String
    var period: Double = 3
    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30)) { tl in
            let colors = (Gradients.colors(preset) ?? Gradients.colors("macaron")!).map {
                Color(.sRGB, red: $0.0 / 255, green: $0.1 / 255, blue: $0.2 / 255, opacity: 1)
            }
            let phase = CGFloat(tl.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: period) / period)
            LinearGradient(colors: colors + colors.dropFirst(), startPoint: UnitPoint(x: -phase, y: 0.5),
                           endPoint: UnitPoint(x: 2 - phase, y: 0.5))
        }
    }
}

struct StyledText: View {
    var text: String
    var size: Int
    var bold: Bool
    var italic: Bool = false
    var underline: Bool = false
    var color: String = ""
    var rgb: String = ""
    var bg: String = ""
    var bgRgb: String = ""
    var font: String = ""
    var u: CGFloat

    static func px(_ level: Int, _ u: CGFloat) -> CGFloat {
        let n = CGFloat(max(1, min(50, level)))
        return (40 + (n - 1) * 200 / 49) * u
    }

    var body: some View {
        let px = Self.px(size, u)
        var t = Text(text)
        let f: Font = font.isEmpty ? .system(size: px, weight: bold ? .heavy : .semibold, design: .rounded)
                                    : .custom(font, size: px).weight(bold ? .bold : .regular)
        t = t.font(f)
        if italic { t = t.italic() }
        if underline { t = t.underline() }
        let base = t.multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
        return Group {
            if !rgb.isEmpty {
                base.foregroundColor(.clear).overlay(MarqueeGradient(preset: rgb).mask(base))
            } else {
                base.foregroundColor(Color(hexString: color) ?? .bubbleInk)
            }
        }
        .padding(.horizontal, (bg.isEmpty && bgRgb.isEmpty) ? 0 : px * 0.35)
        .padding(.vertical, (bg.isEmpty && bgRgb.isEmpty) ? 0 : px * 0.08)
        .background(
            Group {
                if !bgRgb.isEmpty { MarqueeGradient(preset: bgRgb, period: 5) }
                else if let c = Color(hexString: bg) { c }
                else { Color.clear }
            }
            .clipShape(RoundedRectangle(cornerRadius: px * 0.35, style: .continuous))
        )
    }
}

/// Images: built-in whale-girl animations or user images (GIFs animate).
struct BubbleImage: View {
    var imgId: String
    var maxWidth: CGFloat
    var body: some View {
        if let anim = BuiltinImages.anim(imgId) {
            TimelineView(.animation(minimumInterval: 1.0 / 20)) { tl in
                let (r, c) = anim.frame(at: tl.date.timeIntervalSinceReferenceDate)
                if let img = Atlas.shared.image(r, c) {
                    Image(decorative: img, scale: 1).resizable().interpolation(.high)
                        .frame(width: maxWidth, height: maxWidth * 208 / 192)
                }
            }
        } else if let url = BuiltinImages.generatedURL(imgId), let ns = NSImage(contentsOf: url) {
            let ratio = ns.size.width > 0 ? ns.size.height / ns.size.width : 1
            Image(nsImage: ns).resizable().interpolation(.high).frame(width: maxWidth * 0.8, height: maxWidth * 0.8 * ratio)
        } else if let item = Gallery.list("images").first(where: { $0.id == imgId }),
                  let ns = NSImage(contentsOf: Gallery.url("images", item)) {
            let ratio = ns.size.width > 0 ? ns.size.height / ns.size.width : 1
            AnimatedImage(image: ns).frame(width: maxWidth, height: maxWidth * ratio)
        } else {
            Text("（图片缺失）").font(.system(size: maxWidth * 0.12)).foregroundColor(.gray)
        }
    }
}

struct AnimatedImage: NSViewRepresentable {
    var image: NSImage
    func makeNSView(context: Context) -> NSImageView {
        let v = NSImageView()
        v.imageScaling = .scaleProportionallyUpOrDown
        v.animates = true
        v.image = image
        v.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        v.setContentCompressionResistancePriority(.defaultLow, for: .vertical)
        return v
    }
    func updateNSView(_ v: NSImageView, context: Context) { if v.image !== image { v.image = image } }
}

struct ModuleView: View {
    @ObservedObject var model: AppModel
    var m: BubbleModule
    var u: CGFloat

    var body: some View {
        switch m.type {
        case .image:
            BubbleImage(imgId: m.imgId, maxWidth: 540 * u * CGFloat(max(0.1, min(1, m.imgScale))))
        case .randomImage:
            BubbleImage(imgId: model.pickedImages[m.id] ?? m.imgs.first?.imgId ?? "",
                        maxWidth: 540 * u * CGFloat(max(0.1, min(1, m.imgScale))))
        case .random:
            let idx = model.pickedLines[m.id] ?? 0
            if idx < m.lines.count {
                let l = m.lines[idx]
                StyledText(text: model.substitute(l.t, module: m), size: l.size ?? m.size, bold: l.bold ?? m.bold,
                           italic: l.italic ?? m.italic, underline: m.ul, color: l.color ?? m.color,
                           rgb: l.rgb ?? m.rgb, bg: m.bg, bgRgb: m.bgRgb, font: m.font, u: u)
            }
        case .link:
            StyledText(text: model.substitute(m.text, module: m), size: m.size, bold: m.bold, italic: m.italic,
                       underline: m.ul, color: m.color.isEmpty && m.rgb.isEmpty ? "#2f6fe0" : m.color, rgb: m.rgb,
                       bg: m.bg, bgRgb: m.bgRgb, font: m.font, u: u)
                .contentShape(Rectangle())
                .onTapGesture { if let url = URL(string: m.url), ["http", "https"].contains(url.scheme ?? "") { NSWorkspace.shared.open(url) } }
                .help(m.url)
        case .peak:
            let peak = Pricing.isPeak(model.now)
            let color = peak ? m.peakColor : m.offColor
            let rgb = peak ? m.peakRgb : m.offRgb
            let bgRgb = peak ? m.peakBgRgb : m.offBgRgb
            StyledText(text: model.substitute(m.tpl.isEmpty ? "{status}" : m.tpl, module: m), size: m.size, bold: m.bold,
                       italic: m.italic, underline: m.ul, color: color.isEmpty ? m.color : color,
                       rgb: rgb.isEmpty && color.isEmpty ? m.rgb : rgb, bg: m.bg, bgRgb: bgRgb.isEmpty ? m.bgRgb : bgRgb,
                       font: m.font, u: u)
        case .text:
            StyledText(text: model.substitute(m.text, module: m), size: m.size, bold: m.bold, italic: m.italic,
                       underline: m.ul, color: m.color, rgb: m.rgb, bg: m.bg, bgRgb: m.bgRgb, font: m.font, u: u)
        default:
            StyledText(text: model.substitute(m.tpl.isEmpty ? m.type.defaultTemplate : m.tpl, module: m), size: m.size,
                       bold: m.bold, italic: m.italic, underline: m.ul, color: m.color, rgb: m.rgb, bg: m.bg,
                       bgRgb: m.bgRgb, font: m.font, u: u)
        }
    }
}

/// Rows of modules; a module with joinPrev continues the previous row.
struct BubbleContent: View {
    @ObservedObject var model: AppModel
    var modules: [BubbleModule]
    var u: CGFloat

    static func rows(_ modules: [BubbleModule]) -> [[BubbleModule]] {
        var rows: [[BubbleModule]] = []
        for m in modules {
            if m.joinPrev, !m.type.isImage, var last = rows.popLast(), let prev = last.last, !prev.type.isImage, last.count < 6 {
                last.append(m); rows.append(last)
            } else {
                rows.append([m])
            }
        }
        return Array(rows.prefix(6))
    }

    var body: some View {
        VStack(spacing: 10 * u) {
            ForEach(Array(Self.rows(modules).enumerated()), id: \.offset) { _, row in
                HStack(alignment: .center, spacing: 14 * u) {
                    ForEach(row) { m in ModuleView(model: model, m: m, u: u) }
                }
            }
        }
    }
}

/// Shrinks its content to fit the given box (never enlarges). Single layout pass:
/// a hidden copy sets the natural size, the overlay reads it and draws a scaled copy.
struct FitInBox<Content: View>: View {
    var width: CGFloat
    var height: CGFloat
    @ViewBuilder var content: Content

    var body: some View {
        content.fixedSize().hidden()
            .overlay(GeometryReader { g in
                let k = min(1, width / max(1, g.size.width), height / max(1, g.size.height))
                content.fixedSize().scaleEffect(k).frame(width: g.size.width, height: g.size.height)
            })
            .frame(width: width, height: height)
    }
}

/// Bubble with content, in the widget's coordinate space (base = widget box width).
struct BubbleView: View {
    @ObservedObject var model: AppModel
    var modules: [BubbleModule]
    var base: CGFloat
    var mirrored: Bool

    var body: some View {
        let u = base / 1026
        ZStack(alignment: .topLeading) {
            BubbleShapeView(u: u)
            FitInBox(width: 540 * u, height: 320 * u) {
                BubbleContent(model: model, modules: modules, u: u)
                    .frame(maxWidth: 760 * u)
            }
            .scaleEffect(x: mirrored ? -1 : 1, y: 1)
            .position(x: 454 * u, y: 245 * u)
        }
        .frame(width: 1026 * u, height: 700 * u, alignment: .topLeading)
        .contentShape(Ellipse().path(in: CGRect(x: 81 * u, y: 15 * u, width: 746 * u, height: 464 * u)))
    }
}
