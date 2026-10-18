// "自定义泡泡" editor: click queue, weighted A/B choices, per-module content and style, module library.
import AppKit
import SwiftUI

struct BubblePreview: View {
    @ObservedObject var model: AppModel
    var modules: [BubbleModule]
    var base: CGFloat = 300
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("预览").font(.headline)
            ZStack {
                RoundedRectangle(cornerRadius: 10).fill(Color(nsColor: .underPageBackgroundColor))
                BubbleView(model: model, modules: modules, base: base, mirrored: false)
                    .frame(width: base, height: base * 700 / 1026)
            }
            .frame(height: base * 700 / 1026 + 16)
            Text("实际显示会按气泡大小自动缩放内容。随机语句与随机图片在预览里显示第一条。").font(.caption).foregroundStyle(.secondary)
        }
    }
}

struct ModuleListEditor: View {
    @ObservedObject var model: AppModel
    @Binding var modules: [BubbleModule]
    var library: Binding<[BubbleModule]>? = nil
    @State private var selected: String? = nil

    private var index: Int? { modules.firstIndex { $0.id == selected } }
    private var rowCount: Int { BubbleContent.rows(modules).count }
    private var imageCount: Int { modules.filter { $0.type.isImage }.count }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            List(selection: $selected) {
                ForEach(Array(modules.enumerated()), id: \.element.id) { i, m in
                    HStack(spacing: 6) {
                        if m.joinPrev && i > 0 { Image(systemName: "arrow.turn.down.right").foregroundStyle(.secondary) }
                        Text(m.type.label).font(.caption.weight(.semibold))
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(Capsule().fill(Color.accentColor.opacity(0.15)))
                        Text(m.summary).lineLimit(1).foregroundStyle(.secondary)
                    }
                    .tag(m.id)
                }
                .onMove { modules.move(fromOffsets: $0, toOffset: $1) }
            }
            .frame(minHeight: 150)

            HStack(spacing: 6) {
                Menu("添加模块") {
                    ForEach(ModuleType.allCases, id: \.self) { t in Button(t.label) { add(BubbleModule(type: t)) } }
                    if let lib = library?.wrappedValue, !lib.isEmpty {
                        Divider()
                        Menu("从模块库") {
                            ForEach(lib) { m in Button(m.type.label + "：" + m.summary) { var c = m; c.id = UUID().uuidString; add(c) } }
                        }
                    }
                }
                .frame(width: 110)
                Button { move(-1) } label: { Image(systemName: "arrow.up") }.disabled(index == nil || index == 0)
                Button { move(1) } label: { Image(systemName: "arrow.down") }.disabled(index == nil || index == modules.count - 1)
                Button { if let i = index { var c = modules[i]; c.id = UUID().uuidString; modules.insert(c, at: i + 1); selected = c.id } } label: {
                    Image(systemName: "plus.square.on.square")
                }.disabled(index == nil).help("复制")
                if let library {
                    Button { if let i = index { var c = modules[i]; c.id = UUID().uuidString; library.wrappedValue.append(c) } } label: {
                        Image(systemName: "tray.and.arrow.down")
                    }.disabled(index == nil).help("存入模块库")
                }
                Button(role: .destructive) { if let i = index { modules.remove(at: i); selected = nil } } label: { Image(systemName: "trash") }
                    .disabled(index == nil)
                Spacer()
                Text("\(rowCount)/6 行").font(.caption).foregroundStyle(rowCount > 6 ? .red : .secondary)
            }
            if imageCount > 1 { Text("一个泡泡只能放一个图片类模块，多出来的会被忽略。").font(.caption).foregroundStyle(.orange) }

            if let i = index {
                Divider()
                ScrollView { ModuleForm(model: model, m: $modules[i], isFirst: i == 0).padding(.trailing, 8) }
            } else {
                Text("选中一个模块来编辑内容和样式。拖动可以排序。").font(.callout).foregroundStyle(.secondary)
                Spacer()
            }
        }
    }

    private func add(_ m: BubbleModule) {
        var m = m
        if m.type == .random && m.lines.isEmpty { m.lines = [RandomLine("新的一句")]; m.bold = true }
        if m.type == .text { m.text = "文本"; m.bold = true }
        if m.type == .link { m.text = "链接"; m.url = "https://platform.deepseek.com" }
        if m.type == .image { m.imgId = "bimg_wave" }
        if m.type == .randomImage { m.imgs = [WeightedImage(imgId: "bimg_wave"), WeightedImage(imgId: "bimg_cheer")] }
        if m.type == .peak { m.peakColor = "#e0433f"; m.offColor = "#2fa24c"; m.bold = true }
        if m.type == .vendorBalance || m.type == .vendorQuota { m.modelId = model.apiModels.first?.id ?? "" }
        if m.type == .subscription { m.size = 5; m.bold = true }
        if let i = index { modules.insert(m, at: i + 1) } else { modules.append(m) }
        selected = m.id
    }
    private func move(_ d: Int) {
        guard let i = index, i + d >= 0, i + d < modules.count else { return }
        modules.swapAt(i, i + d)
    }
}

