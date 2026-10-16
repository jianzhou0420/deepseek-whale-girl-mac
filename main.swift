// DeepSeek 鲸鱼娘桌宠 —— 使用网上开源的 deepseek娘 动画图集（MIT 许可，见 assets/LICENSE）
import AppKit
import SwiftUI
import ImageIO

extension Color {
    init(hex: UInt32) {
        self.init(.sRGB, red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255, blue: Double(hex & 0xFF) / 255, opacity: 1)
    }
}
let brand = Color(hex: 0x4D6BFE)

// MARK: - 图集：8 列 × 11 行，每格 192×208
// 行：0 待机(0-5 举“区”牌, 6 中性) 1 向右跑 2 向左跑 3 挥手 4 跳 5 失败(0-3 哭, 4-5 抱膝, 6-7 委屈)
//     6 等待 7 工作 8 思考 9-10 十六方向看（0°=上，顺时针每格 22.5°）
final class Atlas {
    static let cellW = 192, cellH = 208

    /// 原图集里有些帧的头发被直直切掉了一刀：检测到这种硬边时，把那一侧 16 像素做渐隐，避免出现一条竖线
    static func removeStrays(_ img: CGImage) -> CGImage {
        let w = img.width, h = img.height
        guard let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
                                  space: CGColorSpaceCreateDeviceRGB(),
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue),
              let data = ctx.data else { return img }
        ctx.draw(img, in: CGRect(x: 0, y: 0, width: w, height: h))
        let px = data.bindMemory(to: UInt8.self, capacity: w * h * 4)
        // 1) 连通区域：去掉和身体不相连的小碎块
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
        // 2) 硬切边渐隐
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
            fatalError("找不到 spritesheet.webp")
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
    static let sleep     = Anim(row: 8, cols: [3], fps: 1)   // 闭眼帧（原图集抱膝帧被裁切，不用）
    static let sulk      = Anim(row: 5, cols: [6, 7], fps: 3)
    static let cheer     = Anim(row: 6, cols: [0, 1, 2, 3, 4, 5], fps: 6)
    static let work      = Anim(row: 7, cols: [0, 1, 2, 3, 4, 5], fps: 6)
    static let think     = Anim(row: 8, cols: [0, 1, 2, 3, 4, 5], fps: 4)
}

// MARK: - 状态
enum PetState { case idle, walk, sleep, drag, fall, think, act }

final class PetModel: ObservableObject {
    @Published var sprite: CGImage?
    @Published var bubble: String?
    @Published var sleeping = false
    @Published var frame = 0
}

// MARK: - 视图
let spriteW: CGFloat = 144, spriteH: CGFloat = 156   // 192×208 的 0.75 倍
let winW: CGFloat = 240, bubbleH: CGFloat = 70, winH: CGFloat = bubbleH + spriteH

struct BubbleView: View {
    let text: String
    var body: some View {
        Text(text)
            .font(.system(size: 12, weight: .medium))
            .foregroundColor(Color(hex: 0x1F2A60))
            .multilineTextAlignment(.center)
            .lineLimit(3)
            .padding(.horizontal, 10).padding(.vertical, 7)
            .background(RoundedRectangle(cornerRadius: 12).fill(Color.white))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(brand, lineWidth: 1.5))
            .frame(maxWidth: 224)
            .padding(.bottom, 2)
    }
}

struct ZzzView: View {
    let frame: Int
    var body: some View {
        let t = Double(frame % 60) / 60
        ZStack {
            Text("Z").font(.system(size: 16, weight: .heavy, design: .rounded))
                .offset(x: 6, y: -t * 16).opacity(1 - t)
            Text("z").font(.system(size: 11, weight: .heavy, design: .rounded))
                .offset(x: -6, y: 10 - t * 10).opacity(0.4 + 0.6 * (1 - t))
        }
        .foregroundColor(brand)
        .offset(x: 40, y: -40)
    }
}

struct PetView: View {
    @ObservedObject var model: PetModel
    var body: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .bottom) {
                if let text = model.bubble { BubbleView(text: text) }
            }
            .frame(width: winW, height: bubbleH, alignment: .bottom)
            ZStack {
                if let img = model.sprite {
                    Image(decorative: img, scale: 1)
                        .resizable()
                        .interpolation(.high)
                        .frame(width: spriteW, height: spriteH)
                }
                if model.sleeping { ZzzView(frame: model.frame) }
            }
            .frame(width: spriteW, height: spriteH)
        }
        .frame(width: winW, height: winH)
    }
}

