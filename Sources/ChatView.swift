// The chat window: conversation list, streamed Markdown answers with collapsible reasoning, editing and regenerating,
// file attachments, a deep-thinking switch, and the long-term memory sheet.
import AppKit
import PDFKit
import SwiftUI
import UniformTypeIdentifiers

// MARK: - Window

final class ChatPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

final class ChatWindow: NSObject, NSWindowDelegate {
    static let shared = ChatWindow()
    private var panel: ChatPanel?

    var isOpen: Bool { panel?.isVisible == true }

    func toggle(near widget: NSWindow?) { isOpen ? panel?.close() : open(near: widget) }

    /// Open next to the widget the first time (left of it, or right when the pet sits on the left edge);
    /// later the window keeps where the user put it.
    func open(near widget: NSWindow?) {
        let first = panel == nil
        let p = panel ?? make()
        panel = p
        if first, !p.setFrameUsingName("WhaleSeekChat"), let w = widget {
            let size = p.frame.size
            let vf = (w.screen ?? NSScreen.main)?.visibleFrame ?? w.frame
            let left = w.frame.midX > vf.midX
            var x = left ? w.frame.minX - size.width + w.frame.width * 0.1 : w.frame.maxX - w.frame.width * 0.1
            x = min(max(vf.minX, x), vf.maxX - size.width)
            let y = min(max(vf.minY, w.frame.minY), vf.maxY - size.height)
            p.setFrameOrigin(NSPoint(x: x, y: y))
        }
        p.setFrameAutosaveName("WhaleSeekChat")
        NSApp.activate(ignoringOtherApps: true)
        p.makeKeyAndOrderFront(nil)
    }

    private func make() -> ChatPanel {
        let p = ChatPanel(contentRect: NSRect(x: 0, y: 0, width: 860, height: 660),
                          styleMask: [.titled, .closable, .resizable, .miniaturizable, .fullSizeContentView],
                          backing: .buffered, defer: false)
        p.title = "鲸鱼娘"
        p.titlebarAppearsTransparent = true
        p.level = .floating
        p.isReleasedWhenClosed = false
        p.hidesOnDeactivate = false
        p.isFloatingPanel = true
        p.collectionBehavior = [.fullScreenAuxiliary]
        p.minSize = NSSize(width: 520, height: 420)
        p.contentViewController = NSHostingController(rootView: ChatView(model: AppModel.shared, chat: ChatSession.shared))
        p.setContentSize(NSSize(width: 860, height: 660))
        p.delegate = self
        return p
    }
}

// MARK: - Root

struct ChatView: View {
    @ObservedObject var model: AppModel
    @ObservedObject var chat: ChatSession
    @AppStorage("chatSidebar") private var showSidebar = true
    @State private var showMemory = false

    var body: some View {
        HStack(spacing: 0) {
            if showSidebar {
                ChatSidebar(chat: chat, showMemory: $showMemory)
                    .frame(width: 220)
                    .transition(.move(edge: .leading))
                Divider()
            }
            VStack(spacing: 0) {
                header
                Divider()
                ChatThread(model: model, chat: chat)
                ChatComposer(model: model, chat: chat)
            }
            .frame(minWidth: 380)
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .sheet(isPresented: $showMemory) { MemorySheet(model: model, chat: chat) }
    }

    private var header: some View {
        HStack(spacing: 10) {
            Button { withAnimation(.easeOut(duration: 0.2)) { showSidebar.toggle() } } label: { Image(systemName: "sidebar.left") }
                .buttonStyle(.borderless).help("显示 / 隐藏对话列表")
            Text(chat.current?.title ?? "新对话").font(.headline).lineLimit(1)
            Spacer()
            if chat.memoryBusy {
                HStack(spacing: 4) { ProgressView().controlSize(.mini); Text("记忆整理中").font(.caption) }.foregroundStyle(.secondary)
            }
            Button { showMemory = true } label: { Label("\(chat.memories.count)", systemImage: "brain") }
                .buttonStyle(.borderless).help("长期记忆")
            Button { chat.newChat() } label: { Image(systemName: "square.and.pencil") }
                .buttonStyle(.borderless).keyboardShortcut("n").help("新对话（⌘N）")
        }
        .padding(.horizontal, 14)
        .padding(.top, 30)          // room for the transparent title bar's buttons
        .padding(.bottom, 10)
    }
}

// MARK: - Sidebar

struct ChatSidebar: View {
    @ObservedObject var chat: ChatSession
    @Binding var showMemory: Bool
    @State private var query = ""
    @State private var renaming: Conversation?
    @State private var newTitle = ""
    @State private var confirmDeleteAll = false

