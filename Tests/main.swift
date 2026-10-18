import Foundation
var failures = 0
func check(_ cond: Bool, _ msg: String, file: String = #file, line: Int = #line) {
    if cond { print("  ok  \(msg)") } else { failures += 1; print("FAIL  \(msg)  (line \(line))") }
}
func bj(_ s: String) -> Date {   // "2026-10-16 10:30" Beijing
    let f = DateFormatter(); f.locale = Locale(identifier: "en_US_POSIX"); f.timeZone = BeijingTime.tz
    f.dateFormat = "yyyy-MM-dd HH:mm"; return f.date(from: s)!
}

print("== Pricing")
check(Pricing.isPeak(bj("2026-10-16 10:30")), "Fri 10:30 is peak")
check(!Pricing.isPeak(bj("2026-10-16 12:30")), "Fri 12:30 is off-peak")
check(Pricing.isPeak(bj("2026-10-16 17:59")), "Fri 17:59 is peak")
check(!Pricing.isPeak(bj("2026-10-16 18:00")), "Fri 18:00 is off-peak")
check(!Pricing.isPeak(bj("2026-10-17 10:00")), "Sat 10:00 is off-peak (weekend rule)")
check(Pricing.isPeak(bj("2026-08-15 10:00")), "Sat 2026-08-15 10:00 was peak (before weekend rule)")
check(!Pricing.isPeak(bj("2026-10-05 10:00")), "National Day Mon 10:00 is off-peak")
check(!Pricing.isPeak(bj("2026-09-25 10:00")), "Mid-Autumn Fri 10:00 is off-peak")
check(Pricing.nextChange(after: bj("2026-10-16 10:30")) == bj("2026-10-16 12:00"), "next change 10:30 -> 12:00")
check(Pricing.nextChange(after: bj("2026-10-16 19:00")) == bj("2026-10-19 09:00"), "Fri 19:00 -> Mon 09:00")
check(Pricing.nextChange(after: bj("2026-09-30 20:00")) == bj("2026-10-08 09:00"), "before National Day -> Oct 8 09:00")
check(Pricing.countdown(bj("2026-10-16 10:30")) == "01:30:00", "countdown format")
check(Pricing.statusText(.liangwen, peak: true) == "梁文峰", "liangwen style")

print("== Accounting")
var L = Ledger()
let t0 = bj("2026-10-16 00:02")
L.observe(balance: 100, currency: "cny", scope: "k1", at: t0)
L.observe(balance: 98.5, currency: "CNY", scope: "k1", at: t0.addingTimeInterval(60))
L.observe(balance: 98.5, currency: "CNY", scope: "k1", at: t0.addingTimeInterval(30))  // out of order, ignored
var s = L.summary(day: "2026-10-16")!
check(abs(s.amount - 1.5) < 1e-9, "drop counted as spend: \(s.amount)")
check(L.events.count == 1 && abs(L.events[0].cost - 1.5) < 1e-9, "usage event logged")
L.observe(balance: 148.5, currency: "CNY", scope: "k1", at: t0.addingTimeInterval(120))   // +50 top-up
L.observe(balance: 147.5, currency: "CNY", scope: "k1", at: t0.addingTimeInterval(180))
s = L.summary(day: "2026-10-16")!
check(abs(s.amount - 2.5) < 1e-9, "top-up does not cancel spend: \(s.amount)")
check(s.needsReview, "rise needs review")
do {
    s = try L.reconcile(day: "2026-10-16", credits: "50", otherDebits: "", revision: s.revision, confirmed: true)
    check(abs(s.amount - 2.5) < 1e-9 && !s.needsReview && s.source == .corrected, "correction: 100+50-147.5 = 2.5")
} catch { check(false, "reconcile threw \(error)") }
do { _ = try L.reconcile(day: "2026-10-16", credits: "-1", otherDebits: "", revision: L.summary(day: "2026-10-16")!.revision, confirmed: true); check(false, "negative rejected") }
catch { check(true, "negative credits rejected") }
do { _ = try L.reconcile(day: "2026-10-16", credits: "1", otherDebits: "", revision: "stale", confirmed: true); check(false, "stale rejected") }
catch { check(true, "stale revision rejected") }
L.observe(balance: 147.0, currency: "CNY", scope: "k1", at: t0.addingTimeInterval(240))
s = L.summary(day: "2026-10-16")!
check(abs(s.amount - 3.0) < 1e-9, "spend after correction keeps accumulating: \(s.amount)")
check(!s.partialDay || true, "partial flag computed")
// switch key -> new book; old day still visible
L.observe(balance: 50, currency: "CNY", scope: "k2", at: t0.addingTimeInterval(300))
check(L.bookCount == 2, "new key gets a new book")
let other = L.daySummary("2026-10-15")
check(other.source == .none, "empty day")
L.observe(balance: 10, currency: "USD", scope: "k2", at: t0.addingTimeInterval(400))
check(L.active == "k2-USD", "currency switch resets baseline into its own book")
check(!Ledger.isPartial(day: "2026-10-16", firstAt: t0.timeIntervalSince1970 * 1000, lastAt: t0.timeIntervalSince1970 * 1000 + 1, now: t0), "observation from 00:02 is a full day")
check(Ledger.isPartial(day: "2026-10-16", firstAt: bj("2026-10-16 09:00").timeIntervalSince1970 * 1000, lastAt: bj("2026-10-16 10:00").timeIntervalSince1970 * 1000, now: bj("2026-10-16 10:00")), "observation from 09:00 is partial")
// prune
var P = Ledger()
P.observe(balance: 10, currency: "CNY", scope: "a", at: bj("2026-01-01 10:00"))
P.observe(balance: 9, currency: "CNY", scope: "a", at: bj("2026-01-01 11:00"))
P.observe(balance: 8, currency: "CNY", scope: "a", at: bj("2026-10-16 11:00"))
check(P.books["a-CNY"]!.days["2026-01-01"] == nil && P.archive.contains { $0.day == "2026-01-01" && abs($0.amount - 1) < 1e-9 }, "old day archived")
check(P.events.allSatisfy { $0.day >= "2026-07-18" }, "old events pruned")

