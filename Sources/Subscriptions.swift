// Subscriptions found on this Mac, without any keys:
//  - cswap (claude-swap): every Claude account's 5h / 7d / spend / per-model usage via `cswap list --json`
//  - Claude Code: signed-in account and plan from ~/.claude.json, token usage from ~/.claude/projects/**/*.jsonl
//  - Codex (ChatGPT plan): plan type and usage windows from ~/.codex session logs (see Codex.swift)
import Foundation

// MARK: - cswap (claude-swap) `list --json`, schemaVersion 1. All fields optional: the contract is additive.

struct SubWindow: Codable, Equatable {
    var name: String?
    var pct: Double?
    var resetsAt: String?
    var expectedPct: Double?
    var aheadOfPace: Bool?
    var willLastToReset: Bool?
    var resetDate: Date? { resetsAt.flatMap { JSONPath.date($0) } }
}

struct SubSpend: Codable, Equatable {
    var used: Double?
    var limit: Double?
    var pct: Double?
    var currency: String?
    var resetsAt: String?
}

struct SubUsage: Codable, Equatable {
    var fiveHour: SubWindow?
    var sevenDay: SubWindow?
    var spend: SubSpend?
    var scoped: [SubWindow]?
}

struct CswapAccount: Codable, Equatable, Identifiable {
    var number: Int
    var email: String
    var alias: String?
    var organizationName: String?
    var isOrganization: Bool?
    var active: Bool?
    var usageStatus: String?
    var usage: SubUsage?
    var lastGoodUsage: SubUsage?
    var usageAgeSeconds: Double?
    var lastGoodAgeSeconds: Double?
    var usageError: String?
    var disabled: Bool?
    var loginExpiresAt: String?
    var id: Int { number }

    /// Fresh usage if available, otherwise the last known reading.
    var shownUsage: SubUsage? { usage ?? lastGoodUsage }
    var isStale: Bool { usage == nil && lastGoodUsage != nil }
    var label: String { alias.map { "\($0) · \(email)" } ?? email }

    var statusText: String {
        switch usageStatus ?? "" {
        case "ok": return "正常"
        case "token_expired": return "令牌过期"
        case "relogin_required": return "需要重新登录"
        case "rate_limited": return "已达上限"
        case "unavailable": return "暂时取不到" + (usageError.map { "（\($0)）" } ?? "")
        case "": return "—"
        default: return usageStatus ?? "—"
        }
    }
}

struct CswapList: Codable, Equatable {
    struct Failure: Codable, Equatable { var type: String?; var message: String? }
    var schemaVersion: Int?
    var activeAccountNumber: Int?
    var accounts: [CswapAccount]?
    var error: Failure?
}

enum Cswap {
    static let candidates = [NSHomeDirectory() + "/.local/bin/cswap", "/opt/homebrew/bin/cswap", "/usr/local/bin/cswap",
                             NSHomeDirectory() + "/.cargo/bin/cswap", NSHomeDirectory() + "/Library/Python/3.12/bin/cswap",
                             NSHomeDirectory() + "/Library/Python/3.13/bin/cswap"]

    /// Find the cswap executable: explicit override, common install locations, then the login shell's PATH.
    static func locate(override: String = "") -> String? {
        let fm = FileManager.default
        if !override.isEmpty { return fm.isExecutableFile(atPath: override) ? override : nil }
        if let p = candidates.first(where: { fm.isExecutableFile(atPath: $0) }) { return p }
        let out = run("/bin/zsh", ["-lc", "command -v cswap"], timeout: 8)?.stdout.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return out.hasPrefix("/") && fm.isExecutableFile(atPath: out) ? out : nil
    }

    static func decode(_ data: Data) -> CswapList? { try? JSONDecoder().decode(CswapList.self, from: data) }

    /// Runs `cswap list --json`. cswap caches usage per account and backs off on its own,
    /// so calling it every few minutes does not add API traffic beyond its own polling policy.
    static func list(path: String) -> (CswapList?, String?) {
        guard let r = run(path, ["list", "--json"], timeout: 45) else { return (nil, "cswap 没有响应（超时）") }
        guard let parsed = decode(Data(r.stdout.utf8)) else {
            let err = r.stderr.split(separator: "\n").last.map(String.init) ?? "退出码 \(r.status)"
            return (nil, "无法解析 cswap 输出：" + err)
        }
        if let e = parsed.error { return (parsed, "cswap 报错：" + (e.message ?? e.type ?? "未知错误")) }
        return (parsed, nil)
    }

    struct RunResult { var stdout: String; var stderr: String; var status: Int32 }

