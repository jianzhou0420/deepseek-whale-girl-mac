// Settings window.
import AppKit
import SwiftUI
import UniformTypeIdentifiers

enum SettingsTab: String, CaseIterable, Identifiable {
    case general, deepseek, subscriptions, alerts, sound, snap, vendors, resources, about
    var id: String { rawValue }
    var title: String {
        switch self {
        case .general: return "通用"
        case .deepseek: return "DeepSeek"
        case .subscriptions: return "订阅"
        case .alerts: return "提醒"
        case .sound: return "音效"
        case .snap: return "吸附"
        case .vendors: return "模型与厂商"
        case .resources: return "资源"
        case .about: return "关于"
        }
    }
    var icon: String {
        switch self {
        case .general: return "gearshape"
        case .deepseek: return "key"
        case .subscriptions: return "person.2.badge.gearshape"
        case .alerts: return "bell"
        case .sound: return "speaker.wave.2"
        case .snap: return "rectangle.portrait.and.arrow.right"
        case .vendors: return "server.rack"
        case .resources: return "photo.on.rectangle"
        case .about: return "info.circle"
        }
    }
}

final class SettingsState: ObservableObject {
    static let shared = SettingsState()
    @Published var tab: SettingsTab = .general
}

struct SettingsView: View {
    @ObservedObject var model: AppModel
    @ObservedObject var ui: SettingsState

