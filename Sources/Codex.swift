// Local Codex usage stats: reads ~/.codex/sessions/**/rollout-*.jsonl (plain JSONL, read-only, no network).
// Parsing rules ported from lib/index.js of MeteorNOX/DeepSeek-Balance-Whale-Widget (MIT):
//  - model comes from type=turn_context payload.model
//  - usage comes from event_msg/token_count payload.info; prefer deltas of the cumulative total_token_usage
//  - rate_limits snapshots (ChatGPT subscription) give 5h / weekly windows
import Foundation

struct CodexTokens: Codable, Equatable {
    var input = 0, cached = 0, output = 0, reasoning = 0, total = 0, turns = 0
    static func + (a: CodexTokens, b: CodexTokens) -> CodexTokens {
        CodexTokens(input: a.input + b.input, cached: a.cached + b.cached, output: a.output + b.output,
                    reasoning: a.reasoning + b.reasoning, total: a.total + b.total, turns: a.turns + b.turns)
    }
}

struct CodexWindow: Codable, Equatable {
    var label: String
    var usedPct: Double?
    var resetAt: Date?
    var windowMinutes: Double?
}

struct CodexFileCache: Codable {
    var planType: String?
    var size: Int
    var mtime: Double
    var days: [String: [String: CodexTokens]]
    var windows: [CodexWindow]
    var windowsAt: Double
}

struct CodexSnapshot: Equatable {
    var today = 0, week = 0, month = 0, all = 0
    var fileCount = 0
    var byModelToday: [String: Int] = [:]
    var days: [String: Int] = [:]
    var windows: [CodexWindow] = []
    var planType: String?
    var found = false
}

final class CodexStats {
    static let shared = CodexStats()
    private var cache: [String: CodexFileCache] = [:]
    private let queue = DispatchQueue(label: "codex-stats")
    private var cacheURL: URL { Store.dir.appendingPathComponent("codex-cache.json") }

    init() {
        if let data = try? Data(contentsOf: cacheURL),
           let c = try? JSONDecoder().decode([String: CodexFileCache].self, from: data) { cache = c }
    }

    static var home: URL? {
        let env = ProcessInfo.processInfo.environment["CODEX_HOME"] ?? ""
        for c in [env, NSHomeDirectory() + "/.codex"] where !c.isEmpty {
            if FileManager.default.fileExists(atPath: c) { return URL(fileURLWithPath: c) }
        }
        return nil
    }

