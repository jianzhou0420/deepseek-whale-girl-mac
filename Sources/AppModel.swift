// Central app state: balance refresh, ledger, vendors, bubble queue, alerts, animations.
import AppKit
import Combine
import CryptoKit
import ServiceManagement
import SwiftUI

enum LoadState: Equatable { case idle, loading, ok, noKey, error(String) }

enum BubbleMode: Equatable {
    case hidden
    case item(index: Int, item: BubbleItem)
    case alert(kind: String, modules: [BubbleModule])
}

final class AppModel: ObservableObject {
    static let shared = AppModel()

    // Persisted
    @Published var settings: Settings {
        didSet {
            guard settings != oldValue else { return }
            scheduleSave()
            if settings.autoPlay.on != oldValue.autoPlay.on || settings.autoPlay.minMinutes != oldValue.autoPlay.minMinutes
                || settings.autoPlay.maxMinutes != oldValue.autoPlay.maxMinutes { autoPlayer.reschedule() }
        }
    }
    let autoPlayer = AutoPlayer()
    @Published var bubbleConfig: BubbleConfig { didSet { if bubbleConfig != oldValue { Store.save("bubble.json", bubbleConfig) } } }
    @Published var apiModels: [ApiModel] { didSet { if apiModels != oldValue { Store.save("api.json", apiModels) } } }
    @Published private(set) var ledger: Ledger

    // DeepSeek balance
    @Published var state: LoadState = .idle
    @Published var balance: Double?
    @Published var bonus: Double?
    @Published var recharge: Double?
    @Published var currency = "CNY"
    @Published var shownBalance: Double?
    @Published var updatedAt: Date?
    @Published var stale = false
    @Published var today: BalanceSummary?

    // Other sources
    @Published var vendorStatus: [String: VendorStatus] = [:]
    @Published var codex = CodexSnapshot()
    @Published var subs = SubscriptionsSnapshot()
    @Published var subsLoading = false
    private var subsTimer: Timer?

    // Widget UI
    @Published var bubble: BubbleMode = .hidden
    @Published var pressed = false
    @Published var hovering = false
    @Published var flipped = false
    @Published var dragging = false
    @Published var roleAnim: Anim = .neutral
    @Published var roleAnimStart = Date()
    @Published var roleClip: String?          // an AI-generated clip playing instead of roleAnim
    @Published var now = Date()
    @Published var pickedLines: [String: Int] = [:]   // random-line picks per module id
    @Published var pickedImages: [String: String] = [:]

    private var saveWork: DispatchWorkItem?
    private var refreshTimer: Timer?
    private var clockTimer: Timer?
    private var bubbleCloseWork: DispatchWorkItem?
    private var animTimer: Timer?
    private var roleResetWork: DispatchWorkItem?
    private var refreshing = false
    private var lowAlerted = false
    private var budgetAlertedDay = ""
    private var lastChoice: [String: String] = [:]

    init() {
        settings = Store.load("settings.json", default: Settings())
        bubbleConfig = Store.load("bubble.json", default: BubbleConfig())
        apiModels = Store.load("api.json", default: [ApiModel]())
        ledger = Store.load("ledger.json", default: Ledger())
        today = ledger.summary(day: BeijingTime.day())
        budgetAlertedDay = UserDefaults.standard.string(forKey: "budgetAlertedDay") ?? ""
        lowAlerted = UserDefaults.standard.bool(forKey: "lowAlerted")
    }

