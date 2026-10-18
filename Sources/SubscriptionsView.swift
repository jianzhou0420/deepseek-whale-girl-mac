// "订阅" settings tab and the usage-window summary: cswap accounts, Claude Code, Codex / ChatGPT.
import AppKit
import SwiftUI

struct UsageBar: View {
    var title: String
    var pct: Double?
    var reset: Date?
    var expected: Double? = nil
    var ahead = false
    var stale = false

    var body: some View {
        let p = min(100, max(0, pct ?? 0))
        let color: Color = p >= 90 ? .red : (p >= 70 ? .orange : .accentColor)
        HStack(spacing: 8) {
            Text(title).font(.caption.weight(.semibold)).frame(width: 64, alignment: .leading).lineLimit(1)
            GeometryReader { g in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.secondary.opacity(0.15))
                    Capsule().fill(color.opacity(stale ? 0.4 : 0.85)).frame(width: g.size.width * p / 100)
                    if let e = expected {
                        Rectangle().fill(Color.primary.opacity(0.5)).frame(width: 2).offset(x: g.size.width * min(100, e) / 100 - 1)
                    }
                }
            }
            .frame(height: 8)
            Text(pctText(pct)).font(.caption).monospacedDigit().frame(width: 40, alignment: .trailing)
            Text(reset.map { AppModel.shortReset($0) } ?? "").font(.caption2).foregroundStyle(.secondary)
                .frame(width: 112, alignment: .leading).lineLimit(1)
            if ahead { Text("超速").font(.caption2).foregroundStyle(.orange) }
        }
    }
}

struct CswapAccountCard: View {
    var a: CswapAccount
    var body: some View {
        let u = a.shownUsage
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Text("#\(a.number)").font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                Text(a.label).font(.body.weight(.medium)).lineLimit(1)
                if a.active == true { badge("当前", .green) }
                if a.disabled == true { badge("已停用", .gray) }
                if a.isStale { badge("旧数据", .orange) }
                Spacer()
                Text(a.statusText).font(.caption).foregroundStyle(a.usageStatus == "ok" ? Color.secondary : Color.orange)
            }
            if let org = a.organizationName, !org.isEmpty {
                Text(org).font(.caption).foregroundStyle(.secondary)
            }
            if let u {
                if let w = u.fiveHour { UsageBar(title: "5 小时", pct: w.pct, reset: w.resetDate, stale: a.isStale) }
                if let w = u.sevenDay {
                    UsageBar(title: "7 天", pct: w.pct, reset: w.resetDate, expected: w.expectedPct, ahead: w.aheadOfPace == true, stale: a.isStale)
                }
                ForEach(Array((u.scoped ?? []).enumerated()), id: \.offset) { _, w in
                    UsageBar(title: w.name ?? "模型", pct: w.pct, reset: w.resetDate, expected: w.expectedPct,
                             ahead: w.aheadOfPace == true, stale: a.isStale)
                }
                if let s = u.spend, s.used != nil || s.limit != nil {
                    HStack {
                        Text("额外用量").font(.caption.weight(.semibold)).frame(width: 64, alignment: .leading)
                        Text(Money.format(s.used, currency: s.currency ?? "USD") + (s.limit.map { " / " + Money.format($0, currency: s.currency ?? "USD") } ?? ""))
                            .font(.caption).monospacedDigit()
                        if let p = s.pct { Text(pctText(p)).font(.caption).foregroundStyle(.secondary) }
                    }
                }
            } else {
                Text("暂时没有用量数据").font(.caption).foregroundStyle(.secondary)
            }
            if let exp = a.loginExpiresAt.flatMap({ JSONPath.date($0) }), exp.timeIntervalSinceNow < 7 * 86400 {
                Text("登录将在 \(DateFormatter.localizedString(from: exp, dateStyle: .short, timeStyle: .short)) 过期，到时需要重新登录并运行 cswap add").font(.caption).foregroundStyle(.orange)
            }
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color(nsColor: .controlBackgroundColor)))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(a.active == true ? Color.green.opacity(0.6) : Color.clear, lineWidth: 1.5))
    }
    private func badge(_ t: String, _ c: Color) -> some View {
        Text(t).font(.caption2.weight(.semibold)).padding(.horizontal, 6).padding(.vertical, 1).background(Capsule().fill(c.opacity(0.18)))
    }
}

struct ClaudeCodeCard: View {
    var c: ClaudeSnapshot
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let a = c.account {
                HStack {
                    Text(a.email ?? a.name ?? "Claude 账号").font(.body.weight(.medium))
                    Text("Claude " + a.plan).font(.caption.weight(.semibold)).padding(.horizontal, 6)
                        .background(Capsule().fill(Color.accentColor.opacity(0.15)))
                    if a.extraUsage == true { Text("已开额外用量").font(.caption2).foregroundStyle(.secondary) }
                }
                if let org = a.organizationName { Text(org).font(.caption).foregroundStyle(.secondary) }
            } else {
                Text("Claude Code 没有登录订阅账号（或使用 API Key）").font(.caption).foregroundStyle(.secondary)
            }
            HStack(spacing: 18) {
                stat("今日", c.today.total); stat("近 7 天", c.week.total); stat("本月", c.month.total); stat("累计", c.all.total)
            }
            .padding(.top, 2)
            if !c.byModelToday.isEmpty {
                Text("今日按模型：" + c.byModelToday.sorted { $0.value > $1.value }.map { "\($0.key) \(CodexStats.formatTokens($0.value))" }.joined(separator: "，"))
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
    }
    private func stat(_ t: String, _ v: Int) -> some View {
        VStack(alignment: .leading) {
            Text(t).font(.caption2).foregroundStyle(.secondary)
            Text(CodexStats.formatTokens(v)).font(.callout.weight(.semibold)).monospacedDigit()
        }
    }
}

