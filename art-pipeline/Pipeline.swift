// Art asset pipeline: generate character images with Codex CLI (ChatGPT plan, built-in image
// generation), key out the background, clean up, run quality checks, install into the app.
//
//   ./art.sh all [--jobs N]      generate missing images (N at a time), process, retry failures, install, preview
//   ./art.sh generate [ids…]     generate (or with --force, regenerate) raw images
//   ./art.sh process [ids…]      key out background + QA for raw images
//   ./art.sh install             copy passing images into assets/generated + manifest
//   ./art.sh preview             contact sheet of processed images on a checkerboard
//   ./art.sh anim [ids…]         sprite-sheet animations from anims.json: generate, split frames, align, QA, HTML preview
//   ./art.sh anim-process / anim-preview / anim-install / anim-gif (README GIF in docs/)
import AppKit
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

// MARK: - Manifest

struct AssetSpec: Codable { var id: String; var name: String; var pose: String; var allowEdges: [String]? }
struct Manifest: Codable { var character: String; var style: String; var background: String; var assets: [AssetSpec] }

struct QAResult: Codable {
    var id: String
    var pass: Bool
    var problems: [String]
    var width: Int
    var height: Int
    var coverage: Double      // opaque fraction of the trimmed image
    var residue: Double       // fraction of opaque pixels that still look like the key color
    var edgeTouch: [String]   // sides where the character touches the raw image border
    var fragmentsRemoved: Int
}

let root = URL(fileURLWithPath: CommandLine.arguments[0]).deletingLastPathComponent().deletingLastPathComponent()
let base = FileManager.default.fileExists(atPath: root.appendingPathComponent("assets.json").path)
    ? root : URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
func path(_ p: String) -> URL { base.appendingPathComponent(p) }
for d in ["raw", "processed", "logs"] { try? FileManager.default.createDirectory(at: path(d), withIntermediateDirectories: true) }

func loadManifest() -> Manifest {
    guard let data = try? Data(contentsOf: path("assets.json")),
          let m = try? JSONDecoder().decode(Manifest.self, from: data) else { fatalError("assets.json missing or invalid") }
    return m
}

// MARK: - Generation via Codex CLI

func generate(_ a: AssetSpec, _ m: Manifest, attempt: Int, allowFallback: Bool = true) -> Bool {
    let prompt = """
    Use your built-in image generation tool to create exactly ONE new image, then save that image file \
    into the current directory as \(a.id).png and reply with just the file name. Do not edit or create any other files.
    Character: \(m.character).
    Pose: \(a.pose).
    Style: \(m.style).
    Background: one flat solid \(m.background) color filling the whole canvas, with no shadow, gradient, ground, \
    frame or texture, and never use that color on the character.
    No text, no watermark, no border.
    """ + (attempt > 0 ? "\nThe previous attempt was rejected (character cut off or background not clean): keep the whole character well inside the canvas." : "")
    return generateImage(id: a.id, name: a.name, prompt: prompt, rawDir: "raw", attempt: attempt, allowFallback: allowFallback)
}

/// Run Codex once with the reference image attached; copy the image it made to <rawDir>/<id>.png.
func generateImage(id: String, name: String, prompt: String, rawDir: String, attempt: Int, allowFallback: Bool) -> Bool {
    let a = (id: id, name: name)
    let work = FileManager.default.temporaryDirectory.appendingPathComponent("artgen-\(a.id)-\(UUID().uuidString.prefix(6))")
    try? FileManager.default.createDirectory(at: work, withIntermediateDirectories: true)
    let ref = work.appendingPathComponent("reference.png")
    try? FileManager.default.copyItem(at: path("reference/whale-girl.png"), to: ref)
    let out = "\(a.id).png"
    let p = Process()
    p.executableURL = URL(fileURLWithPath: "/usr/bin/env")
    p.arguments = ["codex", "exec", "--skip-git-repo-check", "--ephemeral", "-s", "workspace-write", "-C", work.path,
                   "-i", ref.path, "--json", prompt]
    p.currentDirectoryURL = work
    let log = path("logs/\(a.id)-\(attempt).jsonl")
    FileManager.default.createFile(atPath: log.path, contents: nil)
    p.standardOutput = try? FileHandle(forWritingTo: log)
    p.standardError = FileHandle.nullDevice
    p.standardInput = FileHandle.nullDevice
    let start = Date()
    if allowFallback { print("  generating \(a.id) (\(a.name)) …", terminator: ""); fflush(stdout) }
    do { try p.run() } catch { print(" failed to start codex: \(error)"); return false }
    p.waitUntilExit()
    var result = work.appendingPathComponent(out)
    if !FileManager.default.fileExists(atPath: result.path) && allowFallback {
        // Fall back to the newest file Codex wrote to ~/.codex/generated_images during this run.
        let gen = URL(fileURLWithPath: NSHomeDirectory() + "/.codex/generated_images")
        let files = (FileManager.default.enumerator(at: gen, includingPropertiesForKeys: [.contentModificationDateKey])?
            .compactMap { $0 as? URL } ?? []).filter { $0.pathExtension == "png" }
        let fresh = files.compactMap { u -> (URL, Date)? in
            guard let d = try? u.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate, d >= start else { return nil }
            return (u, d)
        }.max { $0.1 < $1.1 }
        if let f = fresh { result = f.0 }
    }
    guard FileManager.default.fileExists(atPath: result.path) else {
        print("  \(a.id): no image produced (exit \(p.terminationStatus)), see logs/\(a.id)-\(attempt).jsonl"); return false
    }
    try? FileManager.default.createDirectory(at: path(rawDir), withIntermediateDirectories: true)
    let dest = path("\(rawDir)/\(a.id).png")
    try? FileManager.default.removeItem(at: dest)
    try? FileManager.default.copyItem(at: result, to: dest)
    let secs = Date().timeIntervalSince(start)
    if allowFallback { print(String(format: " done in %.0fs", secs)) }
    else { print(String(format: "  generated \(a.id) (\(a.name)) in %.0fs", secs)); fflush(stdout) }
    return true
}

