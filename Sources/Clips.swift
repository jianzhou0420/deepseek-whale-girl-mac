// AI-generated frame animations ("clips") from the art pipeline (art-pipeline/anims.json → assets/anims).
// Each clip is drawn scaled and positioned so her feet and height match the atlas character.
import CoreGraphics
import Foundation
import ImageIO

struct Clip {
    var id: String
    var name: String
    var fps: Double
    var frames: [CGImage]
    /// Atlas-cell pixels per clip-frame pixel.
    var scale: CGFloat
    /// Feet point (bottom center of the figure) in clip-frame pixels, top-left origin.
    var feet: CGPoint
    /// Rightmost opaque pixel over all frames, in clip-frame pixels (the widget sits at the window's right edge).
    var right: CGFloat
    var lines: [String] = []

    var loopSeconds: Double { Double(frames.count) / fps }
    func frame(at t: Double) -> CGImage { frames[Int(max(0, t) * fps) % frames.count] }
}

/// Bounding box of pixels with alpha above a threshold (top-left origin).
func alphaBounds(_ img: CGImage, threshold: UInt8 = 40) -> CGRect? {
    let w = img.width, h = img.height
    guard let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
                              space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue),
          let data = ctx.data else { return nil }
    ctx.draw(img, in: CGRect(x: 0, y: 0, width: w, height: h))
    let px = data.bindMemory(to: UInt8.self, capacity: w * h * 4)
    var x0 = w, y0 = h, x1 = -1, y1 = -1
    for y in 0..<h { for x in 0..<w where px[(y * w + x) * 4 + 3] > threshold {
        x0 = min(x0, x); x1 = max(x1, x); y0 = min(y0, y); y1 = max(y1, y)
    } }
    return x1 < 0 ? nil : CGRect(x: x0, y: y0, width: x1 - x0 + 1, height: y1 - y0 + 1)
}

final class Clips {
    static let shared = Clips()
    private(set) var list: [Clip] = []
    /// Feet point and figure height of the neutral atlas frame, in atlas-cell pixels.
    private(set) var atlasFeet = CGPoint(x: 96, y: 200)

    struct Entry: Codable { var id: String; var name: String; var fps: Double; var frames: Int; var heightRatio: Double?; var lines: [String]? }

    init() {
        let dirs = [
            Bundle.main.resourceURL?.appendingPathComponent("anims"),
            URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent("assets/anims"),
        ].compactMap { $0 }
        guard let dir = dirs.first(where: { FileManager.default.fileExists(atPath: $0.appendingPathComponent("anims.json").path) }),
              let data = try? Data(contentsOf: dir.appendingPathComponent("anims.json")),
              let entries = try? JSONDecoder().decode([Entry].self, from: data) else { return }

        var atlasHeight: CGFloat = 180
        if let n = Atlas.shared.image(0, 6), let b = alphaBounds(n) {
            atlasHeight = b.height
            atlasFeet = CGPoint(x: b.midX, y: b.maxY)
        }
        for e in entries {
            let frames = (0..<e.frames).compactMap { k -> CGImage? in
                let u = dir.appendingPathComponent(e.id).appendingPathComponent("\(k).png")
                guard let src = CGImageSourceCreateWithURL(u as CFURL, nil) else { return nil }
                return CGImageSourceCreateImageAtIndex(src, 0, nil)
            }
            // Calibrate on the tallest frame: same figure height as the atlas character (scaled for sitting poses).
            // Frames share one canvas with the feet centered, so the feet point comes from the first frame.
            let bounds = frames.compactMap { alphaBounds($0) }
            guard frames.count == e.frames, bounds.count == frames.count, let f0 = frames.first,
                  let tallest = bounds.map(\.height).max() else { continue }
            let target = atlasHeight * CGFloat(e.heightRatio ?? 1)
            list.append(Clip(id: e.id, name: e.name, fps: e.fps, frames: frames, scale: target / tallest,
                             feet: CGPoint(x: CGFloat(f0.width) / 2, y: bounds[0].maxY),
                             right: bounds.map(\.maxX).max() ?? CGFloat(f0.width), lines: e.lines ?? []))
        }
    }

    func clip(_ id: String) -> Clip? { list.first { $0.id == id } }
}
