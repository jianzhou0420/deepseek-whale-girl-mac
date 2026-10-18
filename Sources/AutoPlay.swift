// Autoplay: the pet acts on her own every few minutes (idle animation, random bubble, usage report)
// and speaks up on events (peak/off-peak switch, subscription threshold, quota reset).
// She stays quiet in full screen / meetings, while the user is away, at night, and plays no sound.
import AppKit
import CoreMediaIO
import IOKit.pwr_mgt

/// System signals used for quiet time. None of them need extra permissions.
enum QuietSignals {
    static func idleSeconds() -> Double {
        CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: CGEventType(rawValue: ~0)!)
    }

    /// The frontmost app has an on-screen window covering a whole screen.
    static func frontmostFullscreen() -> Bool {
        guard let pid = NSWorkspace.shared.frontmostApplication?.processIdentifier,
              pid != ProcessInfo.processInfo.processIdentifier,
              let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]]
        else { return false }
        let screens = NSScreen.screens.map(\.frame.size)
        for w in list where (w[kCGWindowOwnerPID as String] as? pid_t) == pid && (w[kCGWindowLayer as String] as? Int) == 0 {
            guard let b = w[kCGWindowBounds as String] as? [String: CGFloat], let ww = b["Width"], let hh = b["Height"] else { continue }
            if screens.contains(where: { abs($0.width - ww) < 2 && abs($0.height - hh) < 2 }) { return true }
        }
        return false
    }

    /// Video calls and video players keep the display awake; a camera in use means a call.
    static func meeting() -> Bool { displayKeptAwake() || cameraInUse() }

    static func displayKeptAwake() -> Bool {
        var status: Unmanaged<CFDictionary>?
        guard IOPMCopyAssertionsStatus(&status) == kIOReturnSuccess,
              let d = status?.takeRetainedValue() as? [String: Any] else { return false }
        return ((d["PreventUserIdleDisplaySleep"] as? Int) ?? 0) > 0
    }

    static func cameraInUse() -> Bool {
        func addr(_ sel: Int) -> CMIOObjectPropertyAddress {
            CMIOObjectPropertyAddress(mSelector: CMIOObjectPropertySelector(sel),
                                      mScope: CMIOObjectPropertyScope(kCMIOObjectPropertyScopeGlobal),
                                      mElement: CMIOObjectPropertyElement(kCMIOObjectPropertyElementMain))
        }
        var a = addr(kCMIOHardwarePropertyDevices)
        var size: UInt32 = 0
        let sys = CMIOObjectID(kCMIOObjectSystemObject)
        guard CMIOObjectGetPropertyDataSize(sys, &a, 0, nil, &size) == noErr, size > 0 else { return false }
        var ids = [CMIOObjectID](repeating: 0, count: Int(size) / MemoryLayout<CMIOObjectID>.size)
        var used: UInt32 = 0
        guard CMIOObjectGetPropertyData(sys, &a, 0, nil, size, &used, &ids) == noErr else { return false }
        for id in ids {
            var r = addr(kCMIODevicePropertyDeviceIsRunningSomewhere)
            var running: UInt32 = 0
            var s = UInt32(MemoryLayout<UInt32>.size)
            if CMIOObjectGetPropertyData(id, &r, 0, nil, s, &s, &running) == noErr, running != 0 { return true }
        }
        return false
    }
}

final class AutoPlayer: ObservableObject {
    @Published private(set) var nextAt: Date?
    @Published private(set) var quietReason: String?
    @Published private(set) var lastAction = ""
    /// The last event she announced, for the chat context.
    private(set) var recentEvent: String?

    private weak var model: AppModel?
    private var timer: Timer?
    private var prevPeak: Bool?
    private var prevUsage: [String: Double]?

