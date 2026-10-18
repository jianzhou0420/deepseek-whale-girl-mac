// Art asset pipeline: generate character images with Codex CLI (ChatGPT plan, built-in image
// generation), key out the background, clean up, run quality checks, install into the app.
//
//   ./art.sh all                 generate missing images, process, retry failures, install, preview
//   ./art.sh generate [ids…]     generate (or with --force, regenerate) raw images
//   ./art.sh process [ids…]      key out background + QA for raw images
//   ./art.sh install             copy passing images into assets/generated + manifest
//   ./art.sh preview             contact sheet of processed images on a checkerboard
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

func generate(_ a: AssetSpec, _ m: Manifest, attempt: Int) -> Bool {
    let work = FileManager.default.temporaryDirectory.appendingPathComponent("artgen-\(a.id)-\(UUID().uuidString.prefix(6))")
    try? FileManager.default.createDirectory(at: work, withIntermediateDirectories: true)
    let ref = work.appendingPathComponent("reference.png")
    try? FileManager.default.copyItem(at: path("reference/whale-girl.png"), to: ref)
    let out = "\(a.id).png"
    let prompt = """
    Use your built-in image generation tool to create exactly ONE new image, then save that image file \
    into the current directory as \(out) and reply with just the file name. Do not edit or create any other files.
    Character: \(m.character).
    Pose: \(a.pose).
    Style: \(m.style).
    Background: one flat solid \(m.background) color filling the whole canvas, with no shadow, gradient, ground, \
    frame or texture, and never use that color on the character.
    No text, no watermark, no border.
    """ + (attempt > 0 ? "\nThe previous attempt was rejected (character cut off or background not clean): keep the whole character well inside the canvas." : "")
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
    print("  generating \(a.id) (\(a.name)) …", terminator: ""); fflush(stdout)
    do { try p.run() } catch { print(" failed to start codex: \(error)"); return false }
    p.waitUntilExit()
    var result = work.appendingPathComponent(out)
    if !FileManager.default.fileExists(atPath: result.path) {
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
        print(" no image produced (exit \(p.terminationStatus)), see logs/\(a.id)-\(attempt).jsonl"); return false
    }
    let dest = path("raw/\(a.id).png")
    try? FileManager.default.removeItem(at: dest)
    try? FileManager.default.copyItem(at: result, to: dest)
    print(String(format: " done in %.0fs", Date().timeIntervalSince(start)))
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

func process(_ id: String, allowEdges: [String] = []) -> QAResult? {
    guard var im = load(path("raw/\(id).png")) else { print("  \(id): no raw image"); return nil }
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
    let out = scaled(RGBA(w: cw, h: ch, px: crop), maxSide: 640)
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

// MARK: - CLI

let args = Array(CommandLine.arguments.dropFirst())
let cmd = args.first ?? "all"
let force = args.contains("--force")
var retries = 1
if let i = args.firstIndex(of: "--retries"), i + 1 < args.count, let r = Int(args[i + 1]) { retries = r }
let manifest = loadManifest()
let wanted = Set(args.dropFirst().filter { !$0.hasPrefix("--") && Int($0) == nil })
let selected = manifest.assets.filter { wanted.isEmpty || wanted.contains($0.id) }
var qa = loadQA()

func runProcess(_ ids: [String]) {
    for id in ids {
        if let r = process(id, allowEdges: manifest.assets.first { $0.id == id }?.allowEdges ?? []) {
            qa[id] = r
            print("  \(r.pass ? "✓" : "✗") \(id) \(r.width)x\(r.height)" + (r.problems.isEmpty ? "" : "  " + r.problems.joined(separator: "; ")))
        }
    }
    saveQA(qa)
}

switch cmd {
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
    print("1/4 generate")
    for a in selected where force || !FileManager.default.fileExists(atPath: path("raw/\(a.id).png").path) {
        _ = generate(a, manifest, attempt: 0)
    }
    print("2/4 process + QA")
    runProcess(selected.map(\.id))
    print("3/4 retry failures (up to \(retries) time(s) each)")
    for a in selected where qa[a.id]?.pass != true {
        for attempt in 1...max(1, retries) where retries > 0 {
            if generate(a, manifest, attempt: attempt) { runProcess([a.id]) }
            if qa[a.id]?.pass == true { break }
        }
    }
    print("4/4 install + preview")
    install(manifest, qa)
    preview(manifest, qa)
default:
    print("usage: ./art.sh [all|generate|process|install|preview] [ids…] [--force] [--retries N]")
}