struct ModuleForm: View {
    @ObservedObject var model: AppModel
    @Binding var m: BubbleModule
    var isFirst: Bool

    static let fonts: [String] = NSFontManager.shared.availableFontFamilies.sorted()

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            content
            Divider()
            style
        }
    }

    @ViewBuilder private var content: some View {
        switch m.type {
        case .text:
            TextField("文本（可用占位符，如 {balance_ds}）", text: $m.text, axis: .vertical).lineLimit(1...4)
        case .link:
            TextField("显示文字", text: $m.text)
            TextField("链接地址 https://…", text: $m.url)
        case .random:
            Text("随机语句：每次显示按权重抽 1 句，不会连续重复同一句。").font(.caption).foregroundStyle(.secondary)
            ForEach($m.lines) { $l in
                HStack {
                    TextField("句子", text: $l.t)
                    Text("权重").font(.caption)
                    TextField("", value: $l.w, format: .number).frame(width: 44)
                    Picker("", selection: Binding(get: { l.rgb ?? "" }, set: { l.rgb = $0.isEmpty ? nil : $0 })) {
                        Text("默认色").tag("")
                        ForEach(Gradients.presets, id: \.id) { Text($0.name).tag($0.id) }
                    }
                    .labelsHidden().frame(width: 90)
                    Button { m.lines.removeAll { $0.id == l.id } } label: { Image(systemName: "minus.circle") }.buttonStyle(.borderless)
                }
            }
            Button("添加一句") { m.lines.append(RandomLine("新的一句")) }
        case .image:
            imagePicker($m.imgId)
            scaleRow
        case .randomImage:
            ForEach($m.imgs) { $im in
                HStack {
                    imagePicker($im.imgId)
                    Text("权重").font(.caption)
                    TextField("", value: $im.w, format: .number).frame(width: 44)
                    Button { m.imgs.removeAll { $0.id == im.id } } label: { Image(systemName: "minus.circle") }.buttonStyle(.borderless)
                }
            }
            Button("添加图片") { m.imgs.append(WeightedImage(imgId: "bimg_wave")) }
            scaleRow
        case .peak:
            Picker("样式", selection: $m.peakStyle) {
                ForEach(Pricing.Style.allCases, id: \.rawValue) { Text($0.label).tag($0.rawValue) }
            }
            Picker("内容", selection: $m.tpl) {
                Text("状态文字 {status}").tag("{status}")
                Text("倒计时 {countdown}").tag("{countdown}")
                if m.tpl != "{status}" && m.tpl != "{countdown}" { Text("自定义").tag(m.tpl) }
            }
            TextField("自定义模板", text: $m.tpl)
            HStack {
                colorRow("高峰文字", $m.peakColor)
                colorRow("空闲文字", $m.offColor)
            }
            HStack {
                gradientPicker("高峰渐变", $m.peakRgb)
                gradientPicker("空闲渐变", $m.offRgb)
            }
            HStack {
                gradientPicker("高峰底色", $m.peakBgRgb)
                gradientPicker("空闲底色", $m.offBgRgb)
            }
        case .vendorBalance, .vendorQuota:
            if model.apiModels.isEmpty {
                Text("还没有添加其它厂商。先去「设置 → 模型与厂商」添加。").foregroundStyle(.secondary)
            }
            Picker("模型", selection: $m.modelId) {
                Text("未选择").tag("")
                ForEach(model.apiModels) { Text($0.name).tag($0.id) }
            }
            if m.type == .vendorQuota {
                Picker("窗口", selection: $m.window) {
                    Text("全部窗口").tag("")
                    ForEach(windowKeys, id: \.self) { Text($0).tag($0) }
                }
            }
            templateField(m.type == .vendorBalance ? "{name} {balance} {today} {cost_today} {cost_month}" : "{name} {quota} {quota_used} {quota_left} {quota_total} {quota_reset}")
        case .balance, .bonus, .recharge:
            templateField("{balance_ds} {bonus_ds} {recharge_ds}")
        case .today:
            templateField("{expense_ds}")
        case .codex:
            templateField("{codex_today} {codex_week} {codex_month}")
        case .subscription:
            Picker("来源", selection: $m.window) {
                Text("自动（有 cswap 用 cswap 当前账号）").tag("")
                if model.subs.cswap?.accounts?.isEmpty == false {
                    Text("cswap 当前账号").tag("cswap")
                    Text("cswap 全部账号（每个账号一行）").tag("cswap:all")
                    ForEach(model.subs.cswap?.accounts ?? []) { a in Text("cswap #\(a.number) \(a.alias ?? a.email)").tag("cswap:\(a.number)") }
                }
                Text("Claude Code").tag("claude")
                Text("Codex / ChatGPT").tag("codex")
            }
            templateField("{sub_account} {sub_plan} {sub_5h} {sub_7d} {sub_spend} {sub_reset} {sub_tokens_today} {sub_all}")
        }
        if !isFirst && !m.type.isImage {
            Toggle("与上一个模块放在同一行", isOn: $m.joinPrev)
        }
    }

    private var windowKeys: [String] {
        guard let am = model.apiModels.first(where: { $0.id == m.modelId }), let q = am.template?.quota else { return [] }
        return q.windows.map(\.key)
    }

    @ViewBuilder private var style: some View {
        if !m.type.isImage {
            HStack {
                Text("字号")
                Slider(value: Binding(get: { Double(m.size) }, set: { m.size = Int($0) }), in: 1...50, step: 1)
                Text("\(m.size)").monospacedDigit().frame(width: 28)
            }
            HStack {
                Toggle("加粗", isOn: $m.bold)
                Toggle("斜体", isOn: $m.italic)
                Toggle("下划线", isOn: $m.ul)
            }
            HStack {
                colorRow("文字颜色", $m.color)
                gradientPicker("跑马灯渐变", $m.rgb)
            }
            HStack {
                colorRow("底色", $m.bg)
                gradientPicker("渐变底色", $m.bgRgb)
            }
            Picker("字体", selection: $m.font) {
                Text("系统圆体（默认）").tag("")
                ForEach(Self.fonts, id: \.self) { Text($0).tag($0) }
            }
        }
    }

    private var scaleRow: some View {
        HStack {
            Text("图片大小")
            Slider(value: $m.imgScale, in: 0.1...1)
            Text("\(Int(m.imgScale * 100))%").monospacedDigit().frame(width: 44)
        }
    }

    private func templateField(_ hint: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            TextField("显示模板", text: $m.tpl)
            Text("可用占位符：" + hint).font(.caption).foregroundStyle(.secondary)
        }
    }

    private func imagePicker(_ id: Binding<String>) -> some View {
        Picker("图片", selection: id) {
            ForEach(BuiltinImages.all, id: \.id) { Text($0.name).tag($0.id) }
            ForEach(Gallery.list("images")) { Text($0.name).tag($0.id) }
        }
    }

    private func colorRow(_ title: String, _ hex: Binding<String>) -> some View {
        HStack(spacing: 4) {
            ColorPicker(title, selection: Binding(get: { Color(hexString: hex.wrappedValue) ?? .bubbleInk },
                                                  set: { hex.wrappedValue = $0.hexString }), supportsOpacity: false)
            if !hex.wrappedValue.isEmpty {
                Button { hex.wrappedValue = "" } label: { Image(systemName: "xmark.circle.fill") }.buttonStyle(.borderless).help("清除")
            }
        }
    }

    private func gradientPicker(_ title: String, _ id: Binding<String>) -> some View {
        Picker(title, selection: id) {
            Text("无").tag("")
            ForEach(Gradients.presets, id: \.id) { Text($0.name).tag($0.id) }
        }
        .frame(maxWidth: 220)
    }
}

