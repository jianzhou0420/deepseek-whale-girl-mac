// "小鲸鱼记账": today / 7 days / all records, per-entry details, model share, balance correction, Codex tokens.
import SwiftUI

struct UsageView: View {
    @ObservedObject var model: AppModel
    @State private var range = 1
    @State private var search = ""
    @State private var expanded: Set<String> = []
    @State private var correcting: CorrectDay? = nil

    struct CorrectDay: Identifiable { var id: String }

    private var todayKey: String { BeijingTime.day(model.now) }

    private var days: [String] {
        switch range {
        case 0: return [todayKey]
        case 1: return (0..<7).map { BeijingTime.offset(todayKey, -$0) }
        default: return model.ledger.allDays.reversed()
        }
    }

    private func events(_ day: String) -> [UsageEvent] {
        model.ledger.events.filter { $0.day == day }.sorted { $0.ts > $1.ts }
    }

    private var filteredDays: [String] {
        let q = search.trimmingCharacters(in: .whitespaces).lowercased()
        guard !q.isEmpty else { return days }
        return days.filter { d in d.contains(q) || events(d).contains { $0.model.lowercased().contains(q) } }
    }

    private var share: [(String, Double)] {
        let set = Set(filteredDays)
        var m: [String: Double] = [:]
        for e in model.ledger.events where set.contains(e.day) { m[e.model, default: 0] += e.cost }
        return m.sorted { $0.value > $1.value }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                if model.ledger.bookCount > 1 {
                    Label("检测到 \(model.ledger.bookCount) 个记账本（换过 API key 或币种）。不同记账本不会相加，旧本的日期标注为「历史账户」。",
                          systemImage: "books.vertical").font(.callout).foregroundStyle(.secondary)
                }
                HStack {
                    Picker("", selection: $range) { Text("今日").tag(0); Text("近 7 天").tag(1); Text("全部记录").tag(2) }
                        .pickerStyle(.segmented).frame(width: 260)
                    Spacer()
                    TextField("按日期或模型名搜索", text: $search).textFieldStyle(.roundedBorder).frame(width: 200)
                }
                if !share.isEmpty { shareView }
                VStack(spacing: 0) {
                    ForEach(filteredDays, id: \.self) { d in dayRow(d); Divider() }
                }
                .background(RoundedRectangle(cornerRadius: 10).fill(Color(nsColor: .controlBackgroundColor)))
                if model.codex.found { codexView }
                Text("今日已用由「余额下降」累计得到：只在应用运行、能取到余额时观测；充值和赠金单独记录，不会冲掉消费。一天中途才开始观测会标为「部分数据」。逐条明细保留 90 天，每日合计保留 365 天。")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            .padding(20)
        }
        .sheet(item: $correcting) { c in CorrectionSheet(model: model, day: c.id) { correcting = nil } }
    }

    private var header: some View {
        let t = model.ledger.daySummary(todayKey, now: model.now)
        return HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text("今日已用").font(.headline).foregroundStyle(.secondary)
                Text(t.source == .none ? "--" : Money.format(t.amount, currency: t.currency))
                    .font(.system(size: 34, weight: .heavy, design: .rounded)).monospacedDigit()
                Text(t.label).font(.callout).foregroundStyle(t.needsReview ? .orange : .secondary)
                if t.partialDay, let f = t.firstObservedAt {
                    Text("部分数据：从 \(Self.time(f)) 才开始观测").font(.caption).foregroundStyle(.secondary)
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 6) {
                Text("余额 " + model.amountText(model.balance)).font(.title3.weight(.semibold))
                Text(Pricing.statusText(.standard, peak: Pricing.isPeak(model.now)) + " · " + Pricing.countdown(model.now) + " 后切换")
                    .font(.callout).foregroundStyle(Pricing.isPeak(model.now) ? .red : .green)
                if t.source != .none && t.source != .otherAccount {
                    Button(t.needsReview ? "核对余额调整…" : "余额校正…") { correcting = CorrectDay(id: todayKey) }
                }
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.accentColor.opacity(0.08)))
    }

    private var shareView: some View {
        let total = share.reduce(0) { $0 + $1.1 }
        return VStack(alignment: .leading, spacing: 6) {
            Text("消费构成 · 合计 \(String(format: "%.2f", total))").font(.headline)
            ForEach(share, id: \.0) { name, v in
                HStack {
                    Text(name).frame(width: 150, alignment: .leading).lineLimit(1)
                    GeometryReader { g in
                        RoundedRectangle(cornerRadius: 3).fill(Color.accentColor.opacity(0.7))
                            .frame(width: max(2, g.size.width * CGFloat(total > 0 ? v / total : 0)))
                    }
                    .frame(height: 10)
                    Text(String(format: "%.2f", v)).monospacedDigit().frame(width: 70, alignment: .trailing)
                    Text(String(format: "%.0f%%", total > 0 ? v / total * 100 : 0)).monospacedDigit().foregroundStyle(.secondary).frame(width: 44, alignment: .trailing)
                }
            }
        }
    }

    private func dayRow(_ d: String) -> some View {
        let s = model.ledger.daySummary(d, now: model.now)
        let evs = events(d)
        let open = expanded.contains(d)
        return VStack(alignment: .leading, spacing: 0) {
            HStack {
                Image(systemName: open ? "chevron.down" : "chevron.right").foregroundStyle(.secondary).frame(width: 14)
                Text(d + " " + Self.weekday(d)).monospacedDigit()
                if d == todayKey { Text("今天").font(.caption).padding(.horizontal, 5).background(Capsule().fill(Color.accentColor.opacity(0.2))) }
                Spacer()
                Text(s.label + (s.partialDay && s.source != .none ? " · 部分数据" : "")).font(.caption).foregroundStyle(s.needsReview ? .orange : .secondary)
                Text(s.source == .none ? "--" : Money.format(s.amount, currency: s.currency)).monospacedDigit().frame(width: 100, alignment: .trailing)
            }
            .padding(.horizontal, 12).padding(.vertical, 8)
            .contentShape(Rectangle())
            .onTapGesture { if open { expanded.remove(d) } else { expanded.insert(d) } }
            if open {
                VStack(alignment: .leading, spacing: 4) {
                    if evs.isEmpty { Text("没有逐条明细").font(.caption).foregroundStyle(.secondary) }
                    ForEach(evs) { e in
                        HStack {
                            Text(Self.time(e.ts)).monospacedDigit().foregroundStyle(.secondary)
                            Text(e.model)
                            Spacer()
                            Text(String(format: "%.4f", e.cost)).monospacedDigit()
                        }
                        .font(.callout)
                    }
                    if !s.otherBooks.isEmpty {
                        Text("其它记账本：" + s.otherBooks.map { "\($0.currency) \(String(format: "%.2f", $0.amount))" }.joined(separator: "，"))
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    if model.ledger.summary(day: d) != nil {
                        Button("余额校正…") { correcting = CorrectDay(id: d) }.controlSize(.small)
                    }
                }
                .padding(.leading, 38).padding(.trailing, 12).padding(.bottom, 10)
            }
        }
    }

    private var codexView: some View {
        let c = model.codex
        let last7 = (0..<7).reversed().map { CodexStats.localDay(Date().addingTimeInterval(Double(-$0) * 86400)) }
        let maxV = max(1, last7.map { c.days[$0] ?? 0 }.max() ?? 1)
        return VStack(alignment: .leading, spacing: 8) {
            Text("Codex 本地会话").font(.headline)
            HStack(spacing: 20) {
                stat("今日", c.today); stat("近 7 天", c.week); stat("本月", c.month); stat("累计", c.all)
            }
            HStack(alignment: .bottom, spacing: 6) {
                ForEach(last7, id: \.self) { d in
                    VStack(spacing: 2) {
                        RoundedRectangle(cornerRadius: 3).fill(Color.accentColor.opacity(0.7))
                            .frame(width: 26, height: max(2, 60 * CGFloat(c.days[d] ?? 0) / CGFloat(maxV)))
                        Text(String(d.suffix(5))).font(.system(size: 9)).foregroundStyle(.secondary)
                    }
                }
            }
            ForEach(c.windows, id: \.label) { w in
                Text("\(w.label) 窗口已用 \(w.usedPct.map { String(format: "%.0f%%", $0) } ?? "—")" + (w.resetAt.map { " · " + AppModel.shortReset($0) } ?? ""))
                    .font(.callout)
            }
        }
    }

    private func stat(_ t: String, _ v: Int) -> some View {
        VStack(alignment: .leading) {
            Text(t).font(.caption).foregroundStyle(.secondary)
            Text(CodexStats.formatTokens(v)).font(.title3.weight(.semibold)).monospacedDigit()
        }
    }

    static func time(_ ms: Double) -> String {
        let f = DateFormatter(); f.dateFormat = "HH:mm:ss"
        return f.string(from: Date(timeIntervalSince1970: ms / 1000))
    }
    static func weekday(_ day: String) -> String {
        guard let d = BeijingTime.startOfDay(day) else { return "" }
        let i = BeijingTime.calendar.component(.weekday, from: d)
        return ["周日", "周一", "周二", "周三", "周四", "周五", "周六"][i - 1]
    }
}