    func start() {
        refresh(manual: false)
        restartRefreshTimer()
        clockTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            self?.now = Date()
        }
        RunLoop.main.add(clockTimer!, forMode: .common)
        refreshSubscriptions()
        restartSubsTimer()
        autoPlayer.start(self)
    }

    func restartSubsTimer() {
        subsTimer?.invalidate()
        let s = max(1, settings.subsRefreshMinutes) * 60
        subsTimer = Timer.scheduledTimer(withTimeInterval: s, repeats: true) { [weak self] _ in self?.refreshSubscriptions() }
    }

    /// Auto-detect cswap / Claude Code / Codex on this Mac and read their usage (no keys involved).
    func refreshSubscriptions() {
        guard settings.subsOn, !subsLoading else { return }
        subsLoading = true
        let useCswap = settings.subsCswapOn, path = settings.cswapPath
        DispatchQueue.global(qos: .utility).async {
            let s = SubscriptionsSnapshot.collect(useCswap: useCswap, cswapOverride: path)
            DispatchQueue.main.async {
                self.subs = s
                self.codex = s.codex
                self.subsLoading = false
            }
        }
    }

    func restartRefreshTimer() {
        refreshTimer?.invalidate()
        let s = max(15, settings.refreshSeconds)
        refreshTimer = Timer.scheduledTimer(withTimeInterval: s, repeats: true) { [weak self] _ in self?.refresh(manual: false) }
    }

    private func scheduleSave() {
        saveWork?.cancel()
        let w = DispatchWorkItem { [weak self] in if let s = self?.settings { Store.save("settings.json", s) } }
        saveWork = w
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4, execute: w)
    }

    // MARK: - Refresh

    var deepseekKey: String? { Keychain.get("DEEPSEEK_API_KEY") }

    /// The ledger is split per API key (a hash of the key), like the original "per-key books".
    private func scope(for key: String) -> String {
        let h = SHA256.hash(data: Data(key.utf8))
        return "key_" + h.map { String(format: "%02x", $0) }.joined().prefix(24)
    }

    func refresh(manual: Bool) {
        guard !refreshing else { return }
        refreshing = true
        if manual || balance == nil { state = .loading }
        if manual { playRole(.think, for: 30) }
        let key = deepseekKey
        let models = apiModels
        Task {
            var result: Result<VendorClient.DeepSeekBalance, Error>? = nil
            if let key, !key.isEmpty {
                do { result = .success(try await VendorClient.fetchDeepSeek(key: key)) }
                catch { result = .failure(error) }
            }
            var statuses: [String: VendorStatus] = [:]
            await withTaskGroup(of: (String, VendorStatus).self) { g in
                for m in models where m.template?.kind != .codex {
                    let k = Keychain.get(m.keyRef)
                    g.addTask { (m.id, await VendorClient.fetch(model: m, key: k)) }
                }
                for await (id, st) in g { statuses[id] = st }
            }
            let codexSnap = models.contains { $0.provider == "codex" } || bubbleUsesCodex ? CodexStats.shared.snapshot() : CodexSnapshot()
            let fetched = result
            let fetchedStatuses = statuses
            await MainActor.run {
                self.apply(fetched, key: key, manual: manual)
                self.applyVendors(fetchedStatuses)
                self.codex = codexSnap
                self.refreshing = false
            }
        }
    }

    private var bubbleUsesCodex: Bool {
        func uses(_ it: BubbleItem) -> Bool { it.modules.contains { $0.type == .codex } || it.options.contains { uses($0.item) } }
        return bubbleConfig.items.contains(where: uses)
    }

    private func apply(_ result: Result<VendorClient.DeepSeekBalance, Error>?, key: String?, manual: Bool) {
        guard let result, let key else {
            state = .noKey
            stopRoleSoon()
            return
        }
        switch result {
        case .success(let b):
            let old = balance
            balance = b.total; bonus = b.bonus; recharge = b.recharge; currency = b.currency
            updatedAt = Date(); stale = false; state = .ok
            let drop = ledger.observe(balance: b.total, currency: b.currency, scope: scope(for: key), model: "DeepSeek")
            Store.save("ledger.json", ledger)
            today = ledger.summary(day: BeijingTime.day())
            let changed = old != nil && abs((old ?? 0) - b.total) > 0.000001
            if old == nil { shownBalance = b.total }
            else if changed { animateBalance(from: old!, to: b.total) }
            if changed && !manual && settings.bubbleOn, case .hidden = bubble {
                showItem(0, autoClose: 3)
            }
            if changed { playRole(b.total > (old ?? 0) ? .cheer : .work, for: 2) } else { stopRoleSoon() }
            _ = drop
            checkAlerts()
        case .failure(let e):
            let err = e as? VendorError
            if err?.isTransient == true, balance != nil {
                stale = true; state = .ok          // keep showing the last balance quietly
            } else {
                state = .error((e as? LocalizedError)?.errorDescription ?? e.localizedDescription)
            }
            stopRoleSoon()
        }
    }

    private func applyVendors(_ statuses: [String: VendorStatus]) {
        for (id, var st) in statuses {
            if st.error != nil, let prev = vendorStatus[id], prev.balance != nil || !prev.windows.isEmpty {
                st.balance = prev.balance; st.windows = prev.windows; st.stale = true
            }
            vendorStatus[id] = st
            if let c = st.costToday, st.error == nil { vendorToday[id] = c }
            if let m = apiModels.first(where: { $0.id == id }), let b = st.balance, st.error == nil {
                vendorLedgerObserve(model: m, balance: b, currency: st.currency)
            }
        }
        vendorStatus = vendorStatus.filter { id, _ in apiModels.contains { $0.id == id } }
        checkVendorAlerts()
    }

    // MARK: - Per-vendor "today used" (observed balance drops)

    @Published var vendorToday: [String: Double] = UserDefaults.standard.dictionary(forKey: "vendorToday") as? [String: Double] ?? [:]
    private var vendorLast: [String: Double] = UserDefaults.standard.dictionary(forKey: "vendorLast") as? [String: Double] ?? [:]
    private var vendorDay: [String: String] = UserDefaults.standard.dictionary(forKey: "vendorDay") as? [String: String] ?? [:]

    private func vendorLedgerObserve(model: ApiModel, balance: Double, currency: String) {
        let day = BeijingTime.day()
        let id = model.id
        if vendorDay[id] != day { vendorDay[id] = day; vendorToday[id] = 0 }
        if let last = vendorLast[id], balance < last {
            let drop = last - balance
            vendorToday[id, default: 0] += drop
            ledger.events.append(UsageEvent(ts: Date().timeIntervalSince1970 * 1000, day: day, model: model.name, cost: drop, tokens: 0))
            Store.save("ledger.json", ledger)
        }
        vendorLast[id] = balance
        UserDefaults.standard.set(vendorToday, forKey: "vendorToday")
        UserDefaults.standard.set(vendorLast, forKey: "vendorLast")
        UserDefaults.standard.set(vendorDay, forKey: "vendorDay")
    }

    // MARK: - Ledger editing

    func reconcile(day: String, credits: String, otherDebits: String, revision: String, confirmed: Bool, reset: Bool) throws {
        var l = ledger
        _ = try l.reconcile(day: day, credits: credits, otherDebits: otherDebits, revision: revision, confirmed: confirmed, reset: reset)
        ledger = l
        Store.save("ledger.json", ledger)
        today = ledger.summary(day: BeijingTime.day())
    }

    // MARK: - Balance number animation (700 ms, ease-out cubic)

    private func animateBalance(from: Double, to: Double) {
        animTimer?.invalidate()
        let start = Date()
        shownBalance = from
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            guard let self else { return }
            self.animTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60, repeats: true) { [weak self] t in
                guard let self else { t.invalidate(); return }
                let p = min(1, Date().timeIntervalSince(start.addingTimeInterval(0.3)) / 0.7)
                let e = 1 - pow(1 - p, 3)
                self.shownBalance = from + (to - from) * e
                if p >= 1 { t.invalidate(); self.shownBalance = to }
            }
        }
    }

    // MARK: - Character animation

    var lowBalance: Bool {
        guard settings.lowAlert.on, let b = balance else { return false }
        return b < settings.lowAlert.threshold
    }

    var idleAnim: Anim { lowBalance ? .sulk : .neutral }

    func playRole(_ a: Anim, for seconds: Double) {
        roleClip = nil
        roleAnim = a; roleAnimStart = Date()
        roleResetWork?.cancel()
        let w = DispatchWorkItem { [weak self] in self?.roleAnim = self?.idleAnim ?? .neutral }
        roleResetWork = w
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds, execute: w)
    }
    /// Play an AI-generated clip for a few loops (about 4 seconds), then return to idle. Returns the duration.
    @discardableResult
    func playClip(_ id: String) -> Double {
        guard let clip = Clips.shared.clip(id) else { return 0 }
        let loops = max(2, Int((4 / clip.loopSeconds).rounded()))
        roleClip = id; roleAnimStart = Date()
        roleResetWork?.cancel()
        let w = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.roleClip = nil; self.roleAnim = self.idleAnim
        }
        roleResetWork = w
        DispatchQueue.main.asyncAfter(deadline: .now() + Double(loops) * clip.loopSeconds, execute: w)
        return Double(loops) * clip.loopSeconds
    }

    private func stopRoleSoon() {
        if roleAnim.row == Anim.think.row { playRole(idleAnim, for: 0.01) }
    }

    // MARK: - Bubble state machine

    func tapCharacter() {
        refresh(manual: true)
        guard settings.bubbleOn else { playRole(.wave, for: 1.5); return }
        switch bubble {
        case .hidden: showItem(0)
        case .alert: showItem(0)
        case .item(let i, _): bubbleConfig.advanceOnTap ? advance(from: i) : showItem(0)
        }
    }

    func tapBubble() {
        switch bubble {
        case .hidden: break
        case .alert: hideBubble()
        case .item(let i, _): advance(from: i)
        }
    }

    private func advance(from i: Int) {
        if i + 1 < bubbleConfig.items.count { showItem(i + 1) } else { hideBubble() }
    }

    func showItem(_ index: Int, autoClose: Double? = nil) {
        guard index < bubbleConfig.items.count else { hideBubble(); return }
        let raw = bubbleConfig.items[index]
        let item = raw.resolved(avoid: lastChoice[raw.id])
        lastChoice[raw.id] = item.id
        pickRandom(in: item.modules)
        withAnimation(.spring(response: 0.32, dampingFraction: 0.72)) { bubble = .item(index: index, item: item) }
        scheduleClose(autoClose ?? settings.bubbleCloseSec)
    }

    /// A one-line speech bubble that goes with a small action (no sound, no role change).
    func showSpeech(_ text: String, seconds: Double) {
        let modules = [BubbleDefaults.text(text, size: 8)]
        withAnimation(.spring(response: 0.32, dampingFraction: 0.72)) { bubble = .alert(kind: "speech", modules: modules) }
        scheduleClose(seconds)
    }

    var bubbleIsHidden: Bool { if case .hidden = bubble { return true }; return false }

    func showAlert(kind: String, modules: [BubbleModule], closeSec: Double, role: Anim? = nil, sound: Bool = true) {
        pickRandom(in: modules)
        withAnimation(.spring(response: 0.32, dampingFraction: 0.72)) { bubble = .alert(kind: kind, modules: modules) }
        scheduleClose(closeSec)
        playRole(role ?? (kind == "low" ? .sulk : .panic), for: 3)
        if sound, settings.alertSoundOn { SoundPlayer.shared.play(settings.alertSound, volume: settings.alertVolume ?? settings.volume) }
    }

    func hideBubble() {
        bubbleCloseWork?.cancel()
        withAnimation(.easeOut(duration: 0.18)) { bubble = .hidden }
    }

    private func scheduleClose(_ seconds: Double) {
        bubbleCloseWork?.cancel()
        guard seconds > 0 else { return }
        let w = DispatchWorkItem { [weak self] in self?.hideBubble() }
        bubbleCloseWork = w
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds, execute: w)
    }

    private func pickRandom(in modules: [BubbleModule]) {
        for m in modules {
            if m.type == .random, !m.lines.isEmpty {
                let total = m.lines.reduce(0) { $0 + max(0.0001, $1.w) }
                var pick = 0
                for _ in 0..<6 {
                    var r = Double.random(in: 0..<total)
                    for (i, l) in m.lines.enumerated() { r -= max(0.0001, l.w); if r < 0 { pick = i; break } }
                    if pick != pickedLines[m.id] || m.lines.count == 1 { break }
                }
                pickedLines[m.id] = pick
            }
            if m.type == .randomImage, !m.imgs.isEmpty {
                let total = m.imgs.reduce(0) { $0 + max(0.0001, $1.w) }
                var pick = m.imgs[0].imgId
                for _ in 0..<6 {
                    var r = Double.random(in: 0..<total)
                    for im in m.imgs { r -= max(0.0001, im.w); if r < 0 { pick = im.imgId; break } }
                    if pick != pickedImages[m.id] || m.imgs.count == 1 { break }
                }
                pickedImages[m.id] = pick
            }
        }
    }

    // MARK: - Alerts

    private func checkAlerts() {
        if let b = balance, settings.lowAlert.on {
            if b < settings.lowAlert.threshold {
                if !lowAlerted {
                    lowAlerted = true
                    showAlert(kind: "low", modules: settings.lowAlert.modules, closeSec: settings.lowAlert.closeSec)
                }
            } else { lowAlerted = false }
            UserDefaults.standard.set(lowAlerted, forKey: "lowAlerted")
        }
        let day = BeijingTime.day()
        if settings.budgetAlert.on, let t = today, t.amount >= settings.budgetAlert.threshold, budgetAlertedDay != day {
            budgetAlertedDay = day
            UserDefaults.standard.set(day, forKey: "budgetAlertedDay")
            showAlert(kind: "budget", modules: settings.budgetAlert.modules, closeSec: settings.budgetAlert.closeSec)
        }
    }

    private var vendorAlerted: Set<String> = []
    private func checkVendorAlerts() {
        for m in apiModels {
            guard let st = vendorStatus[m.id] else { continue }
            if m.lowBalanceOn, let b = st.balance {
                let key = "low-" + m.id
                if b < m.lowBalance {
                    if !vendorAlerted.contains(key) {
                        vendorAlerted.insert(key)
                        showAlert(kind: "vendor", modules: [BubbleDefaults.text("\(m.name) 余额不足", size: 6),
                                                            BubbleDefaults.text(Money.format(b, currency: st.currency), size: 10, rgb: "rouge")], closeSec: 0)
                    }
                } else { vendorAlerted.remove(key) }
            }
            if m.budgetOn, let used = vendorToday[m.id], used >= m.budget {
                let key = "budget-" + m.id + "-" + BeijingTime.day()
                if !vendorAlerted.contains(key) {
                    vendorAlerted.insert(key)
                    showAlert(kind: "vendor", modules: [BubbleDefaults.text("\(m.name) 今日已用", size: 6),
                                                        BubbleDefaults.text(Money.format(used, currency: st.currency), size: 10, rgb: "rouge"),
                                                        BubbleDefaults.text("超过预算啦", size: 6)], closeSec: 0)
                }
            }
        }
    }

    // MARK: - Text values for bubble modules

    func amountText(_ v: Double?) -> String {
        switch state {
        case .noKey where balance == nil: return "未设置密钥"
        case .loading where balance == nil: return "…"
        case .error where balance == nil: return "—"
        default: return Money.format(v, currency: currency)
        }
    }

    var todayText: String {
        guard let t = today else { return "--" }
        return Money.format(t.amount, currency: t.currency)
    }

    func substitute(_ s: String, module m: BubbleModule? = nil) -> String {
        guard s.contains("{") else { return s }
        var out = s
        let peak = Pricing.isPeak(now)
        var map: [String: String] = [
            "{balance_ds}": amountText(shownBalance ?? balance),
            "{bonus_ds}": bonus.map { Money.format($0, currency: currency) } ?? "—",
            "{recharge_ds}": recharge.map { Money.format($0, currency: currency) } ?? "—",
            "{expense_ds}": todayText,
            "{status}": Pricing.statusText(Pricing.Style(rawValue: m?.peakStyle ?? "default") ?? .standard, peak: peak),
            "{countdown}": Pricing.countdown(now),
            "{below}": String(format: "%.2f", settings.lowAlert.threshold),
            "{amount}": String(format: "%.2f", settings.budgetAlert.threshold),
            "{codex_today}": CodexStats.formatTokens(codex.today),
            "{codex_week}": CodexStats.formatTokens(codex.week),
            "{codex_month}": CodexStats.formatTokens(codex.month),
        ]
        if let m, !m.modelId.isEmpty, let model = apiModels.first(where: { $0.id == m.modelId }) {
            let st = vendorStatus[model.id]
            map["{name}"] = model.name
            map["{balance}"] = st?.balance.map { Money.format($0, currency: st!.currency) } ?? (st?.error != nil ? "出错" : "—")
            map["{today}"] = vendorToday[model.id].map { Money.format($0, currency: model.currency) } ?? "—"
            map["{cost_today}"] = st?.costToday.map { Money.format($0, currency: "USD") } ?? "—"
            map["{cost_month}"] = st?.costMonth.map { Money.format($0, currency: "USD") } ?? "—"
            let wins = (st?.windows ?? []).filter { m.window.isEmpty || $0.key == m.window }
            map["{quota}"] = wins.isEmpty ? manualQuotaText(model) : wins.map { w in
                "\(w.label) 已用 \(w.usedPct.map { String(format: "%.0f%%", $0) } ?? "—")" + (w.resetAt.map { " · " + Self.shortReset($0) } ?? "")
            }.joined(separator: " | ")
            let q = quotaNumbers(model)
            map["{quota_used}"] = q.used
            map["{quota_left}"] = q.left
            map["{quota_total}"] = q.total
            map["{quota_reset}"] = wins.first?.resetAt.map { Self.shortReset($0) } ?? "—"
        }
        if out.contains("{sub_") { for (k, v) in subscriptionValues(m) { map[k] = v } }
        for (k, v) in map where out.contains(k) { out = out.replacingOccurrences(of: k, with: v) }
        return out
    }

    static func shortReset(_ d: Date) -> String {
        let s = Int(max(0, d.timeIntervalSinceNow))
        if s >= 86400 { return "\(s / 86400)天后重置" }
        if s >= 3600 { return "\(s / 3600)小时\((s % 3600) / 60)分后重置" }
        return "\(max(1, s / 60))分钟后重置"
    }

    func quotaUsed(_ m: ApiModel) -> Double {
        if m.quota.source == "codex" {
            switch m.quota.reset {
            case "daily": return Double(codex.today)
            case "monthly": return Double(codex.month)
            default: return max(0, Double(codex.all) - m.quota.baseline)
            }
        }
        return m.quota.used
    }

    private func quotaNumbers(_ m: ApiModel) -> (used: String, left: String, total: String) {
        guard m.quota.on, m.quota.total > 0 else { return ("—", "—", "—") }
        let used = quotaUsed(m)
        let fmt: (Double) -> String = { m.quota.unit == "元" ? String(format: "%.2f", $0) : CodexStats.formatTokens(Int($0)) }
        return (fmt(used), fmt(max(0, m.quota.total - used)), fmt(m.quota.total))
    }

    private func manualQuotaText(_ m: ApiModel) -> String {
        guard m.quota.on, m.quota.total > 0 else { return "—" }
        let q = quotaNumbers(m)
        let pct = quotaUsed(m) / m.quota.total * 100
        return "已用 \(q.used)/\(q.total) (\(String(format: "%.0f%%", pct)))"
    }

    // MARK: - Status bar text

    var statusTitle: String {
        guard settings.menuBarBalance else { return "🐳" }
        guard let b = shownBalance ?? balance else { return "🐳" }
        return "🐳 " + Money.symbol(currency) + String(format: "%.2f", b)
    }

    // MARK: - Launch at login

    var launchAtLogin: Bool {
        get { SMAppService.mainApp.status == .enabled }
        set {
            do { if newValue { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() } }
            catch { NSLog("WhaleSeek: launch at login: \(error)") }
            objectWillChange.send()
        }
    }
}