    var body: some View {
        VStack(spacing: 8) {
            Button { chat.newChat() } label: {
                Label("新对话", systemImage: "plus.bubble").frame(maxWidth: .infinity)
            }
            .controlSize(.large)
            .padding(.top, 34)
            TextField("搜索对话", text: $query).textFieldStyle(.roundedBorder)
            List(selection: Binding(get: { chat.currentId }, set: { if let id = $0 { chat.select(id) } })) {
                ForEach(groups, id: \.0) { g in
                    Section(g.0) {
                        ForEach(g.1) { c in
                            Text(c.messages.isEmpty ? "新对话" : c.title).lineLimit(1).tag(c.id)
                                .contextMenu {
                                    Button("重命名…") { newTitle = c.title; renaming = c }
                                    Button("删除", role: .destructive) { chat.delete(c.id) }
                                }
                        }
                    }
                }
            }
            .listStyle(.sidebar)
            HStack {
                Button { showMemory = true } label: { Label("记忆 \(chat.memories.count)", systemImage: "brain") }
                Spacer()
                Menu {
                    Button("删除全部对话…", role: .destructive) { confirmDeleteAll = true }
                } label: { Image(systemName: "ellipsis.circle") }
                .menuStyle(.borderlessButton).fixedSize()
            }
            .buttonStyle(.borderless)
            .padding(.bottom, 10)
        }
        .padding(.horizontal, 10)
        .background(Color(nsColor: .windowBackgroundColor).opacity(0.6))
        .alert("重命名对话", isPresented: Binding(get: { renaming != nil }, set: { if !$0 { renaming = nil } })) {
            TextField("标题", text: $newTitle)
            Button("好") { if let c = renaming { chat.rename(c.id, newTitle) }; renaming = nil }
            Button("取消", role: .cancel) { renaming = nil }
        }
        .confirmationDialog("删除全部对话？此操作不能撤销。", isPresented: $confirmDeleteAll) {
            Button("删除全部", role: .destructive) { chat.deleteAll() }
        }
    }

    private var groups: [(String, [Conversation])] {
        let q = query.trimmingCharacters(in: .whitespaces).lowercased()
        let list = chat.conversations.filter { c in
            q.isEmpty || c.title.lowercased().contains(q) || c.messages.contains { $0.text.lowercased().contains(q) }
        }
        let cal = Calendar.current
        var out: [(String, [Conversation])] = []
        func add(_ name: String, _ f: (Conversation) -> Bool) {
            let items = list.filter { c in f(c) && !out.contains { $0.1.contains(c) } }
            if !items.isEmpty { out.append((name, items)) }
        }
        add("今天") { cal.isDateInToday($0.updated) }
        add("昨天") { cal.isDateInYesterday($0.updated) }
        add("7 天内") { $0.updated > Date().addingTimeInterval(-7 * 86400) }
        add("30 天内") { $0.updated > Date().addingTimeInterval(-30 * 86400) }
        add("更早") { _ in true }
        return out
    }
}

// MARK: - Thread

struct ChatThread: View {
    @ObservedObject var model: AppModel
    @ObservedObject var chat: ChatSession

    var body: some View {
        let messages = chat.current?.messages ?? []
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 18) {
                    if messages.isEmpty { WelcomeView(model: model, chat: chat) }
                    ForEach(messages) { m in
                        MessageRow(model: model, chat: chat, message: m, isLast: m.id == messages.last?.id).id(m.id)
                    }
                    if let e = chat.error { Text(e).font(.callout).foregroundStyle(.red) }
                    Color.clear.frame(height: 1).id("bottom")
                }
                .padding(.horizontal, 22)
                .padding(.vertical, 16)
                .frame(maxWidth: 820)
                .frame(maxWidth: .infinity)
            }
            .onChange(of: messages.last?.text.count ?? 0) { _ in proxy.scrollTo("bottom", anchor: .bottom) }
            .onChange(of: messages.last?.reasoning?.count ?? 0) { _ in proxy.scrollTo("bottom", anchor: .bottom) }
            .onChange(of: chat.currentId) { _ in DispatchQueue.main.async { proxy.scrollTo("bottom", anchor: .bottom) } }
            .onAppear { DispatchQueue.main.async { proxy.scrollTo("bottom", anchor: .bottom) } }
        }
    }
}