    var body: some View {
        NavigationSplitView {
            List(SettingsTab.allCases, selection: Binding(get: { ui.tab }, set: { if let t = $0 { ui.tab = t } })) { t in
                Label(t.title, systemImage: t.icon).tag(t)
            }
            .navigationSplitViewColumnWidth(160)
        } detail: {
            Group {
                switch ui.tab {
                case .general: GeneralTab(model: model)
                case .deepseek: DeepSeekTab(model: model)
                case .subscriptions: SubscriptionsTab(model: model)
                case .alerts: AlertsTab(model: model)
                case .sound: SoundTab(model: model)
                case .snap: SnapTab(model: model)
                case .vendors: VendorsTab(model: model)
                case .resources: ResourcesTab(model: model)
                case .about: AboutTab()
                }
            }
            .frame(minWidth: 480, maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }
}

struct GeneralTab: View {
    @ObservedObject var model: AppModel
    var body: some View {
        Form {
            Section("外观") {
                HStack {
                    Text("大小")
                    Slider(value: $model.settings.scale, in: 0.6...2.5, step: 0.1)
                    Text(String(format: "%.1f", model.settings.scale)).monospacedDigit().frame(width: 32)
                }
                Toggle("角色动画（思考、开心、委屈等）", isOn: $model.settings.animateRole)
                Toggle("悬停时显示菜单按钮（关闭后右键角色打开菜单）", isOn: $model.settings.showMenuButton)
                Toggle("菜单栏显示余额", isOn: $model.settings.menuBarBalance)
                Toggle("开机自动启动", isOn: Binding(get: { model.launchAtLogin }, set: { model.launchAtLogin = $0 }))
            }
            Section("气泡") {
                Toggle("点击角色时弹出气泡", isOn: $model.settings.bubbleOn)
                Toggle("点按角色推进队列（点一下前进一项，最后一项后收起）", isOn: $model.bubbleConfig.advanceOnTap)
                Stepper(value: $model.settings.bubbleCloseSec, in: 0...120, step: 1) {
                    Text("自动收起：" + (model.settings.bubbleCloseSec == 0 ? "不自动收起" : "\(Int(model.settings.bubbleCloseSec)) 秒"))
                }
                Button("自定义泡泡内容…") { Windows.bubbleEditor() }
            }
            Section("刷新") {
                Picker("自动刷新余额", selection: $model.settings.refreshSeconds) {
                    Text("30 秒").tag(30.0); Text("60 秒").tag(60.0); Text("2 分钟").tag(120.0); Text("5 分钟").tag(300.0)
                }
                .onChange(of: model.settings.refreshSeconds) { _ in model.restartRefreshTimer() }
            }
        }
        .formStyle(.grouped)
    }
}

struct DeepSeekTab: View {
    @ObservedObject var model: AppModel
    @State private var key = ""
    @State private var message = ""
    @State private var busy = false

    var body: some View {
        Form {
            Section {
                SecureField("sk-…", text: $key)
                HStack {
                    Button("保存密钥") {
                        Keychain.set("DEEPSEEK_API_KEY", key)
                        message = key.isEmpty ? "已删除密钥" : "已保存到钥匙串"
                        key = ""
                        model.refresh(manual: true)
                    }
                    .keyboardShortcut(.defaultAction)
                    Button("测试") {
                        busy = true
                        let k = key.isEmpty ? (model.deepseekKey ?? "") : key
                        Task {
                            do {
                                let b = try await VendorClient.fetchDeepSeek(key: k)
                                message = "✅ 余额 " + Money.format(b.total, currency: b.currency)
                            } catch { message = "❌ " + ((error as? LocalizedError)?.errorDescription ?? "\(error)") }
                            busy = false
                        }
                    }
                    .disabled(busy)
                    if busy { ProgressView().controlSize(.small) }
                    Spacer()
                    Link("去 DeepSeek 开放平台创建密钥", destination: URL(string: "https://platform.deepseek.com/api_keys")!)
                }
                if !message.isEmpty { Text(message).font(.callout) }
            } header: {
                Text("DeepSeek API 密钥")
            } footer: {
                Text("密钥只保存在 macOS 钥匙串里，只会发往 api.deepseek.com/user/balance 查询余额。"
                     + (Keychain.has("DEEPSEEK_API_KEY") ? "当前已设置密钥。" : "当前还没有设置密钥。"))
                    .font(.footnote).foregroundStyle(.secondary)
            }
            Section("当前状态") {
                LabeledContent("总余额", value: model.amountText(model.balance))
                LabeledContent("赠金", value: Money.format(model.bonus, currency: model.currency))
                LabeledContent("充值余额", value: Money.format(model.recharge, currency: model.currency))
                LabeledContent("今日已用", value: model.todayText)
                LabeledContent("当前时段", value: Pricing.statusText(.standard, peak: Pricing.isPeak(model.now)) + " · " + Pricing.countdown(model.now) + " 后切换")
                LabeledContent("更新时间", value: model.updatedAt.map { DateFormatter.localizedString(from: $0, dateStyle: .none, timeStyle: .medium) } ?? "—")
                if case .error(let e) = model.state { Text("❌ " + e).foregroundStyle(.red).font(.callout) }
                if model.stale { Text("网络抖动，显示的是最近一次成功获取的余额").font(.callout).foregroundStyle(.secondary) }
            }
            Section("定价（元 / 百万 tokens，空闲 / 高峰）") {
                ForEach(Pricing.table, id: \.name) { row in
                    LabeledContent(row.display) {
                        Text("命中 \(fmt(row.price.hit)) · 未命中 \(fmt(row.price.miss)) · 输出 \(fmt(row.price.out))")
                            .font(.callout).monospacedDigit()
                    }
                }
                Text("高峰：工作日 9:00–12:00、14:00–18:00（北京时间）。周末和法定节假日全天为空闲时段。")
                    .font(.footnote).foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }
    private func fmt(_ p: [Double]) -> String { p.map { String(format: "%g", $0) }.joined(separator: "/") }
}

struct AlertsTab: View {
    @ObservedObject var model: AppModel
    @State private var editing: String? = nil

    var body: some View {
        Form {
            alertSection("余额预警", "low", $model.settings.lowAlert, unit: "余额低于", defaults: BubbleDefaults.lowBalanceAlert,
                         hint: "余额低于这个数时弹一次提醒，回到这个数以上后才会再次提醒。内容里 {below} 会替换成这个数。")
            alertSection("今日预算", "budget", $model.settings.budgetAlert, unit: "今日已用达到", defaults: BubbleDefaults.budgetAlert,
                         hint: "今日已用达到这个数时，当天弹一次提醒。内容里 {amount} 会替换成这个数。")
            Section("提醒音") {
                Toggle("提醒时播放声音", isOn: $model.settings.alertSoundOn)
                SoundPicker(title: "声音", selection: $model.settings.alertSound, settings: model.settings, allowNone: false)
                VolumeRow(title: "提醒音量", value: $model.settings.alertVolume, follow: model.settings.volume)
                Button("试听") { SoundPlayer.shared.play(model.settings.alertSound, volume: model.settings.alertVolume ?? model.settings.volume) }
            }
            Section {
                Text("每轮对话消耗提示、任务结束音、提问 / 授权提示依赖 DeepSeek Harness 内部的会话事件，独立的 Mac 应用拿不到这些数据，所以没有移植。")
                    .font(.footnote).foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .sheet(item: Binding(get: { editing.map { EditKey(id: $0) } }, set: { editing = $0?.id })) { k in
            AlertContentEditor(model: model, kind: k.id) { editing = nil }
        }
    }

    struct EditKey: Identifiable { var id: String }

    @ViewBuilder
    private func alertSection(_ title: String, _ kind: String, _ cfg: Binding<AlertConfig>, unit: String,
                              defaults: [BubbleModule], hint: String) -> some View {
        Section {
            Toggle("开启", isOn: cfg.on)
            HStack {
                Text(unit)
                TextField("", value: cfg.threshold, format: .number.precision(.fractionLength(0...2)))
                    .frame(width: 90).textFieldStyle(.roundedBorder)
                Text(model.currency)
            }
            Stepper(value: cfg.closeSec, in: 0...600, step: 5) {
                Text("自动关闭：" + (cfg.wrappedValue.closeSec == 0 ? "不自动关闭（点气泡关闭）" : "\(Int(cfg.wrappedValue.closeSec)) 秒"))
            }
            HStack {
                Button("编辑提醒内容…") { editing = kind }
                Button("恢复默认内容") { cfg.wrappedValue.modules = defaults }
                Button("预览") { model.showAlert(kind: kind, modules: cfg.wrappedValue.modules, closeSec: 6) }
            }
        } header: { Text(title) } footer: { Text(hint).font(.footnote).foregroundStyle(.secondary) }
    }
}

struct AlertContentEditor: View {
    @ObservedObject var model: AppModel
    var kind: String
    var done: () -> Void
    @State private var draft: [BubbleModule] = []

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 12) {
                ModuleListEditor(model: model, modules: $draft).frame(minWidth: 420)
                BubblePreview(model: model, modules: draft).frame(width: 300)
            }
            .padding()
            Divider()
            HStack {
                Spacer()
                Button("取消", action: done)
                Button("保存") {
                    if kind == "low" { model.settings.lowAlert.modules = draft } else { model.settings.budgetAlert.modules = draft }
                    done()
                }
                .keyboardShortcut(.defaultAction)
            }
            .padding()
        }
        .frame(width: 800, height: 560)
        .onAppear { draft = kind == "low" ? model.settings.lowAlert.modules : model.settings.budgetAlert.modules }
    }
}

struct SoundPicker: View {
    var title: String
    @Binding var selection: String
    var settings: Settings
    var allowNone = true
    var body: some View {
        Picker(title, selection: $selection) {
            if allowNone { Text("（静音）").tag("") }
            ForEach(SoundPlayer.systemSounds, id: \.self) { Text("系统·" + $0).tag("sys:" + $0) }
            ForEach(settings.fragments) { Text("片段·" + $0.name).tag($0.id) }
        }
    }
}

struct VolumeRow: View {
    var title: String
    @Binding var value: Double?
    var follow: Double
    var body: some View {
        HStack {
            Text(title)
            Slider(value: Binding(get: { value ?? follow }, set: { value = $0 }), in: 0...1)
            Text(value == nil ? "跟随按压音量 \(Int(follow * 100))%" : "\(Int((value ?? 0) * 100))%")
                .font(.callout).monospacedDigit().frame(width: 140, alignment: .leading)
            if value != nil { Button("跟随") { value = nil }.controlSize(.small) }
        }
    }
}

struct SoundTab: View {
    @ObservedObject var model: AppModel
    @State private var newGroupName = ""
    @State private var error = ""

    var body: some View {
        Form {
            Section("按压音效") {
                Toggle("按下 / 松开角色时播放音效", isOn: $model.settings.soundOn)
                Picker("音效组", selection: $model.settings.soundGroup) {
                    ForEach(SoundPlayer.shared.groups(model.settings)) { g in Text(g.name + (g.preset ? "" : "（自定义）")).tag(g.id) }
                }
                HStack {
                    Text("音量（全局基准）")
                    Slider(value: $model.settings.volume, in: 0...1)
                    Text("\(Int(model.settings.volume * 100))%").monospacedDigit().frame(width: 44)
                }
                Button("试听") { SoundPlayer.shared.press(); DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { SoundPlayer.shared.release() } }
            }
            Section("自定义音效组") {
                ForEach($model.settings.customGroups) { $g in
                    HStack {
                        TextField("名称", text: $g.name).frame(width: 110)
                        SoundPicker(title: "按下", selection: $g.press, settings: model.settings)
                        SoundPicker(title: "松开", selection: $g.release, settings: model.settings)
                        Button(role: .destructive) {
                            model.settings.customGroups.removeAll { $0.id == g.id }
                            if model.settings.soundGroup == g.id { model.settings.soundGroup = "bubble" }
                        } label: { Image(systemName: "trash") }.buttonStyle(.borderless)
                    }
                }
                HStack {
                    TextField("", text: $newGroupName, prompt: Text("新音效组名称")).labelsHidden().frame(width: 180)
                    Button("新建") {
                        let id = "grp_" + UUID().uuidString.prefix(6).lowercased()
                        model.settings.customGroups.append(SoundGroup(id: id, name: newGroupName.isEmpty ? "我的音效" : newGroupName,
                                                                      press: "sys:Pop", release: ""))
                        newGroupName = ""
                    }
                }
            }
            Section("音频片段") {
                ForEach($model.settings.fragments) { $f in FragmentRow(fragment: $f, model: model) }
                HStack {
                    Button("导入音频…") { importAudio() }
                    if !error.isEmpty { Text(error).foregroundStyle(.red).font(.callout) }
                }
                Text("导入后可以拖动起止点裁剪，片段能用在音效组和提醒音里。").font(.footnote).foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }

    private func importAudio() {
        let p = NSOpenPanel()
        p.allowedContentTypes = [.audio]
        p.allowsMultipleSelection = true
        guard p.runModal() == .OK else { return }
        for u in p.urls {
            do { model.settings.fragments.append(try SoundPlayer.importFragment(u)) }
            catch { self.error = (error as? LocalizedError)?.errorDescription ?? "\(error)" }
        }
    }
}

struct FragmentRow: View {
    @Binding var fragment: SoundFragment
    @ObservedObject var model: AppModel
    @State private var duration: Double = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                TextField("名称", text: $fragment.name).frame(width: 160)
                Spacer()
                Button("试听") { SoundPlayer.shared.play(fragment.id, volume: model.settings.volume) }
                Button(role: .destructive) {
                    try? FileManager.default.removeItem(at: Store.sub("audio").appendingPathComponent(fragment.file))
                    let id = fragment.id
                    DispatchQueue.main.async {
                        model.settings.fragments.removeAll { $0.id == id }
                        for i in model.settings.customGroups.indices {
                            if model.settings.customGroups[i].press == id { model.settings.customGroups[i].press = "" }
                            if model.settings.customGroups[i].release == id { model.settings.customGroups[i].release = "" }
                        }
                    }
                } label: { Image(systemName: "trash") }.buttonStyle(.borderless)
            }
            if duration > 0 {
                HStack {
                    Text("起").font(.caption)
                    Slider(value: $fragment.start, in: 0...duration)
                    Text("止").font(.caption)
                    Slider(value: $fragment.end, in: 0...duration)
                    Text(String(format: "%.2f–%.2fs", fragment.start, fragment.end)).font(.caption).monospacedDigit().frame(width: 90)
                }
            }
        }
        .onAppear { duration = SoundPlayer.duration(fragment) }
    }
}

struct SnapTab: View {
    @ObservedObject var model: AppModel
    var body: some View {
        Form {
            Section {
                Toggle("拖动松手后吸附到屏幕边缘", isOn: $model.settings.snapOn)
                Toggle("贴左边时整体水平翻转（文字保持正向）", isOn: $model.settings.flipOnLeft)
                Picker("吸附区单位", selection: $model.settings.snapMode) {
                    Text("按比例").tag("ratio"); Text("按像素").tag("pixel")
                }
                .pickerStyle(.segmented)
            } footer: {
                Text("挂件中心落进某条边的吸附区，松手后就贴到那条边；左右、上下各自独立判断，角落可以组合。数值为 0 表示这条边不吸附（上边默认关闭）。")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            Section("吸附区") {
                if model.settings.snapMode == "ratio" {
                    ratio("左", $model.settings.snapLeft)
                    ratio("右", $model.settings.snapRight)
                    ratio("上", $model.settings.snapTop)
                    ratio("下", $model.settings.snapBottom)
                } else {
                    pixel("左", $model.settings.snapLeftPx)
                    pixel("右", $model.settings.snapRightPx)
                    pixel("上", $model.settings.snapTopPx)
                    pixel("下", $model.settings.snapBottomPx)
                }
            }
        }
        .formStyle(.grouped)
    }
    private func ratio(_ t: String, _ v: Binding<Double>) -> some View {
        HStack {
            Text(t).frame(width: 20)
            Slider(value: v, in: 0...0.5, step: 0.01)
            Text(v.wrappedValue == 0 ? "关闭" : "\(Int(v.wrappedValue * 100))%").monospacedDigit().frame(width: 44)
        }
    }
    private func pixel(_ t: String, _ v: Binding<Double>) -> some View {
        HStack {
            Text(t).frame(width: 20)
            TextField("", value: v, format: .number).frame(width: 80).textFieldStyle(.roundedBorder)
            Text("像素" + (v.wrappedValue == 0 ? "（关闭）" : "")).foregroundStyle(.secondary)
        }
    }
}

// MARK: - Vendors

struct VendorsTab: View {
    @ObservedObject var model: AppModel
    @State private var selected: String? = nil
    @State private var newTemplate = "openrouter"

    var body: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 8) {
                List(selection: $selected) {
                    ForEach(model.apiModels) { m in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(m.name).font(.body.weight(.medium))
                            Text(statusLine(m)).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                        }
                        .tag(m.id)
                    }
                }
                HStack {
                    Picker("", selection: $newTemplate) {
                        ForEach(Vendors.sorted) { t in Text(t.name).tag(t.id) }
                    }
                    .labelsHidden()
                    Button("添加") {
                        guard let t = Vendors.template(newTemplate) else { return }
                        let m = ApiModel.from(t)
                        model.apiModels.append(m)
                        selected = m.id
                    }
                }
                .padding([.horizontal, .bottom], 8)
            }
            .frame(width: 230)
            Divider()

            Group {
                if let id = selected, let idx = model.apiModels.firstIndex(where: { $0.id == id }) {
                    VendorEditor(model: model, m: $model.apiModels[idx]) {
                        model.apiModels.remove(at: idx); selected = nil
                    }
                    .id(id)
                } else {
                    VStack(spacing: 8) {
                        Image(systemName: "server.rack").font(.largeTitle).foregroundStyle(.secondary)
                        Text("DeepSeek 余额在「DeepSeek」页设置。")
                        Text("这里可以添加其它厂商：查余额、查订阅额度，或者统计本机 Codex 用量。在左下角选好厂商后点「添加」。")
                    }
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                    .padding(24)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func statusLine(_ m: ApiModel) -> String {
        if m.provider == "codex" { return "今日 " + CodexStats.formatTokens(model.codex.today) + " tokens" }
        guard let st = model.vendorStatus[m.id] else { return m.template?.noBalanceAPI == true ? "无余额接口" : "未获取" }
        if let e = st.error { return "❌ " + e }
        if let c = st.costMonth { return "本月 " + Money.format(c, currency: "USD") + " · 今天 " + Money.format(st.costToday, currency: "USD") }
        if let b = st.balance { return Money.format(b, currency: st.currency) + (st.stale ? "（旧）" : "") }
        if !st.windows.isEmpty { return st.windows.map { "\($0.label) \($0.usedPct.map { String(format: "%.0f%%", $0) } ?? "—")" }.joined(separator: " · ") }
        return "—"
    }
}

struct VendorEditor: View {
    @ObservedObject var model: AppModel
    @Binding var m: ApiModel
    var onDelete: () -> Void
    @State private var key = ""
    @State private var testResult = ""
    @State private var testing = false
    @State private var advanced = false

    var body: some View {
        let t = m.template
        Form {
            Section {
                TextField("显示名称", text: $m.name)
                LabeledContent("厂商模板", value: t?.name ?? m.provider)
                if let note = t?.note, !note.isEmpty { Text(note).font(.footnote).foregroundStyle(.secondary) }
            }
            if t?.kind != .codex {
                Section("密钥") {
                    HStack {
                        TextField("凭据名", text: $m.keyRef).frame(width: 200)
                        Text(Keychain.has(m.keyRef) ? "已设置" : "未设置").foregroundStyle(Keychain.has(m.keyRef) ? .green : .secondary)
                    }
                    HStack {
                        SecureField("粘贴密钥后点保存", text: $key)
                        Button("保存") {
                            guard Keychain.isValidRef(m.keyRef) else { testResult = "❌ 凭据名只能用字母、数字和下划线"; return }
                            Keychain.set(m.keyRef, key); key = ""; testResult = "已保存到钥匙串"
                        }
                    }
                    Text("同一个凭据名的密钥会被所有使用它的模型共用。").font(.footnote).foregroundStyle(.secondary)
                }
                if t?.needsBaseURL == true || m.provider == "custom" {
                    Section("接口") {
                        if t?.needsBaseURL == true { TextField("Base URL，例如 https://your-gateway.example", text: $m.baseURL) }
                        if m.provider == "custom" {
                            TextField("余额接口地址", text: $m.urlOverride)
                            TextField("剩余余额字段路径（如 data.balance）", text: $m.remainingPath)
                            TextField("或：总额字段路径", text: $m.totalPath)
                            TextField("已用字段路径", text: $m.usedPath)
                        }
                        Toggle("允许把密钥发送到自定义地址", isOn: $m.allowCustomEndpoint)
                        Text("默认只会把密钥发往模板里写死的官方接口。确认是你自己的网关后再打开。").font(.footnote).foregroundStyle(.secondary)
                    }
                }
                DisclosureGroup("接口与字段（高级）", isExpanded: $advanced) {
                    TextField("覆盖接口地址（留空用模板）", text: $m.urlOverride)
                    TextField("覆盖鉴权（如 Bearer {key}）", text: $m.authOverride)
                    TextField("剩余余额字段路径", text: $m.remainingPath)
                    TextField("总额字段路径", text: $m.totalPath)
                    TextField("已用字段路径", text: $m.usedPath)
                    HStack {
                        Text("乘数")
                        TextField("", value: $m.scale, format: .number).frame(width: 80)
                        Text("0 = 用模板默认").foregroundStyle(.secondary)
                    }
                    Picker("币种", selection: $m.currency) { Text("CNY").tag("CNY"); Text("USD").tag("USD") }
                    Toggle("允许把密钥发送到自定义地址", isOn: $m.allowCustomEndpoint)
                }
            }
            Section("提醒") {
                HStack {
                    Toggle("余额低于", isOn: $m.lowBalanceOn)
                    TextField("", value: $m.lowBalance, format: .number).frame(width: 80)
                    Text(m.currency)
                }
                HStack {
                    Toggle("今日已用超过", isOn: $m.budgetOn)
                    TextField("", value: $m.budget, format: .number).frame(width: 80)
                    Text(m.currency)
                }
            }
            Section("额度（订阅 / 资源包）") {
                Toggle("启用额度", isOn: $m.quota.on)
                if m.quota.on {
                    HStack {
                        Text("总量")
                        TextField("", value: $m.quota.total, format: .number).frame(width: 110)
                        Picker("", selection: $m.quota.unit) { Text("tokens").tag("tokens"); Text("元").tag("元") }.labelsHidden().frame(width: 90)
                    }
                    Picker("重置", selection: $m.quota.reset) {
                        Text("不重置").tag("none"); Text("每日").tag("daily"); Text("每月").tag("monthly")
                    }
                    Picker("已用来源", selection: $m.quota.source) {
                        Text("手动填写").tag("manual")
                        Text("Codex 本地会话 token").tag("codex")
                    }
                    .onChange(of: m.quota.source) { s in if s == "codex" { m.quota.baseline = Double(model.codex.all) } }
                    if m.quota.source == "manual" {
                        HStack { Text("已用"); TextField("", value: $m.quota.used, format: .number).frame(width: 110) }
                    } else {
                        LabeledContent("当前已用", value: CodexStats.formatTokens(Int(model.quotaUsed(m))))
                    }
                }
            }
            if m.provider == "codex" {
                Section("Codex 本地统计") {
                    if model.codex.found {
                        LabeledContent("今日", value: CodexStats.formatTokens(model.codex.today) + " tokens")
                        LabeledContent("近 7 天", value: CodexStats.formatTokens(model.codex.week) + " tokens")
                        LabeledContent("本月", value: CodexStats.formatTokens(model.codex.month) + " tokens")
                        LabeledContent("累计", value: CodexStats.formatTokens(model.codex.all) + " tokens")
                        LabeledContent("会话文件", value: "\(model.codex.fileCount) 个")
                        ForEach(model.codex.windows, id: \.label) { w in
                            LabeledContent("\(w.label) 窗口", value: "已用 \(w.usedPct.map { String(format: "%.0f%%", $0) } ?? "—")"
                                           + (w.resetAt.map { " · " + AppModel.shortReset($0) } ?? ""))
                        }
                    } else {
                        Text("没有找到 ~/.codex 目录。装好 Codex 并用过一次后再来看。").foregroundStyle(.secondary)
                    }
                }
            }
            Section {
                HStack {
                    Button("测试连通性") {
                        testing = true
                        let mm = m
                        Task {
                            testResult = await VendorClient.test(model: mm, key: Keychain.get(mm.keyRef))
                            testing = false
                            model.refresh(manual: false)
                        }
                    }
                    .disabled(testing)
                    if testing { ProgressView().controlSize(.small) }
                    Spacer()
                    Button("删除这个模型", role: .destructive, action: onDelete)
                }
                if !testResult.isEmpty { Text(testResult).font(.callout).textSelection(.enabled) }
                Text("泡泡里可以加「余额·其它厂商」「额度·其它厂商」模块来显示这个模型。").font(.footnote).foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - Resources

struct ResourcesTab: View {
    @ObservedObject var model: AppModel
    @State private var roles = Gallery.list("roles")
    @State private var images = Gallery.list("images")
    @State private var error = ""

    var body: some View {
        Form {
            Section("角色") {
                ScrollView(.horizontal) {
                    HStack(spacing: 12) {
                        tile(selected: model.settings.roleId == "default", name: "鲸鱼娘（默认）", delete: nil) {
                            if let img = Atlas.shared.image(0, 6) { Image(decorative: img, scale: 1).resizable().scaledToFit() }
                        } tap: { model.settings.roleId = "default" }
                        ForEach(roles) { r in
                            tile(selected: model.settings.roleId == r.id, name: r.name, delete: {
                                Gallery.remove("roles", r.id); roles = Gallery.list("roles")
                                if model.settings.roleId == r.id { model.settings.roleId = "default" }
                            }) {
                                if let ns = NSImage(contentsOf: Gallery.url("roles", r)) { Image(nsImage: ns).resizable().scaledToFit() }
                            } tap: { model.settings.roleId = r.id }
                        }
                    }
                    .padding(.vertical, 4)
                }
                Button("导入角色图片…") { importImages("roles") }
                Text("建议用透明背景的 PNG 或 GIF，角色站在图片底部。").font(.footnote).foregroundStyle(.secondary)
            }
            Section("泡泡图库") {
                ScrollView(.horizontal) {
                    HStack(spacing: 12) {
                        ForEach(BuiltinImages.all, id: \.id) { b in
                            tile(selected: false, name: b.name, delete: nil) { BubbleImage(imgId: b.id, maxWidth: 64) } tap: {}
                        }
                        ForEach(images) { im in
                            tile(selected: false, name: im.name, delete: {
                                Gallery.remove("images", im.id); images = Gallery.list("images")
                            }) {
                                if let ns = NSImage(contentsOf: Gallery.url("images", im)) { Image(nsImage: ns).resizable().scaledToFit() }
                            } tap: {}
                        }
                    }
                    .padding(.vertical, 4)
                }
                Button("导入图片 / 动图…") { importImages("images") }
            }
            if !error.isEmpty { Text(error).foregroundStyle(.red) }
            Section("数据") {
                Button("在访达中显示数据文件夹") { NSWorkspace.shared.activateFileViewerSelecting([Store.dir]) }
                Text("设置、记账、泡泡配置都保存在这个文件夹里；API 密钥保存在钥匙串里。").font(.footnote).foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }

    private func importImages(_ kind: String) {
        let p = NSOpenPanel()
        p.allowedContentTypes = [.png, .gif, .jpeg, .webP, .heic]
        p.allowsMultipleSelection = true
        guard p.runModal() == .OK else { return }
        for u in p.urls {
            do { _ = try Gallery.add(kind, from: u) } catch { self.error = (error as? LocalizedError)?.errorDescription ?? "\(error)" }
        }
        roles = Gallery.list("roles"); images = Gallery.list("images")
    }

    private func tile<C: View>(selected: Bool, name: String, delete: (() -> Void)?, @ViewBuilder content: () -> C, tap: @escaping () -> Void) -> some View {
        VStack(spacing: 4) {
            content().frame(width: 72, height: 78)
            Text(name).font(.caption).lineLimit(1).frame(width: 84)
            if let delete { Button("删除", role: .destructive, action: delete).controlSize(.mini) }
        }
        .padding(6)
        .background(RoundedRectangle(cornerRadius: 8).stroke(selected ? Color.accentColor : Color.secondary.opacity(0.25), lineWidth: selected ? 2 : 1))
        .contentShape(Rectangle())
        .onTapGesture(perform: tap)
    }
}

struct AboutTab: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    if let img = Atlas.shared.image(3, 1) { Image(decorative: img, scale: 1).resizable().frame(width: 64, height: 69) }
                    VStack(alignment: .leading) {
                        Text("WhaleBalance").font(.title2.bold())
                        Text("v\(appVersion) · DeepSeek 余额小鲸鱼的 macOS 原生版").foregroundStyle(.secondary)
                    }
                }
                Text("致谢").font(.headline)
                Text("功能设计、记账规则、厂商模板与默认台词移植自 [MeteorNOX/DeepSeek-Balance-Whale-Widget](https://github.com/MeteorNOX/DeepSeek-Balance-Whale-Widget)（代码 MIT 许可）。原项目的图片与音效不在 MIT 范围内，本应用没有使用。")
                Text("角色动画来自 [f0909172434/deepseek-girl-codex-pet](https://github.com/f0909172434/deepseek-girl-codex-pet)（MIT 许可）。")
                Text("这是社区制作的非官方项目，与 DeepSeek（深度求索）没有隶属或背书关系。")
                Text("没有移植的功能").font(.headline)
                Text("每轮对话消耗、任务结束音、提问 / 授权提示、对话名模块、DSH 账号登录态余额，以及按会话估算无余额接口厂商的今日已用。它们都依赖 DeepSeek Harness 进程内部的数据，独立应用拿不到。")
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