    static func run(_ exe: String, _ args: [String], timeout: TimeInterval) -> RunResult? {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: exe)
        p.arguments = args
        var env = ProcessInfo.processInfo.environment
        let extra = [NSHomeDirectory() + "/.local/bin", "/opt/homebrew/bin", "/usr/local/bin"]
        env["PATH"] = (extra + [(env["PATH"] ?? "/usr/bin:/bin")]).joined(separator: ":")
        env["NO_COLOR"] = "1"
        p.environment = env
        let out = Pipe(), err = Pipe()
        p.standardOutput = out; p.standardError = err; p.standardInput = FileHandle.nullDevice
        var outData = Data(), errData = Data()
        let group = DispatchGroup()
        group.enter(); DispatchQueue.global().async { outData = out.fileHandleForReading.readDataToEndOfFile(); group.leave() }
        group.enter(); DispatchQueue.global().async { errData = err.fileHandleForReading.readDataToEndOfFile(); group.leave() }
        do { try p.run() } catch { return nil }
        let deadline = Date().addingTimeInterval(timeout)
        while p.isRunning && Date() < deadline { Thread.sleep(forTimeInterval: 0.1) }
        if p.isRunning { p.terminate(); return nil }
        group.wait()
        return RunResult(stdout: String(decoding: outData, as: UTF8.self), stderr: String(decoding: errData, as: UTF8.self),
                         status: p.terminationStatus)
    }
}

// MARK: - Claude Code (local files only)

struct ClaudeAccountInfo: Equatable {
    var email: String?
    var name: String?
    var organizationName: String?
    var organizationType: String?
    var billingType: String?
    var rateLimitTier: String?
    var extraUsage: Bool?

    /// Human-readable plan, e.g. "Max 20x", "Pro", "Team".
    var plan: String {
        let tier = (rateLimitTier ?? "").lowercased()
        let type = (organizationType ?? "").lowercased()
        var base: String
        if type.contains("max") || tier.contains("max") { base = "Max" }
        else if type.contains("pro") || tier.contains("pro") { base = "Pro" }
        else if type.contains("team") { base = "Team" }
        else if type.contains("enterprise") { base = "Enterprise" }
        else if !type.isEmpty { base = organizationType! }
        else { base = "未知" }
        if let r = tier.range(of: #"(\d+)x"#, options: .regularExpression) { base += " " + tier[r] }
        return base
    }
}

struct ClaudeTokens: Codable, Equatable {
    var input = 0, output = 0, cacheWrite = 0, cacheRead = 0, messages = 0
    var total: Int { input + output + cacheWrite + cacheRead }
    static func + (a: ClaudeTokens, b: ClaudeTokens) -> ClaudeTokens {
        ClaudeTokens(input: a.input + b.input, output: a.output + b.output, cacheWrite: a.cacheWrite + b.cacheWrite,
                     cacheRead: a.cacheRead + b.cacheRead, messages: a.messages + b.messages)
    }
}

struct ClaudeFileCache: Codable {
    var size: Int
    var mtime: Double
    var days: [String: [String: ClaudeTokens]]
    var ids: [String]
}

struct ClaudeSnapshot: Equatable {
    var found = false
    var account: ClaudeAccountInfo?
    var today = ClaudeTokens(), week = ClaudeTokens(), month = ClaudeTokens(), all = ClaudeTokens()
    var byModelToday: [String: Int] = [:]
    var days: [String: Int] = [:]
    var fileCount = 0
}

final class ClaudeLocal {
    static let shared = ClaudeLocal()
    private var cache: [String: ClaudeFileCache] = [:]
    private let queue = DispatchQueue(label: "claude-local")
    private var cacheURL: URL { Store.dir.appendingPathComponent("claude-cache.json") }

    init() {
        if let d = try? Data(contentsOf: cacheURL), let c = try? JSONDecoder().decode([String: ClaudeFileCache].self, from: d) { cache = c }
    }

    static var home: URL {
        let env = ProcessInfo.processInfo.environment["CLAUDE_CONFIG_DIR"] ?? ""
        return URL(fileURLWithPath: env.isEmpty ? NSHomeDirectory() + "/.claude" : env)
    }

    /// Reads only non-secret profile fields from ~/.claude.json (no tokens live there).
    static func account() -> ClaudeAccountInfo? {
        let url = URL(fileURLWithPath: NSHomeDirectory() + "/.claude.json")
        guard let d = try? Data(contentsOf: url),
              let j = try? JSONSerialization.jsonObject(with: d) as? [String: Any],
              let oa = j["oauthAccount"] as? [String: Any] else { return nil }
        return ClaudeAccountInfo(email: oa["emailAddress"] as? String, name: oa["displayName"] as? String,
                                 organizationName: oa["organizationName"] as? String,
                                 organizationType: oa["organizationType"] as? String,
                                 billingType: oa["billingType"] as? String,
                                 rateLimitTier: (oa["userRateLimitTier"] as? String) ?? (oa["organizationRateLimitTier"] as? String),
                                 extraUsage: oa["hasExtraUsageEnabled"] as? Bool)
    }