// MARK: - Pixel helpers

struct RGBA { var w: Int; var h: Int; var px: [UInt8] }

func load(_ url: URL) -> RGBA? {
    guard let src = CGImageSourceCreateWithURL(url as CFURL, nil), let img = CGImageSourceCreateImageAtIndex(src, 0, nil) else { return nil }
    let w = img.width, h = img.height
    var px = [UInt8](repeating: 0, count: w * h * 4)
    let ok = px.withUnsafeMutableBytes { buf -> Bool in
        guard let ctx = CGContext(data: buf.baseAddress, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
                                  space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return false }
        ctx.draw(img, in: CGRect(x: 0, y: 0, width: w, height: h))
        return true
    }
    return ok ? RGBA(w: w, h: h, px: px) : nil
}

func save(_ im: RGBA, _ url: URL) {
    var px = im.px
    px.withUnsafeMutableBytes { buf in
        guard let ctx = CGContext(data: buf.baseAddress, width: im.w, height: im.h, bitsPerComponent: 8, bytesPerRow: im.w * 4,
                                  space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue),
              let cg = ctx.makeImage(),
              let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else { return }
        CGImageDestinationAddImage(dest, cg, nil)
        CGImageDestinationFinalize(dest)
    }
}

func scaled(_ im: RGBA, maxSide: Int) -> RGBA {
    let k = min(1, Double(maxSide) / Double(max(im.w, im.h)))
    if k >= 1 { return im }
    let w = max(1, Int(Double(im.w) * k)), h = max(1, Int(Double(im.h) * k))
    var src = im.px
    var out = [UInt8](repeating: 0, count: w * h * 4)
    src.withUnsafeMutableBytes { sb in
        out.withUnsafeMutableBytes { ob in
            let cs = CGColorSpace(name: CGColorSpace.sRGB)!
            let info = CGImageAlphaInfo.premultipliedLast.rawValue
            guard let sctx = CGContext(data: sb.baseAddress, width: im.w, height: im.h, bitsPerComponent: 8, bytesPerRow: im.w * 4, space: cs, bitmapInfo: info),
                  let cg = sctx.makeImage(),
                  let octx = CGContext(data: ob.baseAddress, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4, space: cs, bitmapInfo: info) else { return }
            octx.interpolationQuality = .high
            octx.draw(cg, in: CGRect(x: 0, y: 0, width: w, height: h))
        }
    }
    return RGBA(w: w, h: h, px: out)
}

// MARK: - Processing

/// Key color = median of the outer 2 px border.
func keyColor(_ im: RGBA) -> (Double, Double, Double) {
    var rs: [Int] = [], gs: [Int] = [], bs: [Int] = []
    for y in 0..<im.h { for x in 0..<im.w where x < 2 || y < 2 || x >= im.w - 2 || y >= im.h - 2 {
        let i = (y * im.w + x) * 4
        rs.append(Int(im.px[i])); gs.append(Int(im.px[i + 1])); bs.append(Int(im.px[i + 2]))
    } }
    func med(_ a: [Int]) -> Double { Double(a.sorted()[a.count / 2]) }
    return (med(rs), med(gs), med(bs))
}

/// Key out the background in place (premultiplied result); returns key-colored residue, opaque pixels, specks removed.
func keyOut(_ im: inout RGBA) -> (Int, Int, Int) {
    let (kr, kg, kb) = keyColor(im)
    let n = im.w * im.h
    var alpha = [Double](repeating: 1, count: n)
    // 1) Chroma key with a soft ramp on color distance.
    let t0 = 70.0, t1 = 150.0
    for i in 0..<n {
        let r = Double(im.px[i * 4]), g = Double(im.px[i * 4 + 1]), b = Double(im.px[i * 4 + 2])
        let d = sqrt((r - kr) * (r - kr) + (g - kg) * (g - kg) + (b - kb) * (b - kb))
        alpha[i] = d <= t0 ? 0 : (d >= t1 ? 1 : (d - t0) / (t1 - t0))
    }
    // 2) Connected components on solid pixels; drop specks smaller than 1.5% of the largest piece.
    var label = [Int32](repeating: 0, count: n)
    var sizes: [Int] = [0]
    var stack: [Int] = []
    for s in 0..<n where label[s] == 0 && alpha[s] > 0.05 {
        let lid = Int32(sizes.count); var count = 0
        label[s] = lid; stack.append(s)
        while let i = stack.popLast() {
            count += 1
            let x = i % im.w, y = i / im.w
            for (dx, dy) in [(1, 0), (-1, 0), (0, 1), (0, -1)] {
                let nx = x + dx, ny = y + dy
                guard nx >= 0, ny >= 0, nx < im.w, ny < im.h else { continue }
                let j = ny * im.w + nx
                if label[j] == 0 && alpha[j] > 0.05 { label[j] = lid; stack.append(j) }
            }
        }
        sizes.append(count)
    }
    let biggest = sizes.max() ?? 0
    var removed = 0
    for (k, s) in sizes.enumerated() where k > 0 && s < max(40, biggest * 15 / 1000) { removed += 1; _ = s }
    for i in 0..<n where label[i] > 0 && sizes[Int(label[i])] < max(40, biggest * 15 / 1000) { alpha[i] = 0 }
    // 3) Despill near the edge: pull the key tint out of pixels within 4 px of transparency.
    var edgeDist = [Int](repeating: 99, count: n)
    for i in 0..<n where alpha[i] < 0.5 { edgeDist[i] = 0 }
    for _ in 0..<4 {
        var next = edgeDist
        for y in 0..<im.h { for x in 0..<im.w {
            let i = y * im.w + x
            guard edgeDist[i] > 0 else { continue }
            var m = edgeDist[i]
            if x > 0 { m = min(m, edgeDist[i - 1] + 1) }; if x < im.w - 1 { m = min(m, edgeDist[i + 1] + 1) }
            if y > 0 { m = min(m, edgeDist[i - im.w] + 1) }; if y < im.h - 1 { m = min(m, edgeDist[i + im.w] + 1) }
            next[i] = m
        } }
        edgeDist = next
    }
    let keyIsMagenta = kr > 150 && kb > 150 && kg < 110
    var residue = 0, opaque = 0
    for i in 0..<n {
        var r = Double(im.px[i * 4]), g = Double(im.px[i * 4 + 1]), b = Double(im.px[i * 4 + 2])
        let a = alpha[i]
        if a > 0.5 { opaque += 1 }
        if keyIsMagenta && edgeDist[i] <= 4 {
            let spill = max(0, min(r, b) - g)
            let k = edgeDist[i] <= 1 ? 1.0 : 0.6
            r -= spill * k; b -= spill * k
        }
        if a > 0.5 {
            let d = sqrt((r - kr) * (r - kr) + (g - kg) * (g - kg) + (b - kb) * (b - kb))
            if d < 110 { residue += 1 }
        }
        im.px[i * 4] = UInt8(max(0, min(255, r * a)))
        im.px[i * 4 + 1] = UInt8(max(0, min(255, g * a)))
        im.px[i * 4 + 2] = UInt8(max(0, min(255, b * a)))
        im.px[i * 4 + 3] = UInt8(max(0, min(255, a * 255)))
    }
    return (residue, opaque, removed)
}