    func start(_ model: AppModel) {
        self.model = model
        reschedule()
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 15, repeats: true) { [weak self] _ in self?.tick() }
    }

    func reschedule() {
        guard let c = model?.settings.autoPlay, c.on else { nextAt = nil; return }
        nextAt = Date().addingTimeInterval(AutoPlayPolicy.interval(c, r: .random(in: 0..<1)))
    }

    private func env() -> AutoPlayPolicy.Env {
        let c = model?.settings.autoPlay ?? AutoPlayConfig()
        return .init(hour: Calendar.current.component(.hour, from: Date()),
                     idleSeconds: QuietSignals.idleSeconds(),
                     fullscreen: c.quietFullscreen && QuietSignals.frontmostFullscreen(),
                     meeting: c.quietFullscreen && QuietSignals.meeting())
    }

    private func usage() -> [String: Double] {
        var u: [String: Double] = [:]
        for r in model?.subscriptionRows ?? [] { for (label, pct) in r.bars { if let p = pct { u[r.name + "|" + label] = p } } }
        return u
    }

    private func tick() {
        guard let m = model else { return }
        let c = m.settings.autoPlay
        let peak = Pricing.isPeak(Date()), cur = usage()
        defer { prevPeak = peak; prevUsage = cur }
        guard c.on else { quietReason = nil; nextAt = nil; return }
        if nextAt == nil { reschedule() }
        quietReason = AutoPlayPolicy.quietReason(c, env())

        let evs = AutoPlayPolicy.events(c, prevPeak: prevPeak, peak: peak, prev: prevUsage ?? [:], cur: cur)
        if quietReason == nil, m.bubbleIsHidden, let e = evs.first {
            show(e); return
        }
        guard let due = nextAt, Date() >= due else { return }
        reschedule()
        guard quietReason == nil, m.bubbleIsHidden, !m.hovering else { return }
        if let a = AutoPlayPolicy.pick(c, r: .random(in: 0..<1)) { play(a) }
    }

    /// Run one action now (also used by the "try it" button).
    func play(_ a: AutoAction) {
        guard let m = model else { return }
        lastAction = a.rawValue
        let close = m.settings.bubbleCloseSec > 0 ? m.settings.bubbleCloseSec : 6
        switch a {
        case .anim:
            // Atlas moves and AI clips share one pool, so each move is equally likely.
            let pool = Self.atlasMoves.map(\.id) + (m.settings.autoPlay.aiClips ? Clips.shared.list.map(\.id) : [])
            if let id = pool.randomElement() { playMove(id) }
        case .random:
            let idx = m.bubbleConfig.items.firstIndex { $0.kind == "choice" } ?? max(0, m.bubbleConfig.items.count - 1)
            m.showItem(idx, autoClose: close)
            m.playRole(.wave, for: 1.5)
        case .report:
            m.showItem(0, autoClose: close)
        case .chat:
            if !ChatSession.shared.remark(model: m) { play(.anim) }
        }
    }

    // MARK: - Small actions with matching lines

    static let atlasMoves: [(id: String, name: String, anim: Anim, lines: [String])] = [
        ("wave", "挥手", .wave, ["嗨～老大，我在这儿！", "挥挥手，今天也要好好写代码哦", "看到你啦～摸鱼被我抓到了吧",
                                "Hello～需要鲸鱼娘帮忙吗？", "再挥一次手，额度会变多吗？"]),
        ("think", "思考", .think, ["让我想想…这个 bug 好像是你写的", "思考中…请勿打扰（其实在发呆）", "嗯…上下文好像有点长了",
                                  "我在想中午吃什么，别打断我", "推理中…推理完了，忘了题目"]),
        ("jump", "蹦跳", .jump, ["蹦！今天也是元气满满的一天！", "低谷价格，开心到跳起来！", "跳高高，看看服务器在哪",
                                "蹦！刚才那题我会了！", "跳一跳，烦恼少一少"]),
        ("cheer", "欢呼", .cheer, ["耶！代码一次就跑通了！", "加油加油，老大最棒！", "测试全绿，撒花～",
                                  "今天的余额还很健康哦！", "好耶！又是被夸奖的一天"]),
        ("work", "工作", .work, ["认真工作中，请勿投喂…算了投喂吧", "埋头苦干，争取今天不加班", "正在批量生成 token…",
                                "工作使我快乐（小声：才怪）", "再写一个函数就休息！"]),
    ]
    static let moveSeconds = 4.0
    private var bags: [String: ShuffleBag] = [:]

    /// Play one small action (an atlas move id or an AI clip id) and, if enabled, say one of its lines.
    func playMove(_ id: String) {
        guard let m = model else { return }
        var lines: [String] = [], seconds = Self.moveSeconds
        if let a = Self.atlasMoves.first(where: { $0.id == id }) {
            m.playRole(a.anim, for: seconds); lines = a.lines
        } else if let c = Clips.shared.clip(id) {
            seconds = m.playClip(id); lines = c.lines
        } else { return }
        lastAction = id
        guard m.settings.autoPlay.moveLines, !lines.isEmpty, let k = bags[id, default: ShuffleBag()].next(count: lines.count) else { return }
        m.showSpeech(lines[k], seconds: seconds + 0.5)
    }

    private func show(_ e: AutoPlayPolicy.Event) {
        guard let m = model else { return }
        lastAction = e.kind
        let f = DateFormatter(); f.dateFormat = "HH:mm"
        recentEvent = f.string(from: Date()) + " " + e.text + e.highlight
        var mods = [BubbleDefaults.text(e.text, size: 6)]
        if !e.highlight.isEmpty { mods.append(BubbleDefaults.text(e.highlight, size: 9, rgb: "rouge")) }
        let role: Anim = e.kind == "threshold" || e.kind == "peak" ? .panic : .cheer
        m.showAlert(kind: "event", modules: mods, closeSec: 8, role: role, sound: !m.settings.autoPlay.silent)
    }
}