    /// Parse assistant messages with usage; duplicates (same message id + request id) count once.
    static func parse(_ text: String, seen: inout Set<String>) -> [String: [String: ClaudeTokens]] {
        var days: [String: [String: ClaudeTokens]] = [:]
        let iso = ISO8601DateFormatter(); iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let iso2 = ISO8601DateFormatter()
        for line in text.split(separator: "\n", omittingEmptySubsequences: true) where line.contains("\"usage\"") {
            guard let o = try? JSONSerialization.jsonObject(with: Data(line.utf8)) as? [String: Any],
                  o["type"] as? String == "assistant",
                  let msg = o["message"] as? [String: Any], let u = msg["usage"] as? [String: Any] else { continue }
            let key = "\(msg["id"] as? String ?? "")|\(o["requestId"] as? String ?? "")"
            if key != "|" { if seen.contains(key) { continue }; seen.insert(key) }
            let ts = o["timestamp"] as? String ?? ""
            guard let date = iso.date(from: ts) ?? iso2.date(from: ts) else { continue }
            func n(_ k: String) -> Int { Int(JSONPath.toNumber(u[k]) ?? 0) }
            let t = ClaudeTokens(input: n("input_tokens"), output: n("output_tokens"), cacheWrite: n("cache_creation_input_tokens"),
                                 cacheRead: n("cache_read_input_tokens"), messages: 1)
            let model = (msg["model"] as? String) ?? "claude"
            if model == "<synthetic>" { continue }
            let day = CodexStats.localDay(date)
            days[day, default: [:]][model, default: ClaudeTokens()] = days[day, default: [:]][model, default: ClaudeTokens()] + t
        }
        return days
    }

    func snapshot(now: Date = Date()) -> ClaudeSnapshot {
        queue.sync {
            var snap = ClaudeSnapshot()
            snap.account = Self.account()
            let projects = Self.home.appendingPathComponent("projects")
            guard FileManager.default.fileExists(atPath: Self.home.path) else { return snap }
            snap.found = true
            var files: [URL] = []
            if let e = FileManager.default.enumerator(at: projects, includingPropertiesForKeys: nil) {
                for case let u as URL in e where u.pathExtension == "jsonl" { files.append(u) }
            }
            snap.fileCount = files.count
            var changed = false
            var live = Set<String>()
            for url in files {
                let path = url.path
                live.insert(path)
                let attrs = try? FileManager.default.attributesOfItem(atPath: path)
                let size = (attrs?[.size] as? NSNumber)?.intValue ?? 0
                let mtime = (attrs?[.modificationDate] as? Date)?.timeIntervalSince1970 ?? 0
                if let c = cache[path], c.size == size, c.mtime == mtime { continue }
                guard size < 300_000_000, let d = try? Data(contentsOf: url) else { continue }
                var seen = Set<String>()
                let days = Self.parse(String(decoding: d, as: UTF8.self), seen: &seen)
                cache[path] = ClaudeFileCache(size: size, mtime: mtime, days: days, ids: [])
                changed = true
            }
            for k in cache.keys where !live.contains(k) { cache.removeValue(forKey: k); changed = true }
            if changed, let d = try? JSONEncoder().encode(cache) { try? d.write(to: cacheURL, options: .atomic) }

            let today = CodexStats.localDay(now)
            let weekStart = CodexStats.localDay(now.addingTimeInterval(-6 * 86400))
            let monthPrefix = String(today.prefix(7))
            for c in cache.values {
                for (day, models) in c.days {
                    let sum = models.values.reduce(ClaudeTokens(), +)
                    snap.all = snap.all + sum
                    snap.days[day, default: 0] += sum.total
                    if day == today {
                        snap.today = snap.today + sum
                        for (m, t) in models { snap.byModelToday[m, default: 0] += t.total }
                    }
                    if day >= weekStart && day <= today { snap.week = snap.week + sum }
                    if day.hasPrefix(monthPrefix) { snap.month = snap.month + sum }
                }
            }
            return snap
        }
    }
}

// MARK: - API costs with organization Admin keys

enum CostAPI {
    struct Costs: Equatable { var today: Double; var month: Double }

    static func monthStartUTC(_ now: Date = Date()) -> Date {
        var cal = Calendar(identifier: .gregorian); cal.timeZone = TimeZone(identifier: "UTC")!
        return cal.date(from: cal.dateComponents([.year, .month], from: now))!
    }
    static func dayStartUTC(_ now: Date = Date()) -> Date {
        var cal = Calendar(identifier: .gregorian); cal.timeZone = TimeZone(identifier: "UTC")!
        return cal.startOfDay(for: now)
    }

