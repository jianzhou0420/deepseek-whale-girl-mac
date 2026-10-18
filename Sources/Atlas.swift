// Whale-girl sprite atlas: the MIT-licensed deepseek-girl animation set by f0909172434.
// Shared with the WhaleGirl desktop pet.
import CoreGraphics
import Foundation
import ImageIO

// MARK: - Atlas: 8 columns × 11 rows, each cell 192×208 px
// Rows: 0 idle (0-5 holding the sign, 6 neutral)  1 run right  2 run left  3 wave  4 jump
//       5 failed (0-3 crying, 4-5 hugging knees, 6-7 sulking)
//       6 waiting  7 working  8 thinking  9-10 look in 16 directions (0° = up, clockwise, 22.5° per cell)
final class Atlas {
    static let shared = Atlas()
    static let cellW = 192, cellH = 208

    /// Cleans up a frame: drops small detached fragments, and fades out edges where the
    /// source art was cut off in a straight vertical line.
    static func removeStrays(_ img: CGImage) -> CGImage {
        let w = img.width, h = img.height
        guard let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
                                  space: CGColorSpaceCreateDeviceRGB(),
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue),
              let data = ctx.data else { return img }
        ctx.draw(img, in: CGRect(x: 0, y: 0, width: w, height: h))
        let px = data.bindMemory(to: UInt8.self, capacity: w * h * 4)
        // 1) Connected components: remove small pieces not attached to the body
        var label = [Int32](repeating: 0, count: w * h)
        var sizes: [Int] = [0]
        var stack: [Int] = []
        for start in 0..<(w * h) where label[start] == 0 && px[start * 4 + 3] > 8 {
            let id = Int32(sizes.count); var n = 0
            label[start] = id; stack.append(start)
            while let i = stack.popLast() {
                n += 1
                let x = i % w, y = i / w
                for dy in -1...1 { for dx in -1...1 {
                    let nx = x + dx, ny = y + dy
                    guard nx >= 0, ny >= 0, nx < w, ny < h else { continue }
                    let j = ny * w + nx
                    if label[j] == 0 && px[j * 4 + 3] > 8 { label[j] = id; stack.append(j) }
                }}
            }
            sizes.append(n)
        }
        let biggest = sizes.max() ?? 0
        for i in 0..<(w * h) where label[i] > 0 && sizes[Int(label[i])] < biggest / 6 {
            px[i * 4] = 0; px[i * 4 + 1] = 0; px[i * 4 + 2] = 0; px[i * 4 + 3] = 0
        }
        // 2) Feather hard-cut edges
        var colCount = [Int](repeating: 0, count: w)
        for y in 0..<h { for x in 0..<w where px[(y * w + x) * 4 + 3] > 24 { colCount[x] += 1 } }
        let filled = colCount.indices.filter { colCount[$0] > 0 }
        guard let left = filled.first, let right = filled.last else { return img }
        let fade = 16
        func feather(from edge: Int, step: Int) {
            for k in 0..<fade {
                let x = edge + k * step
                guard x >= 0 && x < w else { continue }
                let f = Double(k + 1) / Double(fade + 1)
                for y in 0..<h {
                    let i = (y * w + x) * 4
                    for ch in 0..<4 { px[i + ch] = UInt8(Double(px[i + ch]) * f) }
                }
            }
        }
        if colCount[left] > 40 { feather(from: left, step: 1) }
        if colCount[right] > 40 { feather(from: right, step: -1) }
        return ctx.makeImage() ?? img
    }
    var frames: [[CGImage?]] = Array(repeating: Array(repeating: nil, count: 8), count: 11)

    init() {
        let candidates = [
            Bundle.main.url(forResource: "spritesheet", withExtension: "webp"),
            URL(fileURLWithPath: CommandLine.arguments[0]).deletingLastPathComponent().appendingPathComponent("assets/spritesheet.webp"),
            URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent("assets/spritesheet.webp"),
        ].compactMap { $0 }
        guard let url = candidates.first(where: { FileManager.default.fileExists(atPath: $0.path) }),
              let src = CGImageSourceCreateWithURL(url as CFURL, nil),
              let sheet = CGImageSourceCreateImageAtIndex(src, 0, nil) else {
            NSLog("WhaleSeek: spritesheet.webp not found")
            return
        }
        for r in 0..<11 {
            for c in 0..<8 {
                if let cell = sheet.cropping(to: CGRect(x: c * Atlas.cellW, y: r * Atlas.cellH,
                                                         width: Atlas.cellW, height: Atlas.cellH)) {
                    frames[r][c] = Atlas.removeStrays(cell)
                }
            }
        }
    }
    func image(_ row: Int, _ col: Int) -> CGImage? { frames[row][col] }
}

struct Anim {
    let row: Int
    let cols: [Int]
    let fps: Double
    func frame(at t: Double) -> (Int, Int) { (row, cols[Int(t * fps) % cols.count]) }

    static let neutral   = Anim(row: 0, cols: [6], fps: 1)
    static let board     = Anim(row: 0, cols: [0, 1, 2, 3, 4, 5], fps: 5)
    static let runRight  = Anim(row: 1, cols: Array(0...7), fps: 10)
    static let runLeft   = Anim(row: 2, cols: Array(0...7), fps: 10)
    static let wave      = Anim(row: 3, cols: [0, 1, 2, 3], fps: 6)
    static let jump      = Anim(row: 4, cols: [0, 1, 2, 3, 4], fps: 8)
    static let panic     = Anim(row: 5, cols: [0, 1, 2, 3], fps: 6)
    static let sleep     = Anim(row: 8, cols: [3], fps: 1)   // eyes-closed frame (the knee-hugging frames are clipped in the source)
    static let sulk      = Anim(row: 5, cols: [6, 7], fps: 3)
    static let cheer     = Anim(row: 6, cols: [0, 1, 2, 3, 4, 5], fps: 6)
    static let work      = Anim(row: 7, cols: [0, 1, 2, 3, 4, 5], fps: 6)
    static let think     = Anim(row: 8, cols: [0, 1, 2, 3, 4, 5], fps: 4)
}