func process(_ id: String, allowEdges: [String] = []) -> QAResult? {
    guard var im = load(path("raw/\(id).png")) else { print("  \(id): no raw image"); return nil }
    let (residue, opaque, removed) = keyOut(&im)
    // 4) Trim to content with a small margin; check whether the character touched the canvas border.
    var minX = im.w, minY = im.h, maxX = -1, maxY = -1
    for y in 0..<im.h { for x in 0..<im.w where im.px[(y * im.w + x) * 4 + 3] > 24 {
        minX = min(minX, x); maxX = max(maxX, x); minY = min(minY, y); maxY = max(maxY, y)
    } }
    guard maxX >= 0 else { print("  \(id): nothing left after keying"); return nil }
    var touch: [String] = []
    if minX <= 1 { touch.append("left") }; if maxX >= im.w - 2 { touch.append("right") }
    if minY <= 1 { touch.append("top") }; if maxY >= im.h - 2 { touch.append("bottom") }
    let pad = max(4, (maxX - minX) / 40)
    let cx0 = max(0, minX - pad), cy0 = max(0, minY - pad), cx1 = min(im.w - 1, maxX + pad), cy1 = min(im.h - 1, maxY + pad)
    let cw = cx1 - cx0 + 1, ch = cy1 - cy0 + 1
    var crop = [UInt8](repeating: 0, count: cw * ch * 4)
    for y in 0..<ch { for x in 0..<cw {
        let si = ((y + cy0) * im.w + (x + cx0)) * 4, di = (y * cw + x) * 4
        crop[di] = im.px[si]; crop[di + 1] = im.px[si + 1]; crop[di + 2] = im.px[si + 2]; crop[di + 3] = im.px[si + 3]
    } }
    let out = scaled(RGBA(w: cw, h: ch, px: crop), maxSide: 448)
    save(out, path("processed/\(id).png"))

    let coverage = Double(opaque) / Double(cw * ch)
    let residueFrac = opaque > 0 ? Double(residue) / Double(opaque) : 1
    var problems: [String] = []
    touch.removeAll { allowEdges.contains($0) }
    if !touch.isEmpty { problems.append("character touches the canvas edge (likely cut off): " + touch.joined(separator: ",")) }
    if residueFrac > 0.004 { problems.append(String(format: "background color residue %.2f%%", residueFrac * 100)) }
    if coverage < 0.25 { problems.append(String(format: "character too small or sparse (coverage %.0f%%)", coverage * 100)) }
    return QAResult(id: id, pass: problems.isEmpty, problems: problems, width: out.w, height: out.h,
                    coverage: coverage, residue: residueFrac, edgeTouch: touch, fragmentsRemoved: removed)
}

// MARK: - Install & preview

func install(_ m: Manifest, _ qa: [String: QAResult]) {
    let dir = base.deletingLastPathComponent().appendingPathComponent("assets/generated")
    try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    var entries: [[String: String]] = []
    for a in m.assets {
        let src = path("processed/\(a.id).png")
        guard FileManager.default.fileExists(atPath: src.path), qa[a.id]?.pass == true else {
            print("  skip \(a.id): " + (qa[a.id]?.problems.joined(separator: "; ") ?? "not processed")); continue
        }
        let dest = dir.appendingPathComponent("\(a.id).png")
        try? FileManager.default.removeItem(at: dest)
        try? FileManager.default.copyItem(at: src, to: dest)
        entries.append(["id": a.id, "name": a.name, "file": "\(a.id).png"])
    }
    let data = try! JSONSerialization.data(withJSONObject: entries, options: [.prettyPrinted, .sortedKeys])
    try? data.write(to: dir.appendingPathComponent("generated.json"))
    print("  installed \(entries.count) image(s) into assets/generated")
}