// MARK: - Subscription placeholders for bubble modules

extension AppModel {
    /// Values for {sub_*} placeholders. The module's `window` field picks the source:
    /// "cswap" (active account), "cswap:<number>", "cswap:all", "claude", "codex".
    func subscriptionValues(_ m: BubbleModule?) -> [String: String] {
        let source = (m?.window ?? "").isEmpty ? defaultSubscriptionSource : m!.window
        var v: [String: String] = ["{sub_account}": "—", "{sub_plan}": "—", "{sub_5h}": "—", "{sub_7d}": "—",
                                   "{sub_spend}": "—", "{sub_reset}": "—", "{sub_tokens_today}": "—", "{sub_all}": "—"]
        func fill(_ a: CswapAccount) {
            v["{sub_account}"] = a.alias ?? a.email
            let u = a.shownUsage
            v["{sub_5h}"] = pctText(u?.fiveHour?.pct)
            v["{sub_7d}"] = pctText(u?.sevenDay?.pct)
            if let s = u?.spend, let used = s.used {
                v["{sub_spend}"] = Money.format(used, currency: s.currency ?? "USD") + (s.limit.map { " / " + Money.format($0, currency: s.currency ?? "USD") } ?? "")
            }
            v["{sub_reset}"] = u?.fiveHour?.resetDate.map { Self.shortReset($0) } ?? "—"
            v["{sub_plan}"] = a.organizationName ?? "Claude"
        }
        if source == "overview" {
            v["{sub_all}"] = subscriptionOverview.isEmpty ? "未检测到订阅" : subscriptionOverview.joined(separator: "\n")
            return v
        }
        if source == "cswap:all", let accts = subs.cswap?.accounts, !accts.isEmpty {
            v["{sub_all}"] = accts.map { a in
                let u = a.shownUsage
                return (a.active == true ? "▶ " : "") + (a.alias ?? a.email.components(separatedBy: "@").first ?? a.email)
                    + " 5h \(pctText(u?.fiveHour?.pct)) · 7d \(pctText(u?.sevenDay?.pct))"
            }.joined(separator: "\n")
            if let a = subs.activeCswap { fill(a) }
        } else if source.hasPrefix("cswap") {
            let num = Int(source.split(separator: ":").last ?? "")
            if let a = num.flatMap({ n in subs.cswap?.accounts?.first { $0.number == n } }) ?? subs.activeCswap { fill(a) }
        } else if source == "claude" {
            let c = subs.claude
            v["{sub_account}"] = c.account?.email ?? "—"
            v["{sub_plan}"] = c.account.map { "Claude " + $0.plan } ?? "—"
            v["{sub_tokens_today}"] = CodexStats.formatTokens(c.today.total)
        } else if source == "codex" {
            v["{sub_plan}"] = subs.codex.planType.map { "ChatGPT " + $0.capitalized } ?? "ChatGPT"
            v["{sub_tokens_today}"] = CodexStats.formatTokens(subs.codex.today)
            for w in subs.codex.windows {
                if w.label == "5h" { v["{sub_5h}"] = pctText(w.usedPct); v["{sub_reset}"] = w.resetAt.map { Self.shortReset($0) } ?? "—" }
                if w.label == "周" { v["{sub_7d}"] = pctText(w.usedPct) }
            }
        }
        return v
    }