struct CorrectionSheet: View {
    @ObservedObject var model: AppModel
    var day: String
    var done: () -> Void
    @State private var credits = ""
    @State private var otherDebits = ""
    @State private var confirmed = false
    @State private var error = ""

    var body: some View {
        let s = model.ledger.summary(day: day)
        VStack(alignment: .leading, spacing: 12) {
            Text("余额校正 · \(day)").font(.title3.bold())
            if let s {
                Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 6) {
                    GridRow { Text("统计起点余额"); Text(Money.format(s.openingBalance, currency: s.currency)).monospacedDigit() }
                    GridRow { Text("当前余额"); Text(Money.format(s.currentBalance, currency: s.currency)).monospacedDigit() }
                    GridRow { Text("观测到的下降"); Text(Money.format(s.observedDecrease, currency: s.currency)).monospacedDigit() }
                    GridRow { Text("观测到的上升"); Text(Money.format(s.observedIncrease, currency: s.currency)).monospacedDigit() }
                    GridRow { Text("当前口径"); Text(s.label + " " + Money.format(s.amount, currency: s.currency)) }
                }
                Text("余额接口只给快照、不给充值流水。请填写这段时间里实际到账的充值与赠金合计，校正后消费 = 起点余额 + 到账 − 其它扣减 − 当前余额。")
                    .font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                TextField("累计到账金额（充值 + 赠金，没有填 0）", text: $credits).textFieldStyle(.roundedBorder)
                TextField("非调用扣减（可选）", text: $otherDebits).textFieldStyle(.roundedBorder)
                Toggle("我已核对本统计区间的全部余额调整", isOn: $confirmed)
                if !error.isEmpty { Text(error).foregroundStyle(.red).font(.callout) }
                HStack {
                    if s.credits != nil {
                        Button("清除校正", role: .destructive) { apply(s, reset: true) }
                    }
                    Spacer()
                    Button("取消", action: done)
                    Button("保存校正") { apply(s, reset: false) }.keyboardShortcut(.defaultAction)
                }
            } else {
                Text("这一天不在当前记账本里，无法校正。").foregroundStyle(.secondary)
                HStack { Spacer(); Button("关闭", action: done) }
            }
        }
        .padding(20)
        .frame(width: 460)
        .onAppear {
            if let s { credits = s.credits.map { String(format: "%g", $0) } ?? ""; otherDebits = s.otherDebits.map { String(format: "%g", $0) } ?? "" }
        }
    }

    private func apply(_ s: BalanceSummary, reset: Bool) {
        do {
            try model.reconcile(day: day, credits: credits, otherDebits: otherDebits, revision: s.revision, confirmed: confirmed, reset: reset)
            done()
        } catch { self.error = (error as? LocalizedError)?.errorDescription ?? "\(error)" }
    }
}