func preview(_ m: Manifest, _ qa: [String: QAResult]) {
    let cell = 300, cols = 3
    let ids = m.assets.map(\.id).filter { FileManager.default.fileExists(atPath: path("processed/\($0).png").path) }
    guard !ids.isEmpty else { return }
    let rows = (ids.count + cols - 1) / cols
    let W = cell * cols, H = (cell + 28) * rows
    guard let ctx = CGContext(data: nil, width: W, height: H, bitsPerComponent: 8, bytesPerRow: 0,
                              space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return }
    for y in stride(from: 0, to: H, by: 12) { for x in stride(from: 0, to: W, by: 12) {
        let dark = ((x / 12) + (y / 12)) % 2 == 0
        ctx.setFillColor(gray: dark ? 0.82 : 0.95, alpha: 1); ctx.fill(CGRect(x: x, y: y, width: 12, height: 12))
    } }
    let ns = NSGraphicsContext(cgContext: ctx, flipped: false)
    NSGraphicsContext.current = ns
    for (k, id) in ids.enumerated() {
        let col = k % cols, row = k / cols
        let ox = col * cell, oy = H - (row + 1) * (cell + 28)
        if let src = CGImageSourceCreateWithURL(path("processed/\(id).png") as CFURL, nil),
           let img = CGImageSourceCreateImageAtIndex(src, 0, nil) {
            let s = min(Double(cell - 20) / Double(img.width), Double(cell - 20) / Double(img.height))
            let w = Double(img.width) * s, h = Double(img.height) * s
            ctx.draw(img, in: CGRect(x: Double(ox) + (Double(cell) - w) / 2, y: Double(oy) + 28 + 10, width: w, height: h))
        }
        let ok = qa[id]?.pass == true
        let label = (ok ? "✓ " : "✗ ") + id
        (label as NSString).draw(at: NSPoint(x: ox + 8, y: oy + 6), withAttributes: [
            .font: NSFont.boldSystemFont(ofSize: 14), .foregroundColor: ok ? NSColor.systemGreen : NSColor.systemRed])
    }
    if let cg = ctx.makeImage(), let dest = CGImageDestinationCreateWithURL(path("preview.png") as CFURL, UTType.png.identifier as CFString, 1, nil) {
        CGImageDestinationAddImage(dest, cg, nil); CGImageDestinationFinalize(dest)
        print("  preview: art-pipeline/preview.png")
    }
}

func loadQA() -> [String: QAResult] {
    guard let d = try? Data(contentsOf: path("qa.json")), let a = try? JSONDecoder().decode([QAResult].self, from: d) else { return [:] }
    return Dictionary(uniqueKeysWithValues: a.map { ($0.id, $0) })
}
func saveQA(_ qa: [String: QAResult]) {
    let enc = JSONEncoder(); enc.outputFormatting = [.prettyPrinted, .sortedKeys]
    try? enc.encode(qa.values.sorted { $0.id < $1.id }).write(to: path("qa.json"))
}


// MARK: - Animations (sprite sheets: one image = a 3×2 grid of 6 frames)

struct AnimSpec: Codable {
    var id: String; var name: String; var fps: Double; var anchor: String; var frames: [String]
    var heightRatio: Double?   // figure height relative to standing (e.g. 0.75 when sitting); used by the app to size the clip
    var lines: [String]?       // speech-bubble lines shown while the clip plays
}
struct AnimManifest: Codable { var anims: [AnimSpec] }
struct AnimQA: Codable {
    var id: String; var pass: Bool; var problems: [String]
    var split: String          // "gaps" or "grid"
    var frames: Int
    var headWidthCV: Double    // variation of head width across frames (consistency)
    var heightCV: Double       // variation of character height across frames
    var meanIoU: Double        // overlap of consecutive frames (low = big jumps)
    var size: [Int]
}

func loadAnims() -> AnimManifest {
    guard let d = try? Data(contentsOf: path("anims.json")), let m = try? JSONDecoder().decode(AnimManifest.self, from: d)
    else { fatalError("anims.json missing or invalid") }
    return m
}

func generateAnim(_ a: AnimSpec, _ m: Manifest, attempt: Int, allowFallback: Bool) -> Bool {
    let list = a.frames.enumerated().map { "Frame \($0.offset + 1): \($0.element)." }.joined(separator: "\n")
    let prompt = """
    Use your built-in image generation tool to create exactly ONE new image, then save that image file \
    into the current directory as \(a.id).png and reply with just the file name. Do not edit or create any other files.
    The image is a SPRITE SHEET for a short looping frame-by-frame animation: a landscape 3:2 image laid out as a grid of \
    3 columns × 2 rows = 6 equal cells, read left to right, top to bottom. Do not draw grid lines or numbers.
    Every cell shows the same character at exactly the same size, same camera distance and same position in the cell, \
    with the feet on the same ground line, so the frames line up when played in sequence. Between frames only the moving \
    parts change; face, hair, outfit, colors and proportions stay identical. Keep each figure fully inside its own cell \
    with clear empty background around it, never touching or crossing into another cell.
    Character: \(m.character).
    Animation: \(a.name), \(a.frames.count) frames.
    \(list)
    Style: \(m.style).
    Background: one flat solid \(m.background) color filling the whole canvas, with no shadow, gradient, ground, \
    frame or texture, and never use that color on the character.
    No text, no watermark, no border.
    """ + (attempt > 0 ? "\nThe previous attempt was rejected (frames inconsistent, touching, or cut off): keep all 6 figures identical in size and well separated." : "")
    return generateImage(id: a.id, name: a.name, prompt: prompt, rawDir: "raw-anim", attempt: attempt, allowFallback: allowFallback)
}