    /// One row per detected subscription: every cswap account (or Claude Code), then Codex.
    var subscriptionRows: [SubRow] {
        var rows: [SubRow] = []
        guard settings.subsOn else { return rows }
        if let accts = subs.cswap?.accounts, !accts.isEmpty {
            for a in accts where a.disabled != true {
                let u = a.shownUsage
                let short = a.alias ?? a.email.components(separatedBy: "@").first ?? a.email
                let name = accts.count == 1 ? (subs.claude.account.map { "Claude \($0.plan)" } ?? short)
                    : (a.active == true ? "▶ " : "") + short
                rows.append(SubRow(name: name,
                                   bars: [("5h", u?.fiveHour?.pct), ("7d", u?.sevenDay?.pct)], stale: a.isStale))
            }
        } else if let acct = subs.claude.account {
            rows.append(SubRow(name: "Claude \(acct.plan)", note: "今日 \(CodexStats.formatTokens(subs.claude.today.total)) tokens"))
        }
        if subs.codex.found || !subs.codex.windows.isEmpty {
            let name = subs.codex.planType.map { "ChatGPT " + $0.capitalized } ?? "Codex"
            let w5 = subs.codex.windows.first { $0.label == "5h" }, w7 = subs.codex.windows.first { $0.label == "周" }
            let bars = [("5h", w5?.usedPct), ("周", w7?.usedPct)].filter { $0.1 != nil }
            if !bars.isEmpty {
                rows.append(SubRow(name: name, bars: bars))
            } else {
                rows.append(SubRow(name: name, note: "今日 \(CodexStats.formatTokens(subs.codex.today)) tokens"))
            }
        }
        return rows
    }

    var subscriptionOverview: [String] {
        subscriptionRows.map { r in
            r.bars.isEmpty ? "\(r.name)  \(r.note)" : r.name + "  " + r.bars.map { "\($0.0) \(pctText($0.1))" }.joined(separator: " · ")
        }
    }

    var defaultSubscriptionSource: String {
        if subs.cswap?.accounts?.isEmpty == false { return "cswap" }
        if subs.claude.account != nil { return "claude" }
        return "codex"
    }
}