struct WhaleAvatar: View {
    var size: CGFloat = 28
    static let head: CGImage? = Atlas.shared.image(0, 6)?.cropping(to: CGRect(x: 44, y: 16, width: 104, height: 104))
    var body: some View {
        Group {
            if let img = Self.head { Image(decorative: img, scale: 1).resizable().interpolation(.high) }
            else { Text("🐋") }
        }
        .frame(width: size, height: size)
        .background(Circle().fill(Color.accentColor.opacity(0.12)))
        .clipShape(Circle())
    }
}

struct WelcomeView: View {
    @ObservedObject var model: AppModel
    @ObservedObject var chat: ChatSession
    static let suggestions = ["我今天在 AI 上花了多少钱？", "用 Python 写一个批量重命名文件的脚本", "解释一下 Transformer 的注意力机制", "你记得我什么？"]

    var body: some View {
        VStack(spacing: 14) {
            WhaleAvatar(size: 72)
            Text("老大，今天要干嘛？").font(.title2.bold())
            Text("写代码、debug、查资料、翻译、聊天都行。我会记住关于你的重要的事。")
                .font(.callout).foregroundStyle(.secondary).multilineTextAlignment(.center)
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                ForEach(Self.suggestions, id: \.self) { s in
                    Button { chat.send(s, model: model) } label: {
                        Text(s).font(.callout).frame(maxWidth: .infinity, alignment: .leading).padding(10)
                            .background(RoundedRectangle(cornerRadius: 10).stroke(Color.primary.opacity(0.12)))
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .frame(maxWidth: 520)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
    }
}

struct MessageRow: View {
    @ObservedObject var model: AppModel
    @ObservedObject var chat: ChatSession
    var message: ChatMessage
    var isLast: Bool
    @State private var hover = false
    @State private var editing = false
    @State private var draft = ""
    @State private var showReasoning = false
    @State private var copied = false

    private var streaming: Bool { chat.streamingId == message.id }

    var body: some View {
        if message.role == "user" { userRow } else { assistantRow }
    }

    private var userRow: some View {
        VStack(alignment: .trailing, spacing: 4) {
            if let files = message.files, !files.isEmpty {
                HStack { ForEach(files) { FileChip(name: $0.name) } }
            }
            if editing {
                VStack(alignment: .trailing, spacing: 6) {
                    TextEditor(text: $draft).font(.body).frame(minHeight: 60, maxHeight: 200)
                        .padding(6).background(RoundedRectangle(cornerRadius: 10).stroke(Color.accentColor))
                    HStack {
                        Button("取消") { editing = false }
                        Button("发送") { editing = false; chat.edit(message.id, text: draft, model: model) }
                            .keyboardShortcut(.defaultAction).disabled(chat.busy)
                    }
                }
            } else if !message.text.isEmpty {
                Text(message.text).textSelection(.enabled)
                    .padding(.horizontal, 12).padding(.vertical, 8)
                    .background(RoundedRectangle(cornerRadius: 14).fill(Color.accentColor.opacity(0.15)))
            }
            HStack(spacing: 10) {
                actionButton(copied ? "checkmark" : "doc.on.doc", "复制") { copy(message.text) }
                actionButton("pencil", "编辑后重新发送") { draft = message.text; editing = true }.disabled(chat.busy)
            }
            .opacity(hover && !editing ? 1 : 0)
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
        .padding(.leading, 60)
        .onHover { hover = $0 }
    }

    private var assistantRow: some View {
        HStack(alignment: .top, spacing: 10) {
            WhaleAvatar()
            VStack(alignment: .leading, spacing: 8) {
                if let r = message.reasoning, !r.isEmpty || streaming {
                    reasoningView(r)
                }
                let live = streaming && message.inner == nil && model.settings.chat.innerVoice
                    ? ChatPersona.splitAside(message.text) : (aside: message.inner, body: message.text)
                if let inner = live.aside {
                    Text("（\(inner)）").font(.callout).italic().foregroundStyle(.secondary)
                }
                if !live.body.isEmpty {
                    MarkdownView(text: live.body)
                } else if streaming && (message.reasoning ?? "").isEmpty {
                    HStack(spacing: 6) { ProgressView().controlSize(.small); Text("鲸鱼娘正在想…").foregroundStyle(.secondary) }
                }
                if let e = message.error { Text(e).font(.caption).foregroundStyle(e.hasPrefix("已停止") ? Color.secondary : Color.red) }
                if !streaming && !message.text.isEmpty {
                    HStack(spacing: 12) {
                        actionButton(copied ? "checkmark" : "doc.on.doc", "复制") { copy(message.text) }
                        if isLast { actionButton("arrow.clockwise", "重新生成") { chat.regenerate(model: model) }.disabled(chat.busy) }
                        if let m = message.model { Text(m).font(.caption2).foregroundStyle(.tertiary) }
                    }
                    .opacity(hover || isLast ? 1 : 0)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .onHover { hover = $0 }
    }

    private func reasoningView(_ r: String) -> some View {
        let thinkingNow = streaming && message.text.isEmpty
        return VStack(alignment: .leading, spacing: 6) {
            Button { showReasoning.toggle() } label: {
                HStack(spacing: 4) {
                    Image(systemName: "sparkle")
                    Text(thinkingNow ? "思考中…" : "已深度思考（用时 \(Int((message.thinkSeconds ?? 0).rounded())) 秒）")
                    Image(systemName: showReasoning || thinkingNow ? "chevron.up" : "chevron.down").font(.caption2)
                }
                .font(.caption).foregroundStyle(.secondary)
                .padding(.horizontal, 8).padding(.vertical, 4)
                .background(Capsule().fill(Color.primary.opacity(0.06)))
            }
            .buttonStyle(.plain)
            if showReasoning || thinkingNow {
                Text(r).font(.callout).foregroundStyle(.secondary).textSelection(.enabled)
                    .padding(.leading, 10)
                    .overlay(Rectangle().fill(Color.primary.opacity(0.15)).frame(width: 2), alignment: .leading)
            }
        }
    }

    private func actionButton(_ icon: String, _ help: String, _ action: @escaping () -> Void) -> some View {
        Button(action: action) { Image(systemName: icon).font(.caption) }
            .buttonStyle(.borderless).foregroundStyle(.secondary).help(help)
    }

    private func copy(_ s: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(s, forType: .string)
        copied = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { copied = false }
    }
}

struct FileChip: View {
    var name: String
    var onRemove: (() -> Void)? = nil
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "doc.text")
            Text(name).lineLimit(1)
            if let onRemove { Button(action: onRemove) { Image(systemName: "xmark.circle.fill") }.buttonStyle(.borderless) }
        }
        .font(.caption)
        .padding(.horizontal, 8).padding(.vertical, 4)
        .background(Capsule().fill(Color.primary.opacity(0.07)))
    }
}

// MARK: - Composer

struct ChatComposer: View {
    @ObservedObject var model: AppModel
    @ObservedObject var chat: ChatSession
    @State private var draft = ""
    @State private var files: [ChatFile] = []
    @State private var fileError: String?
    @FocusState private var focused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !files.isEmpty {
                HStack { ForEach(files) { f in FileChip(name: f.name) { files.removeAll { $0.id == f.id } } } }
            }
            if let e = fileError { Text(e).font(.caption).foregroundStyle(.red) }
            if model.deepseekKey == nil {
                HStack {
                    Text("聊天要用 DeepSeek 密钥").font(.callout)
                    Spacer()
                    Button("去设置") { Windows.settings(tab: .deepseek) }
                }
            } else {
                TextField("给鲸鱼娘发消息（↩ 发送，⌥↩ 换行）", text: $draft, axis: .vertical)
                    .textFieldStyle(.plain)
                    .lineLimit(1...10)
                    .focused($focused)
                    .onSubmit(send)
                HStack(spacing: 10) {
                    Button(action: pickFiles) { Image(systemName: "paperclip") }.buttonStyle(.borderless).help("添加文件（文本、代码、PDF）")
                    Toggle(isOn: $model.settings.chat.thinking) { Label("深度思考", systemImage: "sparkle") }
                        .toggleStyle(.button).controlSize(.small)
                    Menu(ChatTab.models.first { $0.0 == model.settings.chat.model }?.1 ?? model.settings.chat.model) {
                        ForEach(ChatTab.models, id: \.0) { m in Button(m.1) { model.settings.chat.model = m.0 } }
                    }
                    .menuStyle(.borderlessButton).fixedSize().font(.caption)
                    Spacer()
                    if chat.busy {
                        Button(action: chat.stop) { Image(systemName: "stop.circle.fill").font(.title2) }
                            .buttonStyle(.borderless).help("停止生成")
                    } else {
                        Button(action: send) { Image(systemName: "arrow.up.circle.fill").font(.title2) }
                            .buttonStyle(.borderless)
                            .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && files.isEmpty)
                    }
                }
            }
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 14).fill(Color(nsColor: .textBackgroundColor)))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.primary.opacity(0.12)))
        .padding(.horizontal, 16).padding(.bottom, 14).padding(.top, 6)
        .frame(maxWidth: 820)
        .frame(maxWidth: .infinity)
        .onAppear { focused = true }
        .onChange(of: chat.currentId) { _ in focused = true }
        .onDrop(of: [.fileURL], isTargeted: nil) { providers in
            for p in providers {
                _ = p.loadObject(ofClass: URL.self) { url, _ in
                    if let url { DispatchQueue.main.async { add(url) } }
                }
            }
            return true
        }
    }

    private func send() {
        guard !chat.busy else { return }
        let t = draft, f = files
        guard !t.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !f.isEmpty else { return }
        draft = ""; files = []; fileError = nil
        chat.send(t, files: f, model: model)
    }

    private func pickFiles() {
        let p = NSOpenPanel()
        p.allowsMultipleSelection = true
        p.canChooseDirectories = false
        if p.runModal() == .OK { p.urls.forEach(add) }
    }

    /// Read a text, code or PDF file as an attachment (up to 200 KB of text).
    private func add(_ url: URL) {
        fileError = nil
        var text: String?
        if url.pathExtension.lowercased() == "pdf" { text = PDFDocument(url: url)?.string }
        else if let d = try? Data(contentsOf: url), d.count <= 2_000_000 {
            text = String(data: d, encoding: .utf8) ?? String(data: d, encoding: .utf16)
        }
        guard var t = text, !t.contains("\u{0}") else { fileError = "「\(url.lastPathComponent)」不是文本文件，读不了"; return }
        if t.count > 200_000 { t = String(t.prefix(200_000)); fileError = "「\(url.lastPathComponent)」太长，只带上前 20 万字" }
        files.append(ChatFile(name: url.lastPathComponent, text: t))
    }
}