struct BubbleEditorView: View {
    @ObservedObject var model: AppModel
    @State private var draft = BubbleConfig()
    @State private var itemIndex = 0
    @State private var optionIndex = 0
    @State private var loaded = false

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 0) {
                itemsColumn.frame(width: 220)
                Divider()
                middle.padding(12).frame(minWidth: 440, maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                Divider()
                VStack(alignment: .leading, spacing: 12) {
                    BubblePreview(model: model, modules: previewModules)
                    libraryView
                }
                .padding(12)
                .frame(width: 330)
            }
            Divider()
            HStack {
                Toggle("点按角色推进队列", isOn: $draft.advanceOnTap)
                Spacer()
                Button("恢复默认") { draft.items = BubbleDefaults.items; itemIndex = 0; optionIndex = 0 }
                Button("取消") { WindowManager.shared.close("bubble") }
                Button("保存") { model.bubbleConfig = draft; WindowManager.shared.close("bubble") }.keyboardShortcut(.defaultAction)
            }
            .padding(12)
        }
        .onAppear { if !loaded { draft = model.bubbleConfig; loaded = true } }
    }

    private var itemsColumn: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("点击序列").font(.headline).padding([.top, .horizontal], 12)
            List(selection: Binding(get: { itemIndex }, set: { itemIndex = $0 ?? 0; optionIndex = 0 })) {
                ForEach(Array(draft.items.enumerated()), id: \.element.id) { i, it in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(i == 0 ? "首次点击" : "再次点击 #\(i)").font(.body.weight(.medium))
                        Text((it.kind == "choice" ? "并列选择 · \(it.options.count) 项" : "\(it.modules.count) 个模块") + (it.name.isEmpty ? "" : " · " + it.name))
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    .tag(i)
                }
            }
            HStack(spacing: 6) {
                Menu("添加") {
                    Button("自定义内容") { draft.items.append(BubbleItem(name: "新泡泡", modules: [BubbleDefaults.text("新泡泡")])); itemIndex = draft.items.count - 1 }
                    Button("并列选择（按权重抽一个）") {
                        draft.items.append(BubbleItem(kind: "choice", name: "并列选择", options: [
                            ChoiceOption(w: 1, item: BubbleItem(modules: [BubbleDefaults.text("A")])),
                            ChoiceOption(w: 1, item: BubbleItem(modules: [BubbleDefaults.text("B")])),
                        ]))
                        itemIndex = draft.items.count - 1
                    }
                }
                .frame(width: 70)
                Button { moveItem(-1) } label: { Image(systemName: "arrow.up") }.disabled(itemIndex == 0)
                Button { moveItem(1) } label: { Image(systemName: "arrow.down") }.disabled(itemIndex >= draft.items.count - 1)
                Button(role: .destructive) {
                    guard draft.items.count > 1 else { return }
                    draft.items.remove(at: itemIndex); itemIndex = max(0, itemIndex - 1)
                } label: { Image(systemName: "trash") }.disabled(draft.items.count <= 1)
            }
            .padding([.horizontal, .bottom], 12)
            Text("点角色显示「首次点击」；点气泡依次进入后面的项，最后一项后收起。").font(.caption).foregroundStyle(.secondary)
                .padding([.horizontal, .bottom], 12)
        }
    }

    @ViewBuilder private var middle: some View {
        if itemIndex < draft.items.count {
            VStack(alignment: .leading, spacing: 10) {
                TextField("备注名称", text: $draft.items[itemIndex].name)
                if draft.items[itemIndex].kind == "choice" {
                    Text("并列选择：每次按权重抽一个选项显示（不连续重复同一项）。").font(.caption).foregroundStyle(.secondary)
                    HStack {
                        Picker("选项", selection: $optionIndex) {
                            ForEach(Array(draft.items[itemIndex].options.enumerated()), id: \.element.id) { i, _ in
                                Text("选项 \(Character(UnicodeScalar(65 + min(i, 25))!))").tag(i)
                            }
                        }
                        .frame(width: 160)
                        if optionIndex < draft.items[itemIndex].options.count {
                            Text("权重")
                            TextField("", value: $draft.items[itemIndex].options[optionIndex].w, format: .number).frame(width: 60)
                        }
                        Button("添加选项") {
                            draft.items[itemIndex].options.append(ChoiceOption(w: 1, item: BubbleItem(modules: [BubbleDefaults.text("新选项")])))
                            optionIndex = draft.items[itemIndex].options.count - 1
                        }
                        Button("删除选项", role: .destructive) {
                            guard draft.items[itemIndex].options.count > 1 else { return }
                            draft.items[itemIndex].options.remove(at: optionIndex); optionIndex = 0
                        }
                        .disabled(draft.items[itemIndex].options.count <= 1)
                    }
                    if optionIndex < draft.items[itemIndex].options.count {
                        ModuleListEditor(model: model, modules: $draft.items[itemIndex].options[optionIndex].item.modules, library: $draft.library)
                            .id("\(itemIndex)-\(optionIndex)")
                    }
                } else {
                    ModuleListEditor(model: model, modules: $draft.items[itemIndex].modules, library: $draft.library)
                        .id("\(itemIndex)")
                }
            }
        }
    }

    private var libraryView: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("模块库").font(.headline)
            if draft.library.isEmpty {
                Text("选中模块后点「存入模块库」，之后在任意泡泡里通过「添加模块 → 从模块库」复用。").font(.caption).foregroundStyle(.secondary)
            }
            List {
                ForEach(draft.library) { m in
                    HStack {
                        Text(m.type.label).font(.caption.weight(.semibold))
                        Text(m.summary).lineLimit(1).foregroundStyle(.secondary)
                        Spacer()
                        Button { draft.library.removeAll { $0.id == m.id } } label: { Image(systemName: "trash") }.buttonStyle(.borderless)
                    }
                }
            }
            .frame(minHeight: 120)
        }
    }

    private var previewModules: [BubbleModule] {
        guard itemIndex < draft.items.count else { return [] }
        let it = draft.items[itemIndex]
        if it.kind == "choice" {
            return optionIndex < it.options.count ? it.options[optionIndex].item.modules : []
        }
        return it.modules
    }

    private func moveItem(_ d: Int) {
        let j = itemIndex + d
        guard j >= 0, j < draft.items.count else { return }
        draft.items.swapAt(itemIndex, j); itemIndex = j
    }
}