/// Runs of indices whose value is "on", separated by at least `gap` "off" indices.
func runs(_ on: [Bool], gap: Int) -> [(Int, Int)] {
    var out: [(Int, Int)] = []
    var start = -1, lastOn = -1
    for (i, v) in on.enumerated() where v {
        if start < 0 { start = i } else if i - lastOn > gap { out.append((start, lastOn)); start = i }
        lastOn = i
    }
    if start >= 0 { out.append((start, lastOn)) }
    return out
}

/// Merge runs much smaller than the biggest one into their nearest neighbour.
func mergeSmall(_ r: [(Int, Int)], frac: Double) -> [(Int, Int)] {
    var r = r
    while r.count > 1 {
        let sizes = r.map { $0.1 - $0.0 + 1 }
        let big = sizes.max()!
        guard let k = sizes.firstIndex(where: { Double($0) < Double(big) * frac }) else { break }
        let left = k > 0 ? r[k].0 - r[k - 1].1 : Int.max, right = k < r.count - 1 ? r[k + 1].0 - r[k].1 : Int.max
        if left <= right { r[k - 1].1 = r[k].1 } else { r[k + 1].0 = r[k].0 }
        r.remove(at: k)
    }
    return r
}

func processAnim(_ a: AnimSpec) -> AnimQA? {
    guard var im = load(path("raw-anim/\(a.id).png")) else { print("  \(a.id): no raw image"); return nil }
    _ = keyOut(&im)
    let W = im.w, H = im.h
    func alpha(_ x: Int, _ y: Int) -> UInt8 { im.px[(y * W + x) * 4 + 3] }
    let cols = 3, rowsN = 2, want = cols * rowsN
    var problems: [String] = []

    // 1) Split into frames: gaps in the alpha profile, else an equal grid.
    var rects: [(Int, Int, Int, Int)] = []   // x0, y0, x1, y1 inclusive
    let rowOn = (0..<H).map { y in (0..<W).contains { alpha($0, y) > 40 } }
    let bands = mergeSmall(runs(rowOn, gap: 3), frac: 0.2)
    var split = "gaps"
    if bands.count == rowsN {
        for (y0, y1) in bands {
            let colOn = (0..<W).map { x in (y0...y1).contains { alpha(x, $0) > 40 } }
            for (x0, x1) in mergeSmall(runs(colOn, gap: 3), frac: 0.3) { rects.append((x0, y0, x1, y1)) }
        }
    }
    if rects.count != want {
        split = "grid"; rects = []
        for r in 0..<rowsN { for c in 0..<cols {
            rects.append((c * W / cols, r * H / rowsN, (c + 1) * W / cols - 1, (r + 1) * H / rowsN - 1))
        } }
        problems.append("frames not cleanly separated (split by grid)")
    }

    // 2) Per-frame bounding box, head center and width (top 30% of the figure).
    struct F { var bx0, by0, bx1, by1: Int; var headCx: Double; var headW: Int; var cellBottom: Int }  // headCx: x anchor (center of the feet)
    var fs: [F] = []
    for (x0, y0, x1, y1) in rects {
        var bx0 = x1, by0 = y1, bx1 = x0, by1 = y0
        for y in y0...y1 { for x in x0...x1 where alpha(x, y) > 40 { bx0 = min(bx0, x); bx1 = max(bx1, x); by0 = min(by0, y); by1 = max(by1, y) } }
        guard bx1 >= bx0 else { problems.append("empty frame"); continue }
        if split == "grid" && (bx0 <= x0 + 1 || bx1 >= x1 - 1 || by0 <= y0 + 1 || by1 >= y1 - 1) { problems.append("a figure crosses its cell") }
        let headBottom = by0 + (by1 - by0) * 3 / 10
        var sx = 0.0, cnt = 0.0, hx0 = bx1, hx1 = bx0
        for y in by0...headBottom { for x in bx0...bx1 where alpha(x, y) > 128 { sx += Double(x); cnt += 1; hx0 = min(hx0, x); hx1 = max(hx1, x) } }
        // Horizontal anchor: center of the shoes (bottom 6% of the figure), steadier than the head when arms move.
        var fx = 0.0, fc = 0.0
        for y in max(by0, by1 - (by1 - by0) * 6 / 100)...by1 { for x in bx0...bx1 where alpha(x, y) > 128 { fx += Double(x); fc += 1 } }
        _ = sx
        fs.append(F(bx0: bx0, by0: by0, bx1: bx1, by1: by1, headCx: fc > 0 ? fx / fc : (cnt > 0 ? sx / cnt : Double(bx0 + bx1) / 2),
                    headW: max(1, hx1 - hx0), cellBottom: y1))
    }
    guard fs.count == want else { print("  ✗ \(a.id): found \(fs.count) frames"); return nil }

    // 3) Align: feet center on one vertical line; feet on the ground (or keep height above the cell floor for jumps).
    let lift = fs.map { a.anchor == "cell" ? $0.cellBottom - $0.by1 : 0 }
    let left = fs.map { $0.headCx - Double($0.bx0) }.max()!, right = fs.map { Double($0.bx1) - $0.headCx }.max()!
    let half = max(left, right)
    let tall = zip(fs, lift).map { $0.by1 - $0.by0 + $1 }.max()!
    let pad = 8
    let cw = Int(half * 2) + pad * 2, ch = tall + pad * 2
    var frames: [RGBA] = []
    for (k, f) in fs.enumerated() {
        var px = [UInt8](repeating: 0, count: cw * ch * 4)
        let ox = Int((Double(cw) / 2 - f.headCx).rounded()), oy = (ch - pad - lift[k]) - f.by1
        for y in f.by0...f.by1 { for x in f.bx0...f.bx1 {
            let dx = x + ox, dy = y + oy
            guard dx >= 0, dy >= 0, dx < cw, dy < ch else { continue }
            let si = (y * W + x) * 4, di = (dy * cw + dx) * 4
            px[di] = im.px[si]; px[di + 1] = im.px[si + 1]; px[di + 2] = im.px[si + 2]; px[di + 3] = im.px[si + 3]
        } }
        frames.append(scaled(RGBA(w: cw, h: ch, px: px), maxSide: 416))
    }

    // 4) Consistency metrics.
    func cv(_ v: [Double]) -> Double { let m = v.reduce(0, +) / Double(v.count); return sqrt(v.map { ($0 - m) * ($0 - m) }.reduce(0, +) / Double(v.count)) / max(m, 1e-9) }
    let headCV = cv(fs.map { Double($0.headW) }), heightCV = cv(fs.map { Double($0.by1 - $0.by0) })
    var ious: [Double] = []
    for k in 0..<frames.count {
        let p = frames[k], q = frames[(k + 1) % frames.count]
        var inter = 0, uni = 0
        for i in stride(from: 3, to: p.px.count, by: 4) { let x = p.px[i] > 128, y = q.px[i] > 128; if x && y { inter += 1 }; if x || y { uni += 1 } }
        ious.append(uni > 0 ? Double(inter) / Double(uni) : 0)
    }
    let meanIoU = ious.reduce(0, +) / Double(ious.count)
    if headCV > 0.12 { problems.append(String(format: "head size varies %.0f%%", headCV * 100)) }
    if a.anchor == "feet" && heightCV > 0.15 { problems.append(String(format: "figure height varies %.0f%%", heightCV * 100)) }

    let dir = path("processed-anim/\(a.id)")
    try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    for (k, f) in frames.enumerated() { save(f, dir.appendingPathComponent("\(k).png")) }
    saveStrip(frames, dir.appendingPathComponent("strip.png"))
    let pass = problems.isEmpty
    print("  \(pass ? "✓" : "✗") \(a.id) \(split) head±\(Int(headCV * 100))% height±\(Int(heightCV * 100))% IoU \(String(format: "%.2f", meanIoU))"
          + (pass ? "" : "  " + problems.joined(separator: "; ")))
    return AnimQA(id: a.id, pass: pass, problems: problems, split: split, frames: frames.count, headWidthCV: headCV,
                  heightCV: heightCV, meanIoU: meanIoU, size: [frames[0].w, frames[0].h])
}