// MARK: - 台词
enum Lines {
    static let busy = "服务器繁忙，请稍后再试。"
    static let greet = "你好呀！我是 DeepSeek 鲸鱼娘～🐳"
    static let idle = [
        busy,
        "今天也要开源一点点哦！",
        "（摸鱼中……不对，我是鲸鱼）",
        "思考链太长，把自己绕晕了 @_@",
        "要不要问我一道数学题？",
        "来自杭州的问候～",
    ]
    static let poke = [
        "你好！我是 DeepSeek，很高兴见到你！",
        busy,
        "嗯，用户戳了我一下，我应该……",
        "别戳啦，我在推理呢！",
        "Token 很便宜，多戳几下也没关系～",
        "需要我帮你写代码吗？",
        "主人有什么吩咐？",
    ]
    static let drag = ["哇！要带我去哪里～", "放、放我下来！", "我会游泳，但不会飞啊！"]
    static let conclusion = [
        "……结论是：多喝水。",
        "……算了，服务器繁忙。",
        "……答案是 42。",
        "……忘了你刚才问的是什么。",
    ]
}

// MARK: - 鼠标输入层
final class InputView: NSView {
    weak var controller: PetController?
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    override func mouseDown(with e: NSEvent) { controller?.pressBegan() }
    override func mouseDragged(with e: NSEvent) { controller?.pressMoved() }
    override func mouseUp(with e: NSEvent) { controller?.pressEnded() }
    override func rightMouseDown(with e: NSEvent) {
        if let c = controller { NSMenu.popUpContextMenu(c.makeMenu(), with: e, for: self) }
    }
}

// MARK: - 控制器
final class PetController: NSObject {
    let model = PetModel()
    let atlas = Atlas()
    var window: NSWindow!
    var statusItem: NSStatusItem!
    var timer: Timer!
    let dt = 1.0 / 30.0
    // 角色身体在窗口中的大致区域，其余透明处鼠标穿透
    let hitRect = NSRect(x: winW / 2 - 48, y: 0, width: 96, height: spriteH - 8)

    var state: PetState = .fall { didSet { if state != oldValue { animTime = 0 } } }
    var anim: Anim = .neutral
    var animTime = 0.0
    var stateTime = 2.0, bubbleTime = 0.0
    var thinkSeconds = 0
    var targetX: CGFloat = 0
    var vy: CGFloat = 0
    var pressStart: NSPoint?
    var dragOffset = NSPoint.zero
    var didDrag = false
    var lastMouse = NSPoint.zero
    var mouseIdle = 99.0