struct CodexPlanCard: View {
    var c: CodexSnapshot
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(c.planType.map { "ChatGPT " + $0.capitalized } ?? "ChatGPT / Codex").font(.body.weight(.medium))
                Text("今日 \(CodexStats.formatTokens(c.today)) · 本月 \(CodexStats.formatTokens(c.month)) tokens").font(.caption).foregroundStyle(.secondary)
            }
            if c.windows.isEmpty {
                Text("还没有订阅窗口数据：用 ChatGPT 账号登录 Codex 并对话一次后才会出现。").font(.caption).foregroundStyle(.secondary)
            }
            ForEach(c.windows, id: \.label) { w in UsageBar(title: w.label, pct: w.usedPct, reset: w.resetAt) }
        }
    }
}

/// Compact summary used in the ledger window.
struct SubscriptionsSummary: View {
    @ObservedObject var model: AppModel
    var body: some View {
        let s = model.subs
        if model.settings.subsOn && (s.cswap?.accounts?.isEmpty == false || s.claude.account != nil || s.codex.found) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("订阅").font(.headline)
                    Spacer()
                    if model.subsLoading { ProgressView().controlSize(.small) }
                    Button("刷新") { model.refreshSubscriptions() }.controlSize(.small)
                }
                if let accts = s.cswap?.accounts, !accts.isEmpty {
                    ForEach(accts) { CswapAccountCard(a: $0) }
                } else if s.claude.account != nil {
                    ClaudeCodeCard(c: s.claude)
                }
                if s.codex.found { CodexPlanCard(c: s.codex) }
            }
        }
    }
}

struct SubscriptionsTab: View {
    @ObservedObject var model: AppModel

    var body: some View {
        let s = model.subs
        Form {
            Section {
                Toggle("自动识别本机的订阅（cswap、Claude Code、Codex）", isOn: $model.settings.subsOn)
                    .onChange(of: model.settings.subsOn) { on in if on { model.refreshSubscriptions() } }
                Picker("刷新间隔", selection: $model.settings.subsRefreshMinutes) {
                    Text("2 分钟").tag(2.0); Text("5 分钟").tag(5.0); Text("10 分钟").tag(10.0); Text("30 分钟").tag(30.0)
                }
                .onChange(of: model.settings.subsRefreshMinutes) { _ in model.restartSubsTimer() }
                HStack {
                    Button("立即刷新") { model.refreshSubscriptions() }
                    if model.subsLoading { ProgressView().controlSize(.small) }
                    Spacer()
                    if let t = s.updatedAt { Text("更新于 " + DateFormatter.localizedString(from: t, dateStyle: .none, timeStyle: .medium)).font(.caption).foregroundStyle(.secondary) }
                }
            } footer: {
                Text("只读取本机文件和 cswap 的输出，不会读取或发送任何登录令牌。").font(.footnote).foregroundStyle(.secondary)
            }

            Section {
                Toggle("使用 cswap", isOn: $model.settings.subsCswapOn)
                TextField("cswap 路径", text: $model.settings.cswapPath, prompt: Text("留空自动查找"))
                if let p = s.cswapPath {
                    LabeledContent("已找到", value: p).font(.caption)
                    if let e = s.cswapError { Text("❌ " + e).font(.callout).foregroundStyle(.red) }
                    if let accts = s.cswap?.accounts {
                        if accts.isEmpty { Text("cswap 里还没有账号。用 Claude Code 登录后运行 cswap add。").foregroundStyle(.secondary) }
                        ForEach(accts) { CswapAccountCard(a: $0) }
                    }
                } else if model.settings.subsCswapOn {
                    Text("这台 Mac 上没有找到 cswap。它是 Claude Code 的多账号切换工具，装上后这里会显示每个账号的 5 小时、7 天和各模型用量。").font(.callout).foregroundStyle(.secondary)
                    Link("了解 claude-swap", destination: URL(string: "https://github.com/realiti4/claude-swap")!)
                }
            } header: {
                Text("cswap（Claude 多账号）")
            }

            Section("Claude Code") {
                if s.claude.found { ClaudeCodeCard(c: s.claude) }
                else { Text("没有找到 ~/.claude，这台 Mac 上可能没装 Claude Code。").foregroundStyle(.secondary) }
                if s.cswap?.accounts?.isEmpty != false && s.claude.account != nil {
                    Text("Claude 订阅的 5 小时 / 7 天额度只有 Claude 服务器知道，本应用不读取登录令牌，所以看不到百分比。装上 cswap 后会自动显示。")
                        .font(.footnote).foregroundStyle(.secondary)
                }
            }

            Section("Codex / ChatGPT") {
                if s.codex.found { CodexPlanCard(c: s.codex) }
                else { Text("没有找到 ~/.codex，这台 Mac 上可能没装 Codex CLI。").foregroundStyle(.secondary) }
            }

            Section {
                Text("OpenAI API 和 Claude API 的费用需要组织的 Admin Key，请到「模型与厂商」添加「OpenAI API 费用（Admin Key）」或「Claude API 费用（Admin Key）」。普通 API Key 查不到费用。")
                    .font(.footnote).foregroundStyle(.secondary)
                Button("去添加") { SettingsState.shared.tab = .vendors }
            } header: { Text("API 费用") }
        }
        .formStyle(.grouped)
    }
}