/// All frames side by side on white with a center line and a ground line, to eyeball alignment.
func saveStrip(_ frames: [RGBA], _ url: URL) {
    guard let f0 = frames.first else { return }
    let W = f0.w * frames.count, H = f0.h
    var px = [UInt8](repeating: 255, count: W * H * 4)
    for (k, f) in frames.enumerated() { for y in 0..<H { for x in 0..<f.w {
        let si = (y * f.w + x) * 4, di = (y * W + k * f0.w + x) * 4
        let a = Double(f.px[si + 3]) / 255
        for c in 0..<3 { px[di + c] = UInt8(min(255, Double(f.px[si + c]) + 255 * (1 - a))) }
    } } }
    func red(_ x: Int, _ y: Int) { let i = (y * W + x) * 4; px[i] = 230; px[i + 1] = 40; px[i + 2] = 40; px[i + 3] = 255 }
    for k in 0..<frames.count { for y in 0..<H { red(k * f0.w + f0.w / 2, y) } }
    let ground = H - 1 - max(1, H * 8 / 416)
    for x in 0..<W { red(x, ground) }
    save(RGBA(w: W, h: H, px: px), url)
}

/// An HTML page that plays every processed animation next to its raw sheet.
func animPreview(_ m: AnimManifest, _ qa: [String: AnimQA]) {
    var cards = ""
    for a in m.anims where FileManager.default.fileExists(atPath: path("processed-anim/\(a.id)/0.png").path) {
        let q = qa[a.id]
        let frames = (0..<a.frames.count).map { "\"processed-anim/\(a.id)/\($0).png\"" }.joined(separator: ",")
        let stats = q.map { String(format: "%@ · 头部 ±%.0f%% · 身高 ±%.0f%% · IoU %.2f", $0.split, $0.headWidthCV * 100, $0.heightCV * 100, $0.meanIoU) } ?? ""
        let flag = q?.pass == true ? "ok" : "bad"
        cards += """
        <figure class="card \(flag)"><div class="stage"><img class="anim" data-fps="\(a.fps)" data-frames='[\(frames)]' src="processed-anim/\(a.id)/0.png" alt="\(a.name)"></div>
        <figcaption><b>\(a.name)</b> <code>\(a.id)</code><br><small>\(stats)</small>\(q.map { $0.problems.isEmpty ? "" : "<br><small class=p>" + $0.problems.joined(separator: "; ") + "</small>" } ?? "")</figcaption>
        <details><summary>原图</summary><img class="raw" src="raw-anim/\(a.id).png" alt="sprite sheet"></details></figure>

        """
    }
    let html = """
    <!doctype html><html lang="zh"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
    <title>Animation preview</title><style>
    :root{--bg:#f4f6fa;--card:#fff;--ink:#1d2433;--muted:#6b7487;--ok:#2fa24c;--bad:#e0433f}
    @media (prefers-color-scheme:dark){:root{--bg:#14171d;--card:#1e222b;--ink:#e8ecf3;--muted:#98a1b3}}
    body{margin:0;padding:16px;background:var(--bg);color:var(--ink);font:14px -apple-system,system-ui,sans-serif}
    .grid{display:grid;grid-template-columns:repeat(auto-fill,minmax(230px,1fr));gap:14px}
    .card{margin:0;background:var(--card);border-radius:12px;padding:10px;border-top:4px solid var(--ok)}.card.bad{border-top-color:var(--bad)}
    .stage{height:240px;display:flex;align-items:flex-end;justify-content:center;background:repeating-conic-gradient(#0000000d 0 25%,#0000 0 50%) 0 0/16px 16px;border-radius:8px}
    .anim{max-height:230px;max-width:100%}.raw{width:100%;margin-top:6px;border-radius:6px}
    small{color:var(--muted)}.p{color:var(--bad)}code{font-size:12px;color:var(--muted)}
    .bar{display:flex;gap:12px;align-items:center;margin-bottom:12px}
    </style></head><body><div class="bar"><b>鲸鱼娘动作预览</b><label>速度 <input id="spd" type="range" min="0.25" max="2" step="0.25" value="1"></label></div>
    <div class="grid">
    \(cards)</div><script>
    let spd=1;document.getElementById('spd').oninput=e=>spd=+e.target.value;
    for(const img of document.querySelectorAll('.anim')){const fr=JSON.parse(img.dataset.frames);fr.forEach(s=>{const i=new Image();i.src=s});
    let k=0,t=0;const fps=+img.dataset.fps;let last=performance.now();
    (function step(now){t+=(now-last)/1000*spd;last=now;if(t>=1/fps){t=0;k=(k+1)%fr.length;img.src=fr[k]}requestAnimationFrame(step)})(last)}
    </script></body></html>
    """
    try? html.write(to: path("anim-preview.html"), atomically: true, encoding: .utf8)
    print("  preview: art-pipeline/anim-preview.html")
}