// MARK: - Markdown

struct MarkdownView: View {
    var text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(Array(Markdown.blocks(text).enumerated()), id: \.offset) { _, b in block(b) }
        }
        .textSelection(.enabled)
    }

    static func inline(_ s: String) -> AttributedString {
        (try? AttributedString(markdown: s, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace))) ?? AttributedString(s)
    }

    @ViewBuilder private func block(_ b: MDBlock) -> some View {
        switch b {
        case .heading(let level, let t):
            Text(Self.inline(t)).font(level == 1 ? .title2.bold() : level == 2 ? .title3.bold() : .headline).padding(.top, 4)
        case .paragraph(let t):
            Text(Self.inline(t)).fixedSize(horizontal: false, vertical: true).lineSpacing(3)
        case .code(let lang, let code):
            CodeBlock(lang: lang, code: code)
        case .list(let items):
            VStack(alignment: .leading, spacing: 5) {
                ForEach(Array(items.enumerated()), id: \.offset) { _, it in
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text(it.marker).foregroundStyle(.secondary).frame(minWidth: 14, alignment: .trailing)
                        Text(Self.inline(it.text)).fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.leading, CGFloat(it.depth) * 16)
                }
            }
        case .quote(let t):
            Text(Self.inline(t)).foregroundStyle(.secondary).padding(.leading, 10)
                .overlay(Rectangle().fill(Color.accentColor.opacity(0.5)).frame(width: 3), alignment: .leading)
        case .table(let header, let rows):
            ScrollView(.horizontal) {
                Grid(alignment: .leading, horizontalSpacing: 14, verticalSpacing: 6) {
                    GridRow { ForEach(Array(header.enumerated()), id: \.offset) { Text(Self.inline($0.element)).bold() } }
                    Divider()
                    ForEach(Array(rows.enumerated()), id: \.offset) { _, r in
                        GridRow { ForEach(Array(r.enumerated()), id: \.offset) { Text(Self.inline($0.element)) } }
                    }
                }
                .padding(10)
            }
            .background(RoundedRectangle(cornerRadius: 8).stroke(Color.primary.opacity(0.12)))
        case .rule:
            Divider()
        }
    }
}