    static func localDay(_ date: Date) -> String {
        let c = Calendar.current.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year!, c.month!, c.day!)
    }

    static func formatTokens(_ n: Int) -> String {
        if n >= 1_000_000 { return String(format: "%.2fM", Double(n) / 1e6) }
        if n >= 10_000 { return String(format: "%.1fK", Double(n) / 1e3) }
        return "\(n)"
    }

    private func sessionFiles(_ root: URL) -> [URL] {
        var out: [URL] = []
        for sub in ["sessions", "archived_sessions"] {
            let dir = root.appendingPathComponent(sub)
            guard let e = FileManager.default.enumerator(at: dir, includingPropertiesForKeys: [.fileSizeKey, .contentModificationDateKey]) else { continue }
            for case let url as URL in e where url.lastPathComponent.hasPrefix("rollout-") && url.pathExtension == "jsonl" {
                out.append(url)
            }
        }
        return out
    }

    static func parse(_ text: String) -> (days: [String: [String: CodexTokens]], windows: [CodexWindow], windowsAt: Double, plan: String?) {
        var days: [String: [String: CodexTokens]] = [:]
        var model = "codex"
        var prevTotal: Int? = nil
        var windows: [CodexWindow] = []
        var windowsAt: Double = 0
        var plan: String? = nil
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let iso2 = ISO8601DateFormatter()

        for line in text.split(separator: "\n", omittingEmptySubsequences: true) where line.first == "{" {
            guard let obj = try? JSONSerialization.jsonObject(with: Data(line.utf8)) as? [String: Any],
                  let p = obj["payload"] as? [String: Any] else { continue }
            let type = obj["type"] as? String ?? ""
            if type == "turn_context" {
                if let m = p["model"] as? String, !m.isEmpty { model = m }
                continue
            }
            guard type == "event_msg", p["type"] as? String == "token_count",
                  let info = p["info"] as? [String: Any] else { continue }
            let tsStr = obj["timestamp"] as? String ?? ""
            guard let ts = iso.date(from: tsStr) ?? iso2.date(from: tsStr) else { continue }
            let last = info["last_token_usage"] as? [String: Any]
            let tot = info["total_token_usage"] as? [String: Any]
            func n(_ d: [String: Any]?, _ k: String) -> Int { Int(JSONPath.toNumber(d?[k]) ?? 0) }
            var delta: Int? = nil
            let totAll = n(tot, "total_tokens")
            if totAll > 0 {
                if let prev = prevTotal, totAll >= prev { delta = totAll - prev } else { delta = totAll }
                prevTotal = totAll
            }
            // Fall back to last_token_usage only when the cumulative total is missing. A repeated
            // cumulative total is a duplicate snapshot and adds nothing.
            if delta == nil {
                guard last != nil else { continue }
                delta = n(last, "total_tokens")
            }
            guard let d = delta, d > 0 else { continue }
            let lTotal = n(last, "total_tokens")
            let k = lTotal > 0 ? Double(d) / Double(lTotal) : 0
            func s(_ key: String) -> Int { Int((Double(n(last, key)) * k).rounded()) }
            let v = CodexTokens(input: s("input_tokens"), cached: s("cached_input_tokens"), output: s("output_tokens"),
                                reasoning: s("reasoning_output_tokens"), total: d, turns: 1)
            let day = localDay(ts)
            days[day, default: [:]][model, default: CodexTokens()] = days[day, default: [:]][model, default: CodexTokens()] + v

            if let rl = p["rate_limits"] as? [String: Any], ts.timeIntervalSince1970 >= windowsAt {
                var ws: [CodexWindow] = []
                for (key, label) in [("primary", "5h"), ("secondary", "周")] {
                    if let w = rl[key] as? [String: Any], let win = normalize(w, label: label, eventTime: ts) { ws.append(win) }
                }
                if !ws.isEmpty { windows = ws; windowsAt = ts.timeIntervalSince1970 }
                if let pt = rl["plan_type"] as? String, !pt.isEmpty { plan = pt }
            }
        }
        return (days, windows, windowsAt, plan)
    }

    private static func normalize(_ w: [String: Any], label: String, eventTime: Date) -> CodexWindow? {
        func pick(_ keys: [String]) -> Double? {
            for k in keys { if let v = JSONPath.toNumber(w[k]) { return v } }
            return nil
        }
        var used = pick(["used_percent", "usedPercent", "percent", "used_pct", "usage_percent", "usagePercent"])
        if used == nil, let r = pick(["remaining_percent", "remainingPercent", "left_percent", "remaining_pct"]) { used = max(0, 100 - r) }
        var reset: Date? = nil
        if let secs = pick(["resets_in_seconds", "resetsInSeconds", "reset_after_seconds", "reset_in_seconds", "seconds_until_reset"]), secs >= 0 {
            reset = eventTime.addingTimeInterval(secs)
        } else {
            for k in ["resets_at", "reset_at", "reset_time", "next_reset", "resetAt", "nextResetTime"] {
                if let d = JSONPath.date(w[k]) { reset = d; break }
            }
        }
        let minutes = pick(["window_minutes", "windowMinutes", "window", "period_minutes"])
        var name = label
        if let m = minutes { name = m >= 1440 * 6 ? "周" : (m >= 60 ? "\(Int(m / 60))h" : "\(Int(m))m") }
        if used == nil && reset == nil { return nil }
        return CodexWindow(label: name, usedPct: used, resetAt: reset, windowMinutes: minutes)
    }

    /// Re-scan changed files and aggregate. Safe to call often; unchanged files are cached.
    func snapshot(now: Date = Date()) -> CodexSnapshot {
        queue.sync {
            var snap = CodexSnapshot()
            guard let root = Self.home else { return snap }
            snap.found = true
            let files = sessionFiles(root)
            snap.fileCount = files.count
            var changed = false
            var seen = Set<String>()
            for url in files {
                let path = url.path
                seen.insert(path)
                let attrs = try? FileManager.default.attributesOfItem(atPath: path)
                let size = (attrs?[.size] as? NSNumber)?.intValue ?? 0
                let mtime = (attrs?[.modificationDate] as? Date)?.timeIntervalSince1970 ?? 0
                if let c = cache[path], c.size == size, c.mtime == mtime { continue }
                guard size < 200_000_000, let data = try? Data(contentsOf: url),
                      let text = String(data: data, encoding: .utf8) else { continue }
                let r = Self.parse(text)
                cache[path] = CodexFileCache(planType: r.plan, size: size, mtime: mtime, days: r.days, windows: r.windows, windowsAt: r.windowsAt)
                changed = true
            }
            for k in cache.keys where !seen.contains(k) { cache.removeValue(forKey: k); changed = true }
            if changed, let data = try? JSONEncoder().encode(cache) { try? data.write(to: cacheURL, options: .atomic) }

            let today = Self.localDay(now)
            let weekStart = Self.localDay(now.addingTimeInterval(-6 * 86400))
            let monthPrefix = String(today.prefix(7))
            var latestAt: Double = 0
            for c in cache.values {
                for (day, models) in c.days {
                    let sum = models.values.reduce(0) { $0 + $1.total }
                    snap.all += sum
                    snap.days[day, default: 0] += sum
                    if day == today {
                        snap.today += sum
                        for (m, t) in models { snap.byModelToday[m, default: 0] += t.total }
                    }
                    if day >= weekStart && day <= today { snap.week += sum }
                    if day.hasPrefix(monthPrefix) { snap.month += sum }
                }
                if c.windowsAt > latestAt, !c.windows.isEmpty { latestAt = c.windowsAt; snap.windows = c.windows; snap.planType = c.planType ?? snap.planType }
            }
            return snap
        }
    }
}