/// Copy passing animations into assets/anims (frames scaled down to 312 px tall) with a manifest for the app.
func animInstall(_ m: AnimManifest, _ qa: [String: AnimQA]) {
    let dir = base.deletingLastPathComponent().appendingPathComponent("assets/anims")
    var entries: [[String: Any]] = []
    for a in m.anims {
        guard qa[a.id]?.pass == true else { print("  skip \(a.id): " + (qa[a.id]?.problems.joined(separator: "; ") ?? "not processed")); continue }
        let out = dir.appendingPathComponent(a.id)
        try? FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)
        var n = 0
        while let f = load(path("processed-anim/\(a.id)/\(n).png")) { save(scaled(f, maxSide: 312), out.appendingPathComponent("\(n).png")); n += 1 }
        entries.append(["id": a.id, "name": a.name, "fps": a.fps, "frames": n, "heightRatio": a.heightRatio ?? 1, "lines": a.lines ?? []])
    }
    let data = try! JSONSerialization.data(withJSONObject: entries, options: [.prettyPrinted, .sortedKeys])
    try? data.write(to: dir.appendingPathComponent("anims.json"))
    print("  installed \(entries.count) animation(s) into assets/anims")
}

/// One looping GIF with every installed animation playing in a grid (for the README).
func animGIF() {
    let root = base.deletingLastPathComponent()
    guard let d = try? Data(contentsOf: root.appendingPathComponent("assets/anims/anims.json")),
          let entries = try? JSONSerialization.jsonObject(with: d) as? [[String: Any]], !entries.isEmpty else { print("  run anim-install first"); return }
    let clips: [(fps: Double, frames: [CGImage])] = entries.compactMap { e in
        guard let id = e["id"] as? String, let n = e["frames"] as? Int, let fps = e["fps"] as? Double else { return nil }
        let frames = (0..<n).compactMap { k -> CGImage? in
            guard let src = CGImageSourceCreateWithURL(root.appendingPathComponent("assets/anims/\(id)/\(k).png") as CFURL, nil) else { return nil }
            return CGImageSourceCreateImageAtIndex(src, 0, nil)
        }
        return frames.count == n ? (fps, frames) : nil
    }
    let cols = 5, rows = (clips.count + cols - 1) / cols, cw = 180, ch = 210, pad = 12
    let W = cols * cw + pad * 2, H = rows * ch + pad * 2
    let tick = 0.125, ticks = 24   // 3 s loop; every clip has 6 frames at 4–8 fps
    let out = root.appendingPathComponent("docs/animations.gif")
    guard let dest = CGImageDestinationCreateWithURL(out as CFURL, UTType.gif.identifier as CFString, ticks, nil) else { return }
    CGImageDestinationSetProperties(dest, [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFLoopCount: 0]] as CFDictionary)
    for t in 0..<ticks {
        guard let ctx = CGContext(data: nil, width: W, height: H, bitsPerComponent: 8, bytesPerRow: 0,
                                  space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return }
        ctx.setFillColor(red: 0.95, green: 0.96, blue: 0.98, alpha: 1); ctx.fill(CGRect(x: 0, y: 0, width: W, height: H))
        ctx.interpolationQuality = .high
        for (k, c) in clips.enumerated() {
            let img = c.frames[Int(Double(t) * tick * c.fps) % c.frames.count]
            let s = min(Double(cw - 10) / Double(img.width), Double(ch - 10) / Double(img.height))
            let w = Double(img.width) * s, h = Double(img.height) * s
            let x = Double(pad + (k % cols) * cw) + (Double(cw) - w) / 2
            let y = Double(H - pad - (k / cols + 1) * ch) + 5   // bottom-aligned in its cell (CG origin is bottom-left)
            ctx.draw(img, in: CGRect(x: x, y: y, width: w, height: h))
        }
        if let frame = ctx.makeImage() {
            CGImageDestinationAddImage(dest, frame, [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFDelayTime: tick]] as CFDictionary)
        }
    }
    CGImageDestinationFinalize(dest)
    print("  wrote docs/animations.gif")
}