struct CodeBlock: View {
    var lang: String
    var code: String
    @State private var copied = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(lang.isEmpty ? "代码" : lang).font(.caption).foregroundStyle(.secondary)
                Spacer()
                Button {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(code, forType: .string)
                    copied = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { copied = false }
                } label: { Label(copied ? "已复制" : "复制", systemImage: copied ? "checkmark" : "doc.on.doc").font(.caption) }
                .buttonStyle(.borderless)
            }
            .padding(.horizontal, 10).padding(.vertical, 6)
            .background(Color.primary.opacity(0.06))
            ScrollView(.horizontal) {
                Text(code).font(.system(.callout, design: .monospaced)).textSelection(.enabled)
                    .fixedSize(horizontal: true, vertical: true)
                    .padding(10)
            }
        }
        .background(RoundedRectangle(cornerRadius: 8).fill(Color.primary.opacity(0.04)))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.primary.opacity(0.1)))
    }
}

// MARK: - Memory

struct MemorySheet: View {
    @ObservedObject var model: AppModel
    @ObservedObject var chat: ChatSession
    @Environment(\.dismiss) private var dismiss
    @State private var newItem = ""
    @State private var confirmClear = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("长期记忆").font(.title3.bold())
                Spacer()
                Toggle("自动记忆", isOn: $model.settings.chat.memoryOn).toggleStyle(.switch)
            }
            Text("每次聊完，鲸鱼娘会自动整理出值得长期记住的事（你的身份、项目、偏好、让她记住的事），之后的每个对话都会带上。密码、密钥这类敏感信息不会记。你也可以直接对她说「记住…」或「忘掉…」。")
                .font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            List {
                ForEach(chat.memories) { m in MemoryRow(chat: chat, item: m) }
                if chat.memories.isEmpty { Text("还没有记忆").foregroundStyle(.secondary) }
            }
            .frame(minHeight: 240)
            HStack {
                TextField("手动添加一条，例如：老大喜欢用 Swift", text: $newItem).onSubmit(add)
                Button("添加", action: add).disabled(newItem.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            HStack {
                Button("清空全部记忆", role: .destructive) { confirmClear = true }.disabled(chat.memories.isEmpty)
                Spacer()
                Button("完成") { dismiss() }.keyboardShortcut(.defaultAction)
            }
        }
        .padding(18)
        .frame(width: 520, height: 520)
        .confirmationDialog("清空全部记忆？", isPresented: $confirmClear) {
            Button("清空", role: .destructive) { chat.setMemories([]) }
        }
    }

    private func add() { chat.addMemory(newItem); newItem = "" }
}

struct MemoryRow: View {
    @ObservedObject var chat: ChatSession
    var item: MemoryItem
    @State private var text = ""

    var body: some View {
        HStack {
            TextField("", text: $text).textFieldStyle(.plain).onSubmit { chat.editMemory(item.id, text) }
            Text(item.ts.formatted(date: .numeric, time: .omitted)).font(.caption2).foregroundStyle(.tertiary)
            Button { chat.deleteMemory(item.id) } label: { Image(systemName: "trash") }.buttonStyle(.borderless)
        }
        .onAppear { text = item.text }
        .onChange(of: item.text) { text = $0 }
    }
}