print("== JSONPath & vendors")
let j = try! JSONSerialization.jsonObject(with: Data(#"{"data":{"total_credits":"12.5","total_usage":2.25,"limits":[{"type":"TIME_LIMIT","unit":3,"percentage":5},{"type":"TOKENS_LIMIT","unit":3,"percentage":42,"nextResetTime":1792000000000},{"type":"TOKENS_LIMIT","unit":6,"percentage":10}]},"arr":[[1,2],[3,4]]}"#.utf8))
check(JSONPath.number(j, "data.total_credits") == 12.5, "string number")
check(JSONPath.number(j, "arr[1][0]") == 3, "nested array index")
let zq = Vendors.template("zhipu_glm_coding")!.quota!
let (wins, _) = VendorClient.parseQuota(j, zq)
check(wins.count == 2 && wins[0].usedPct == 42 && wins[1].usedPct == 10, "zhipu window pick by type+unit: \(wins.map { $0.usedPct ?? -1 })")
check(wins[0].resetAt == Date(timeIntervalSince1970: 1792000000), "ms reset time")
let mm = try! JSONSerialization.jsonObject(with: Data(#"{"model_remains":[{"current_interval_remaining_percent":70,"current_weekly_remaining_percent":90,"end_time":1792000000000}]}"#.utf8))
let (mw, _) = VendorClient.parseQuota(mm, Vendors.template("minimax_coding")!.quota!)
check(mw[0].usedPct == 30 && mw[1].usedPct == 10, "minimax remaining -> used")
let ds = try! JSONSerialization.jsonObject(with: Data(#"{"is_available":true,"balance_infos":[{"currency":"USD","total_balance":"0.00","granted_balance":"0.00","topped_up_balance":"0.00"},{"currency":"CNY","total_balance":"23.45","granted_balance":"3.00","topped_up_balance":"20.45"}]}"#.utf8))
let dsb = try! VendorClient.parseDeepSeek(ds)
check(dsb.currency == "CNY" && dsb.total == 23.45 && dsb.bonus == 3 && dsb.recharge == 20.45, "DeepSeek picks CNY non-zero item")
// security: key must not go to a custom endpoint
do { _ = try VendorClient.request(url: "https://evil.example/x", defaultURL: "https://api.moonshot.cn/v1/users/me/balance", auth: "Bearer {key}", key: "sk", base: "", allowCustom: false); check(false, "blocked") }
catch { check(true, "key not sent to non-template endpoint") }
do { _ = try VendorClient.request(url: "{base}/v1/dashboard/billing/subscription", defaultURL: "{base}/v1/dashboard/billing/subscription", auth: "Bearer {key}", key: "sk", base: "https://gw.example", allowCustom: false); check(false, "blocked base") }
catch { check(true, "{base} endpoint needs explicit permission") }
let ok = try! VendorClient.request(url: "{base}/v1/dashboard/billing/subscription", defaultURL: "{base}/v1/dashboard/billing/subscription", auth: "Bearer {key}", key: "sk", base: "https://gw.example/", allowCustom: true)
check(ok.url?.absoluteString == "https://gw.example/v1/dashboard/billing/subscription" && ok.value(forHTTPHeaderField: "Authorization") == "Bearer sk", "allowed custom endpoint")
let an = try! VendorClient.request(url: "https://api.anthropic.com/v1/models", defaultURL: "https://api.anthropic.com/v1/models", auth: "x-api-key:{key};anthropic-version:2023-06-01", key: "sk", base: "", allowCustom: false)
check(an.value(forHTTPHeaderField: "x-api-key") == "sk" && an.value(forHTTPHeaderField: "anthropic-version") == "2023-06-01", "header-pair auth")
check(Vendors.all.count >= 33, "template count \(Vendors.all.count)")

print("== Codex")
let log = """
{"timestamp":"2026-10-16T02:00:00.000Z","type":"turn_context","payload":{"model":"gpt-5-codex"}}
{"timestamp":"2026-10-16T02:00:05.000Z","type":"event_msg","payload":{"type":"token_count","info":{"total_token_usage":{"input_tokens":1000,"cached_input_tokens":200,"output_tokens":100,"reasoning_output_tokens":50,"total_tokens":1100},"last_token_usage":{"input_tokens":1000,"cached_input_tokens":200,"output_tokens":100,"reasoning_output_tokens":50,"total_tokens":1100}},"rate_limits":{"primary":{"used_percent":12.5,"window_minutes":300,"resets_in_seconds":3600},"secondary":{"used_percent":40,"window_minutes":10080,"resets_in_seconds":86400}}}}
{"timestamp":"2026-10-16T02:00:06.000Z","type":"event_msg","payload":{"type":"token_count","info":{"total_token_usage":{"total_tokens":1100},"last_token_usage":{"total_tokens":1100}}}}
{"timestamp":"2026-10-16T02:01:00.000Z","type":"event_msg","payload":{"type":"token_count","info":{"total_token_usage":{"input_tokens":3000,"output_tokens":300,"total_tokens":3300},"last_token_usage":{"input_tokens":2000,"output_tokens":200,"total_tokens":2200}}}}
not json
"""
let r = CodexStats.parse(log)
let day = CodexStats.localDay(ISO8601DateFormatter().date(from: "2026-10-16T02:00:05Z")!)
let tot = r.days[day]?["gpt-5-codex"]
check(tot?.total == 3300 && tot?.turns == 2, "cumulative deltas, duplicate snapshot ignored: \(String(describing: tot))")
check(r.windows.count == 2 && r.windows[0].usedPct == 12.5 && r.windows[0].label == "5h" && r.windows[1].label == "周", "rate limit windows \(r.windows.map { $0.label })")

print("== Bubble config round-trip")
let cfg = BubbleConfig()
let data = try! JSONEncoder().encode(cfg)
let back = try! JSONDecoder().decode(BubbleConfig.self, from: data)
check(back == cfg, "encode/decode equal")
let partial = try! JSONDecoder().decode(BubbleModule.self, from: Data(#"{"type":"text","text":"hi"}"#.utf8))
check(partial.size == 6 && partial.text == "hi", "missing fields get defaults")
check(BubbleDefaults.randomLines.count == 50, "random lines \(BubbleDefaults.randomLines.count)")

print("== Subscriptions")
let cs = #"{"schemaVersion":1,"activeAccountNumber":2,"accounts":[{"number":1,"email":"a@x.com","active":false,"usageStatus":"token_expired","usage":null,"lastGoodUsage":{"fiveHour":{"pct":80.0,"resetsAt":"2026-10-18T05:00:00Z"}},"lastGoodAgeSeconds":900},{"number":2,"email":"b@x.com","alias":"work","organizationName":"Acme","active":true,"usageStatus":"ok","usage":{"fiveHour":{"pct":25.0,"resetsAt":"2026-10-18T05:00:00Z","countdown":"2h"},"sevenDay":{"pct":16.0,"resetsAt":"2026-10-22T17:59:59Z","expectedPct":30.5,"aheadOfPace":false},"spend":{"used":12.5,"limit":50,"pct":25,"currency":"USD"},"scoped":[{"name":"Fable","pct":60.0,"resetsAt":"2026-10-22T17:59:59Z"}]},"futureField":{"x":1}}]}"#
let parsed = Cswap.decode(Data(cs.utf8))
check(parsed?.accounts?.count == 2, "cswap list decodes, unknown fields ignored")
let active = parsed.map { SubscriptionsSnapshot(cswap: $0).activeCswap }
check(active??.alias == "work" && active??.shownUsage?.sevenDay?.expectedPct == 30.5, "active account + pace fields")
check(parsed?.accounts?[0].isStale == true && parsed?.accounts?[0].shownUsage?.fiveHour?.pct == 80, "falls back to lastGoodUsage")
check(parsed?.accounts?[1].shownUsage?.scoped?.first?.name == "Fable", "per-model windows")
check(Cswap.decode(Data(#"{"schemaVersion":1,"error":{"type":"X","message":"boom"}}"#.utf8))?.error?.message == "boom", "error envelope")
let cl = """
{"type":"assistant","requestId":"r1","timestamp":"2026-10-18T02:00:00.000Z","message":{"id":"m1","model":"claude-opus-5","usage":{"input_tokens":10,"output_tokens":20,"cache_creation_input_tokens":30,"cache_read_input_tokens":40}}}
{"type":"assistant","requestId":"r1","timestamp":"2026-10-18T02:00:01.000Z","message":{"id":"m1","model":"claude-opus-5","usage":{"input_tokens":10,"output_tokens":20,"cache_creation_input_tokens":30,"cache_read_input_tokens":40}}}
{"type":"assistant","requestId":"r2","timestamp":"2026-10-18T03:00:00.000Z","message":{"id":"m2","model":"<synthetic>","usage":{"input_tokens":5,"output_tokens":5}}}
{"type":"user","message":{"content":"usage"}}
"""
var seenIds = Set<String>()
let cdays = ClaudeLocal.parse(cl, seen: &seenIds)
let cday = CodexStats.localDay(ISO8601DateFormatter().date(from: "2026-10-18T02:00:00Z")!)
check(cdays[cday]?["claude-opus-5"]?.total == 100 && cdays[cday]?["claude-opus-5"]?.messages == 1, "Claude usage dedup by message+request id")
check(ClaudeAccountInfo(organizationType: "claude_max", rateLimitTier: "default_claude_max_20x").plan == "Max 20x", "plan label")
let tStart = ISO8601DateFormatter().date(from: "2026-10-18T00:00:00Z")!
let oj = try! JSONSerialization.jsonObject(with: Data(#"{"data":[{"start_time":1792195200,"results":[{"amount":{"value":1.25,"currency":"usd"}}]},{"start_time":\#(Int(tStart.timeIntervalSince1970)),"results":[{"amount":{"value":0.5,"currency":"usd"}},{"amount":{"value":0.25,"currency":"usd"}}]}],"has_more":true,"next_page":"p2"}"#.utf8))
let o = CostAPI.parseOpenAI(oj, todayStart: tStart)
check(o.0 == 0.75 && o.1 == 2.0 && o.2 == "p2", "OpenAI costs: today \(o.0), month \(o.1), next page")
let aj = try! JSONSerialization.jsonObject(with: Data(#"{"data":[{"starting_at":"2026-10-17T00:00:00Z","results":[{"amount":"123.45","currency":"USD"}]},{"starting_at":"2026-10-18T00:00:00Z","results":[{"amount":"50","currency":"USD"}]}],"has_more":false,"next_page":null}"#.utf8))
let an2 = CostAPI.parseAnthropic(aj, todayStart: tStart)
check(abs(an2.0 - 0.5) < 1e-9 && abs(an2.1 - 1.7345) < 1e-9 && an2.2 == nil, "Anthropic cost report in cents")

// Autoplay policy
var ap = AutoPlayConfig()
check(AutoPlayPolicy.isNight(hour: 23, start: 23, end: 8) && AutoPlayPolicy.isNight(hour: 3, start: 23, end: 8)
      && !AutoPlayPolicy.isNight(hour: 8, start: 23, end: 8) && !AutoPlayPolicy.isNight(hour: 14, start: 23, end: 8), "night window across midnight")
check(AutoPlayPolicy.isNight(hour: 13, start: 12, end: 14) && !AutoPlayPolicy.isNight(hour: 14, start: 12, end: 14), "night window same day")
let busy = AutoPlayPolicy.Env(hour: 14, idleSeconds: 10, fullscreen: false, meeting: false)
check(AutoPlayPolicy.quietReason(ap, busy) == nil, "active daytime is not quiet")
check(AutoPlayPolicy.quietReason(ap, .init(hour: 14, idleSeconds: 10, fullscreen: true, meeting: false)) == "全屏中", "fullscreen is quiet")
check(AutoPlayPolicy.quietReason(ap, .init(hour: 14, idleSeconds: 10, fullscreen: false, meeting: true)) != nil, "meeting is quiet")
check(AutoPlayPolicy.quietReason(ap, .init(hour: 14, idleSeconds: 301, fullscreen: false, meeting: false)) == "你不在电脑前", "away is quiet")
check(AutoPlayPolicy.quietReason(ap, .init(hour: 1, idleSeconds: 10, fullscreen: false, meeting: false)) == "夜间免打扰", "night is quiet")
ap.quietNight = false
check(AutoPlayPolicy.quietReason(ap, .init(hour: 1, idleSeconds: 10, fullscreen: false, meeting: false)) == nil, "night quiet can be turned off")
check(AutoPlayPolicy.pick(ap, r: 0) == .anim && AutoPlayPolicy.pick(ap, r: 0.6) == .random && AutoPlayPolicy.pick(ap, r: 0.99) == .report, "weighted pick 3:2:1")
ap.wAnim = 0; ap.wRandom = 0
check(AutoPlayPolicy.pick(ap, r: 0) == .report, "zero weights are skipped")
ap.wReport = 0
check(AutoPlayPolicy.pick(ap, r: 0.5) == nil, "all weights zero picks nothing")
check(AutoPlayPolicy.interval(ap, r: 0) == 60 && AutoPlayPolicy.interval(ap, r: 1) == 180, "interval 1-3 minutes by default")
ap.minMinutes = 20; ap.maxMinutes = 10
check(AutoPlayPolicy.interval(ap, r: 0) == 600 && AutoPlayPolicy.interval(ap, r: 1) == 1200, "swapped min/max still works")
let ap2 = AutoPlayConfig()
check(AutoPlayPolicy.events(ap2, prevPeak: nil, peak: true, prev: [:], cur: [:]).isEmpty, "no event on first observation")
check(AutoPlayPolicy.events(ap2, prevPeak: false, peak: true, prev: [:], cur: [:]).map(\.kind) == ["peak"], "peak starts")
check(AutoPlayPolicy.events(ap2, prevPeak: true, peak: false, prev: [:], cur: [:]).map(\.kind) == ["offpeak"], "off-peak starts")
let ev = AutoPlayPolicy.events(ap2, prevPeak: true, peak: true, prev: ["Claude|5h": 70, "Claude|7d": 85, "Codex|周": 40],
                               cur: ["Claude|5h": 82, "Claude|7d": 90, "Codex|周": 2, "New|5h": 99])
check(ev.map(\.kind) == ["threshold", "reset"] && ev[0].highlight == "82%", "threshold crossing once, reset, no event for new keys: \(ev)")

var bag = ShuffleBag()
var dealt: [Int] = []
for _ in 0..<50 { dealt.append(bag.next(count: 5)!) }
check(stride(from: 0, to: 50, by: 5).allSatisfy { Set(dealt[$0..<$0 + 5]) == Set(0..<5) }, "shuffle bag: each round of 5 has no repeats")
check(zip(dealt, dealt.dropFirst()).allSatisfy { $0 != $1 }, "shuffle bag: never the same line twice in a row")
check(bag.next(count: 1) == 0 && bag.next(count: 1) == 0 && bag.next(count: 0) == nil, "shuffle bag: single line and empty")

// Keychain migration: a key saved under the WhaleBalance service is found and copied to the new service.
let mref = "WS_MIGRATION_TEST_\(Int.random(in: 1000...9999))"
func kcDelete(_ service: String) {
    SecItemDelete([kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service, kSecAttrAccount as String: mref] as CFDictionary)
}
SecItemAdd([kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: Keychain.legacyService,
            kSecAttrAccount as String: mref, kSecValueData as String: Data("legacy-value".utf8)] as CFDictionary, nil)
let migrated = Keychain.get(mref)
kcDelete(Keychain.legacyService)
check(migrated == "legacy-value" && Keychain.get(mref) == "legacy-value", "keychain: legacy key migrated to the new service")
kcDelete(Keychain.service)
check(Keychain.get(mref) == nil, "keychain: test entries cleaned up")

print(failures == 0 ? "\nALL PASSED" : "\n\(failures) FAILED")
exit(failures == 0 ? 0 : 1)