func loadAnimQA() -> [String: AnimQA] {
    guard let d = try? Data(contentsOf: path("anim-qa.json")), let a = try? JSONDecoder().decode([AnimQA].self, from: d) else { return [:] }
    return Dictionary(uniqueKeysWithValues: a.map { ($0.id, $0) })
}
func saveAnimQA(_ qa: [String: AnimQA]) {
    let enc = JSONEncoder(); enc.outputFormatting = [.prettyPrinted, .sortedKeys]
    try? enc.encode(qa.values.sorted { $0.id < $1.id }).write(to: path("anim-qa.json"))
}

// MARK: - CLI

let args = Array(CommandLine.arguments.dropFirst())
let cmd = args.first ?? "all"
let force = args.contains("--force")
var retries = 1
var jobs = 1
if let i = args.firstIndex(of: "--jobs"), i + 1 < args.count, let j = Int(args[i + 1]) { jobs = max(1, min(6, j)) }
if let i = args.firstIndex(of: "--retries"), i + 1 < args.count, let r = Int(args[i + 1]) { retries = r }
let manifest = loadManifest()
let isAnim = cmd.hasPrefix("anim")
let wanted = Set(args.dropFirst().filter { !$0.hasPrefix("--") && Int($0) == nil })
let selected = isAnim ? [] : manifest.assets.filter { wanted.isEmpty || wanted.contains($0.id) }
var qa = loadQA()

/// Generate several assets, `jobs` at a time. With jobs > 1 the "newest file" fallback is off,
/// so one run can never pick up another run's image.
func generateMany(_ list: [AssetSpec], attempt: Int) {
    if jobs <= 1 { for a in list { _ = generate(a, manifest, attempt: attempt) }; return }
    let sem = DispatchSemaphore(value: jobs)
    let group = DispatchGroup()
    var done = 0
    let lock = NSLock()
    for a in list {
        sem.wait(); group.enter()
        DispatchQueue.global().async {
            _ = generate(a, manifest, attempt: attempt, allowFallback: false)
            lock.lock(); done += 1; let n = done; lock.unlock()
            print("    progress \(n)/\(list.count)"); fflush(stdout)
            sem.signal(); group.leave()
        }
    }
    group.wait()
}

func runProcess(_ ids: [String]) {
    for id in ids {
        if let r = process(id, allowEdges: manifest.assets.first { $0.id == id }?.allowEdges ?? []) {
            qa[id] = r
            print("  \(r.pass ? "✓" : "✗") \(id) \(r.width)x\(r.height)" + (r.problems.isEmpty ? "" : "  " + r.problems.joined(separator: "; ")))
        }
    }
    saveQA(qa)
}

func generateAnims(_ list: [AnimSpec], attempt: Int) {
    let sem = DispatchSemaphore(value: jobs), group = DispatchGroup()
    for a in list {
        sem.wait(); group.enter()
        DispatchQueue.global().async { _ = generateAnim(a, manifest, attempt: attempt, allowFallback: jobs <= 1); sem.signal(); group.leave() }
    }
    group.wait()
}

switch cmd {
case "anim-install":
    animInstall(loadAnims(), loadAnimQA())
case "anim-gif":
    animGIF()
case "anim", "anim-process", "anim-preview":
    let am = loadAnims()
    let sel = am.anims.filter { wanted.isEmpty || wanted.contains($0.id) }
    var aqa = loadAnimQA()
    func proc(_ list: [AnimSpec]) { for a in list { if let r = processAnim(a) { aqa[a.id] = r } }; saveAnimQA(aqa) }
    if cmd == "anim" {
        let todo = sel.filter { force || !FileManager.default.fileExists(atPath: path("raw-anim/\($0.id).png").path) }
        print("1/3 generate \(todo.count) sprite sheet(s), \(jobs) at a time")
        generateAnims(todo, attempt: 0)
    }
    if cmd != "anim-preview" { print("2/3 split + align + QA"); proc(sel) }
    if cmd == "anim", retries > 0 {
        for attempt in 1...retries {
            let failed = sel.filter { aqa[$0.id]?.pass != true }
            if failed.isEmpty { break }
            print("   retry \(failed.count) (attempt \(attempt))")
            generateAnims(failed, attempt: attempt); proc(failed)
        }
    }
    print("3/3 preview"); animPreview(am, aqa)
case "generate":
    for (k, a) in selected.enumerated() where force || !FileManager.default.fileExists(atPath: path("raw/\(a.id).png").path) {
        _ = generate(a, manifest, attempt: k * 0)
    }
case "process":
    runProcess(selected.map(\.id))
case "install":
    install(manifest, qa)
case "preview":
    preview(manifest, qa)
case "all":
    let todo = selected.filter { force || !FileManager.default.fileExists(atPath: path("raw/\($0.id).png").path) }
    print("1/4 generate \(todo.count) image(s), \(jobs) at a time")
    generateMany(todo, attempt: 0)
    print("2/4 process + QA")
    runProcess(selected.map(\.id))
    print("3/4 retry failures (up to \(retries) time(s) each)")
    if retries > 0 {
        for attempt in 1...retries {
            let failed = selected.filter { qa[$0.id]?.pass != true }
            if failed.isEmpty { break }
            generateMany(failed, attempt: attempt)
            runProcess(failed.map(\.id))
        }
    }
    print("4/4 install + preview")
    install(manifest, qa)
    preview(manifest, qa)
default:
    print("usage: ./art.sh [all|generate|process|install|preview|anim|anim-process|anim-preview|anim-install|anim-gif] [ids…] [--force] [--retries N] [--jobs N]")
}