    func start() {
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: winW, height: winH),
                          styleMask: [.borderless], backing: .buffered, defer: false)
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.level = .floating
        window.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]

        let container = NSView(frame: NSRect(x: 0, y: 0, width: winW, height: winH))
        let host = NSHostingView(rootView: PetView(model: model))
        host.frame = container.bounds
        container.addSubview(host)
        let input = InputView(frame: container.bounds)
        input.controller = self
        container.addSubview(input)
        window.contentView = container

        let vf = (NSScreen.main ?? NSScreen.screens[0]).visibleFrame
        window.setFrameOrigin(NSPoint(x: vf.midX - winW / 2, y: vf.maxY - winH))
        state = .fall
        window.orderFrontRegardless()

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.title = "🐳"
        statusItem.menu = makeMenu()

        say(Lines.greet, 3.5)
        timer = Timer(timeInterval: dt, repeats: true) { [weak self] _ in self?.step() }
        RunLoop.main.add(timer, forMode: .common)
    }

    func makeMenu() -> NSMenu {
        let menu = NSMenu()
        func add(_ title: String, _ sel: Selector) {
            let item = NSMenuItem(title: title, action: sel, keyEquivalent: "")
            item.target = self
            menu.addItem(item)
        }
        add("说句话", #selector(menuTalk))
        add("深度思考一下", #selector(menuThink))
        add("举牌子", #selector(menuBoard))
        add("睡觉 / 叫醒", #selector(menuSleep))
        add("回到屏幕中间", #selector(menuCenter))
        menu.addItem(.separator())
        add("退出鲸鱼娘", #selector(menuQuit))
        return menu
    }

    @objc func menuTalk() { talk(Lines.poke.randomElement()!) }
    @objc func menuThink() { startThinking() }
    @objc func menuBoard() { act(.board, 4.5); model.bubble = nil }
    @objc func menuSleep() {
        if state == .sleep { act(.wave, 2); say("唔…醒啦！", 2) }
        else { state = .sleep; stateTime = 30; say("那我睡一会儿 💤", 2) }
    }
    @objc func menuCenter() {
        let vf = screen().visibleFrame
        window.setFrameOrigin(NSPoint(x: vf.midX - winW / 2, y: vf.maxY - winH))
        state = .fall; vy = 0
    }
    @objc func menuQuit() { NSApp.terminate(nil) }

    func screen() -> NSScreen {
        let c = NSPoint(x: window.frame.midX, y: window.frame.midY)
        return NSScreen.screens.first { $0.frame.contains(c) } ?? NSScreen.main ?? NSScreen.screens[0]
    }

    func say(_ text: String, _ duration: Double) { model.bubble = text; bubbleTime = duration }
    func act(_ a: Anim, _ duration: Double) { anim = a; state = .act; animTime = 0; stateTime = duration }

    /// 说一句话，并配上合适的动作
    func talk(_ line: String) {
        say(line, 3.5)
        if line == Lines.busy { act(.sulk, 3) }
        else if Bool.random() { act(.wave, 2.5) }
        else { act(.cheer, 2.5) }
    }

    func startThinking() {
        state = .think
        stateTime = Double.random(in: 2.5...4.5)
        thinkSeconds = Int(stateTime.rounded())
    }

    // 鼠标
    func pressBegan() {
        let m = NSEvent.mouseLocation
        pressStart = m
        dragOffset = NSPoint(x: m.x - window.frame.minX, y: m.y - window.frame.minY)
        didDrag = false
    }
    func pressMoved() {
        guard let s = pressStart else { return }
        let m = NSEvent.mouseLocation
        if !didDrag && hypot(m.x - s.x, m.y - s.y) > 4 {
            didDrag = true
            state = .drag
            say(Lines.drag.randomElement()!, 2)
        }
        if didDrag { window.setFrameOrigin(NSPoint(x: m.x - dragOffset.x, y: m.y - dragOffset.y)) }
    }
    func pressEnded() {
        defer { pressStart = nil }
        if didDrag { state = .fall; vy = 0; return }
        poke()
    }
    func poke() {
        if state == .sleep { act(.wave, 2.5); say("唔…被吵醒了…", 2.5); return }
        if state == .think { return }
        let r = Double.random(in: 0..<1)
        if r < 0.2 { startThinking() }
        else if r < 0.32 { menuBoard() }
        else if r < 0.5 { say(Lines.poke.randomElement()!, 3); state = .fall; vy = 8; anim = .jump }
        else { talk(Lines.poke.randomElement()!) }
    }

    func updatePassthrough() {
        if pressStart != nil || state == .drag { window.ignoresMouseEvents = false; return }
        let m = NSEvent.mouseLocation
        let local = NSPoint(x: m.x - window.frame.minX, y: m.y - window.frame.minY)
        let ignore = !hitRect.contains(local)
        if window.ignoresMouseEvents != ignore { window.ignoresMouseEvents = ignore }
    }

    /// 鼠标最近在动时，按 16 个方向看向鼠标
    func lookFrame() -> (Int, Int)? {
        guard mouseIdle < 1.2 else { return nil }
        let m = NSEvent.mouseLocation
        let head = NSPoint(x: window.frame.midX, y: window.frame.minY + spriteH * 0.7)
        let dx = m.x - head.x, dy = m.y - head.y
        guard hypot(dx, dy) > 40 else { return nil }
        var deg = atan2(dx, dy) * 180 / .pi       // 0°=上，顺时针
        if deg < 0 { deg += 360 }
        let idx = Int((deg / 22.5).rounded()) % 16
        return (9 + idx / 8, idx % 8)
    }

    // 每帧更新
    func step() {
        model.frame &+= 1
        animTime += dt

        let m = NSEvent.mouseLocation
        if m != lastMouse { lastMouse = m; mouseIdle = 0 } else { mouseIdle += dt }

        if model.bubble != nil && state != .think {
            bubbleTime -= dt
            if bubbleTime <= 0 { model.bubble = nil }
        }
        updatePassthrough()

        var o = window.frame.origin
        let vf = screen().visibleFrame
        let ground = vf.minY
        let minX = vf.minX - 40, maxX = vf.maxX - winW + 40
        var cell: (Int, Int)

        switch state {
        case .drag:
            cell = Anim.panic.frame(at: animTime)
        case .fall:
            vy -= 1.1
            o.y += vy
            cell = vy > 0 ? Anim.jump.frame(at: animTime) : (5, 1)
            if o.y <= ground { o.y = ground; vy = 0; state = .idle; stateTime = Double.random(in: 1...3) }
        case .walk:
            let dx = targetX - o.x
            let right = dx > 0
            cell = (right ? Anim.runRight : Anim.runLeft).frame(at: animTime)
            if abs(dx) < 2 { state = .idle; stateTime = Double.random(in: 2...6) }
            else { o.x += right ? 2 : -2 }
        case .idle:
            cell = lookFrame() ?? Anim.neutral.frame(at: 0)
            if o.y > ground + 1 { state = .fall; break }
            o.y = ground
            stateTime -= dt
            if stateTime <= 0 { decide(minX: minX, maxX: maxX) }
        case .act:
            cell = anim.frame(at: animTime)
            stateTime -= dt
            if o.y > ground + 1 { o.y = max(ground, o.y - 6) }
            if stateTime <= 0 { state = .idle; stateTime = Double.random(in: 2...4) }
        case .sleep:
            cell = Anim.sleep.frame(at: animTime)
            stateTime -= dt
            if stateTime <= 0 { act(.wave, 2); say("睡饱啦～", 2) }
        case .think:
            cell = Anim.think.frame(at: animTime)
            stateTime -= dt
            model.bubble = "💭 深度思考中" + String(repeating: "·", count: (model.frame / 8) % 4)
            if stateTime <= 0 {
                say("已深度思考（用时 \(thinkSeconds) 秒）\n" + Lines.conclusion.randomElement()!, 4)
                act(.cheer, 3)
            }
        }

        model.sleeping = state == .sleep
        let img = atlas.image(cell.0, cell.1)
        if model.sprite !== img { model.sprite = img }

        o.x = min(max(o.x, minX), maxX)
        if o != window.frame.origin { window.setFrameOrigin(o) }
    }

    func decide(minX: CGFloat, maxX: CGFloat) {
        let r = Double.random(in: 0..<1)
        if r < 0.5 {
            targetX = CGFloat.random(in: (minX + 40)...(maxX - 40))
            state = .walk
        } else if r < 0.62 {
            state = .sleep; stateTime = Double.random(in: 12...25)
            say("困了…先睡一会儿 💤", 2)
        } else if r < 0.76 {
            talk(Lines.idle.randomElement()!)
        } else if r < 0.82 {
            startThinking()
        } else if r < 0.88 {
            menuBoard()
        } else if r < 0.92 {
            act(.work, 3); say("努力工作中！", 2.5)
        } else {
            stateTime = Double.random(in: 2...5)
        }
    }
}

// MARK: - 截图模式（开发时检查画面用）: WhaleGirl --snapshot <目录>
@MainActor func renderSnapshots(to dir: String) {
    let atlas = Atlas()
    let cases: [(String, (Int, Int), String?, Bool)] = [
        ("idle", (0, 6), Lines.greet, false),
        ("walk", (1, 3), nil, false),
        ("think", (8, 2), "💭 深度思考中···", false),
        ("drag", (5, 3), Lines.drag[1], false),
        ("sleep", (8, 3), nil, true),
        ("board", (0, 2), nil, false),
    ]
    for (name, cell, bubble, sleeping) in cases {
        let m = PetModel()
        m.sprite = atlas.image(cell.0, cell.1); m.bubble = bubble; m.sleeping = sleeping; m.frame = 20
        let r = ImageRenderer(content: PetView(model: m).background(Color(hex: 0xDDE3EE)))
        r.scale = 2
        if let img = r.nsImage, let tiff = img.tiffRepresentation,
           let rep = NSBitmapImageRep(data: tiff), let png = rep.representation(using: .png, properties: [:]) {
            try? png.write(to: URL(fileURLWithPath: dir).appendingPathComponent("\(name).png"))
        }
    }
}

// MARK: - 启动
final class AppDelegate: NSObject, NSApplicationDelegate {
    let pet = PetController()
    func applicationDidFinishLaunching(_ n: Notification) { pet.start() }
}

let args = CommandLine.arguments
if let i = args.firstIndex(of: "--snapshot"), i + 1 < args.count {
    MainActor.assumeIsolated { renderSnapshots(to: args[i + 1]) }
    exit(0)
}
let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