    /// OpenAI: GET /v1/organization/costs (Admin key). amount.value is in dollars.
    static func parseOpenAI(_ json: Any, todayStart: Date) -> (Double, Double, String?) {
        var today = 0.0, month = 0.0
        for b in (JSONPath.get(json, "data") as? [[String: Any]] ?? []) {
            let start = JSONPath.toNumber(b["start_time"]) ?? 0
            let sum = (b["results"] as? [[String: Any]] ?? []).reduce(0.0) { $0 + (JSONPath.number($1, "amount.value") ?? 0) }
            month += sum
            if start >= todayStart.timeIntervalSince1970 { today += sum }
        }
        return (today, month, JSONPath.get(json, "has_more") as? Bool == true ? JSONPath.get(json, "next_page") as? String : nil)
    }

    /// Anthropic: GET /v1/organizations/cost_report (Admin key). amount is a decimal string in cents.
    static func parseAnthropic(_ json: Any, todayStart: Date) -> (Double, Double, String?) {
        var today = 0.0, month = 0.0
        for b in (JSONPath.get(json, "data") as? [[String: Any]] ?? []) {
            let start = JSONPath.date(b["starting_at"]) ?? .distantPast
            let cents = (b["results"] as? [[String: Any]] ?? []).reduce(0.0) { $0 + (JSONPath.toNumber($1["amount"]) ?? 0) }
            month += cents / 100
            if start >= todayStart { today += cents / 100 }
        }
        return (today, month, JSONPath.get(json, "has_more") as? Bool == true ? JSONPath.get(json, "next_page") as? String : nil)
    }

    static func fetch(provider: String, key: String) async throws -> Costs {
        let now = Date()
        let start = monthStartUTC(now), todayStart = dayStartUTC(now)
        var today = 0.0, month = 0.0
        var page: String? = nil
        for _ in 0..<6 {
            var comps: URLComponents
            var req: URLRequest
            if provider == "openai_costs" {
                comps = URLComponents(string: "https://api.openai.com/v1/organization/costs")!
                comps.queryItems = [URLQueryItem(name: "start_time", value: String(Int(start.timeIntervalSince1970))),
                                    URLQueryItem(name: "bucket_width", value: "1d"), URLQueryItem(name: "limit", value: "31")]
                if let page { comps.queryItems!.append(URLQueryItem(name: "page", value: page)) }
                req = URLRequest(url: comps.url!)
                req.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
            } else {
                let f = ISO8601DateFormatter()
                comps = URLComponents(string: "https://api.anthropic.com/v1/organizations/cost_report")!
                comps.queryItems = [URLQueryItem(name: "starting_at", value: f.string(from: start)),
                                    URLQueryItem(name: "ending_at", value: f.string(from: todayStart.addingTimeInterval(86400))),
                                    URLQueryItem(name: "bucket_width", value: "1d"), URLQueryItem(name: "limit", value: "31")]
                if let page { comps.queryItems!.append(URLQueryItem(name: "page", value: page)) }
                req = URLRequest(url: comps.url!)
                req.setValue(key, forHTTPHeaderField: "x-api-key")
                req.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
                req.setValue("WhaleBalance/\(appVersion) (https://github.com/jianzhou0420/deepseek-whale-girl-mac)", forHTTPHeaderField: "User-Agent")
            }
            let json = try await VendorClient.getJSON(req)
            let r = provider == "openai_costs" ? parseOpenAI(json, todayStart: todayStart) : parseAnthropic(json, todayStart: todayStart)
            today += r.0; month += r.1
            page = r.2
            if page == nil { break }
        }
        return Costs(today: today, month: month)
    }
}

// MARK: - Combined snapshot

struct SubscriptionsSnapshot: Equatable {
    var cswapPath: String?
    var cswap: CswapList?
    var cswapError: String?
    var claude = ClaudeSnapshot()
    var codex = CodexSnapshot()
    var updatedAt: Date?

    var activeCswap: CswapAccount? {
        cswap?.accounts?.first { $0.active == true } ?? cswap?.accounts?.first { $0.number == cswap?.activeAccountNumber }
    }

    static func collect(useCswap: Bool, cswapOverride: String) -> SubscriptionsSnapshot {
        var s = SubscriptionsSnapshot()
        if useCswap, let p = Cswap.locate(override: cswapOverride) {
            s.cswapPath = p
            (s.cswap, s.cswapError) = Cswap.list(path: p)
        }
        s.claude = ClaudeLocal.shared.snapshot()
        s.codex = CodexStats.shared.snapshot()
        s.updatedAt = Date()
        return s
    }
}

func pctText(_ v: Double?) -> String { v.map { String(format: "%.0f%%", $0) } ?? "—" }

/// A compact, display-ready summary of one subscription (used by the pet's bubble).
struct SubRow {
    var name: String
    var bars: [(String, Double?)] = []
    var note = ""
    var stale = false
}
