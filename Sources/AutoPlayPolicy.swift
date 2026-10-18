// Autoplay settings and the pure decisions behind them (quiet time, weighted pick, interval, events).
import Foundation

struct AutoPlayConfig: Codable, Equatable {
    var on = true
    var minMinutes = 1.0, maxMinutes = 3.0
    var wAnim = 3.0, wRandom = 2.0, wReport = 1.0
    var wChat = 0.0                 // she says something written by DeepSeek (costs a little per remark)
    var aiClips = true              // small actions also draw from the AI-generated clips
    var moveLines = true            // small actions come with a matching speech bubble
    var evPeak = true
    var evThreshold = true
    var threshold = 80.0
    var evReset = true
    var quietFullscreen = true      // full-screen app in front, camera on, or an app keeping the display awake
    var quietAway = true
    var awayMinutes = 5.0
    var quietNight = true
    var nightStart = 23, nightEnd = 8
    var silent = true               // autoplay never makes sound
}

enum AutoAction: String, CaseIterable { case anim, random, report, chat }

/// Pure decisions, kept separate so they can be tested.
enum AutoPlayPolicy {
    static func isNight(hour h: Int, start: Int, end: Int) -> Bool {
        if start == end { return false }
        return start < end ? (h >= start && h < end) : (h >= start || h < end)
    }

    struct Env { var hour: Int; var idleSeconds: Double; var fullscreen: Bool; var meeting: Bool }

    static func quietReason(_ c: AutoPlayConfig, _ e: Env) -> String? {
        if c.quietFullscreen && e.fullscreen { return "全屏中" }
        if c.quietFullscreen && e.meeting { return "会议 / 视频中" }
        if c.quietAway && e.idleSeconds >= c.awayMinutes * 60 { return "你不在电脑前" }
        if c.quietNight && isNight(hour: e.hour, start: c.nightStart, end: c.nightEnd) { return "夜间免打扰" }
        return nil
    }

    /// Weighted pick; `r` is a uniform random number in [0, 1).
    static func pick(_ c: AutoPlayConfig, r: Double) -> AutoAction? {
        let ws: [(AutoAction, Double)] = [(.anim, c.wAnim), (.random, c.wRandom), (.report, c.wReport), (.chat, c.wChat)].filter { $0.1 > 0 }
        let total = ws.reduce(0) { $0 + $1.1 }
        guard total > 0 else { return nil }
        var x = r * total
        for (a, w) in ws { x -= w; if x < 0 { return a } }
        return ws.last?.0
    }

    static func interval(_ c: AutoPlayConfig, r: Double) -> TimeInterval {
        let lo = max(1, min(c.minMinutes, c.maxMinutes)), hi = max(lo, max(c.minMinutes, c.maxMinutes))
        return (lo + (hi - lo) * r) * 60
    }

    struct Event: Equatable { var kind: String; var text: String; var highlight: String = "" }

    /// Compare two usage observations ("name|window" -> percent) and the peak state.
    static func events(_ c: AutoPlayConfig, prevPeak: Bool?, peak: Bool,
                       prev: [String: Double], cur: [String: Double]) -> [Event] {
        var out: [Event] = []
        if c.evPeak, let p = prevPeak, p != peak {
            out.append(peak ? Event(kind: "peak", text: "高峰时段开始啦，DeepSeek 要涨价了～")
                            : Event(kind: "offpeak", text: "进入低谷时段，DeepSeek 打折中！"))
        }
        for key in cur.keys.sorted() {
            guard let now = cur[key], let before = prev[key] else { continue }
            let parts = key.components(separatedBy: "|")
            let name = parts.first ?? key, win = parts.count > 1 ? parts[1] : ""
            if c.evThreshold, before < c.threshold, now >= c.threshold {
                out.append(Event(kind: "threshold", text: "\(name) \(win) 额度已用", highlight: String(format: "%.0f%%", now)))
            } else if c.evReset, before >= 20, now <= 5 {
                out.append(Event(kind: "reset", text: "\(name) \(win) 额度重置啦！"))
            }
        }
        return out
    }
}

/// Deals indices 0..<count in random order without repeats; a new round never starts with the last one dealt.
struct ShuffleBag {
    private var bag: [Int] = []
    private(set) var last: Int?

    mutating func next(count: Int, random: (Int) -> Int = { Int.random(in: 0..<$0) }) -> Int? {
        guard count > 0 else { return nil }
        if bag.isEmpty || bag.contains(where: { $0 >= count }) {
            var fresh = Array(0..<count)
            for i in stride(from: count - 1, to: 0, by: -1) { fresh.swapAt(i, random(i + 1)) }
            if count > 1, fresh.last == last { fresh.swapAt(count - 1, 0) }
            bag = fresh
        }
        last = bag.removeLast()
        return last
    }
}
