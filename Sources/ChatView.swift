// The chat panel: a small floating window next to the pet with the conversation and an input field.
import AppKit
import SwiftUI

struct ChatView: View {
    @ObservedObject var model: AppModel
    @ObservedObject var chat: ChatSession
    @State private var draft = ""
    @FocusState private var focused: Bool

    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 10) {
                        if chat.messages.isEmpty {
                            Text("跟鲸鱼娘说点什么吧～\n比如「我今天花了多少钱？」")
                                .font(.callout).foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity).padding(.top, 40).multilineTextAlignment(.center)
                        }
                        ForEach(chat.messages) { row($0).id($0.id) }
                        if chat.busy {
                            HStack(spacing: 6) { ProgressView().controlSize(.small); Text("鲸鱼娘正在想…").foregroundStyle(.secondary) }
                                .font(.callout).id("busy")
                        }
                        if let e = chat.error { Text(e).font(.callout).foregroundStyle(.red).id("error") }
                    }
                    .padding(12)
                }
                .onChange(of: chat.messages.count) { _ in scrollToEnd(proxy) }
                .onChange(of: chat.busy) { _ in scrollToEnd(proxy) }
                .onAppear { scrollToEnd(proxy) }
            }
            Divider()
            if model.deepseekKey == nil {
                HStack {
                    Text("聊天要用 DeepSeek 密钥").font(.callout)
                    Spacer()
                    Button("去设置") { Windows.settings(tab: .deepseek) }
                }
                .padding(10)
            } else {
                HStack(spacing: 8) {
                    TextField("和鲸鱼娘说…", text: $draft)
                        .textFieldStyle(.roundedBorder)
                        .focused($focused)
                        .onSubmit(send)
                    Button(action: send) { Image(systemName: "paperplane.fill") }
                        .disabled(chat.busy || draft.trimmingCharacters(in: .whitespaces).isEmpty)
                        .keyboardShortcut(.defaultAction)
                }
                .padding(10)
            }
        }
        .frame(minWidth: 280, minHeight: 300)
        .onAppear { focused = true }
    }

    @ViewBuilder private func row(_ m: ChatMessage) -> some View {
        if m.role == "user" {
            HStack { Spacer(minLength: 40); bubble(m.text, bg: Color.accentColor, fg: .white) }
        } else {
            VStack(alignment: .leading, spacing: 3) {
                if let inner = m.inner {
                    Text("（\(inner)）").font(.caption).italic().foregroundStyle(.secondary)
                }
                HStack { bubble(m.text, bg: Color(nsColor: .controlBackgroundColor), fg: .primary); Spacer(minLength: 40) }
            }
        }
    }

    private func bubble(_ t: String, bg: Color, fg: Color) -> some View {
        Text(t).textSelection(.enabled).foregroundStyle(fg)
            .padding(.horizontal, 10).padding(.vertical, 7)
            .background(RoundedRectangle(cornerRadius: 12).fill(bg))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.primary.opacity(0.08)))
    }

    private func send() {
        guard !chat.busy else { return }
        let t = draft
        draft = ""
        chat.send(t, model: model)
    }

    private func scrollToEnd(_ proxy: ScrollViewProxy) {
        DispatchQueue.main.async {
            withAnimation(.easeOut(duration: 0.2)) {
                if chat.error != nil { proxy.scrollTo("error", anchor: .bottom) }
                else if chat.busy { proxy.scrollTo("busy", anchor: .bottom) }
                else if let last = chat.messages.last { proxy.scrollTo(last.id, anchor: .bottom) }
            }
        }
    }
}

/// A floating panel that takes keyboard input without pulling the app's other windows forward.
final class ChatPanel: NSPanel {
    override var canBecomeKey: Bool { true }
}

final class ChatWindow: NSObject, NSWindowDelegate {
    static let shared = ChatWindow()
    private var panel: ChatPanel?

    var isOpen: Bool { panel?.isVisible == true }

    /// Open next to the widget (left of it, or right when the pet sits on the left edge).
    func toggle(near widget: NSWindow?) { isOpen ? panel?.close() : open(near: widget) }

    func open(near widget: NSWindow?) {
        let p = panel ?? make()
        panel = p
        if let w = widget {
            let size = p.frame.size
            let vf = (w.screen ?? NSScreen.main)?.visibleFrame ?? w.frame
            let left = w.frame.midX > vf.midX
            var x = left ? w.frame.minX - size.width + w.frame.width * 0.1 : w.frame.maxX - w.frame.width * 0.1
            x = min(max(vf.minX, x), vf.maxX - size.width)
            let y = min(max(vf.minY, w.frame.minY), vf.maxY - size.height)
            p.setFrameOrigin(NSPoint(x: x, y: y))
        }
        p.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func make() -> ChatPanel {
        let p = ChatPanel(contentRect: NSRect(x: 0, y: 0, width: 320, height: 420),
                          styleMask: [.titled, .closable, .resizable, .utilityWindow, .nonactivatingPanel],
                          backing: .buffered, defer: false)
        p.title = "和鲸鱼娘聊天"
        p.level = .floating
        p.isReleasedWhenClosed = false
        p.hidesOnDeactivate = false
        p.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        p.contentViewController = NSHostingController(rootView: ChatView(model: AppModel.shared, chat: ChatSession.shared))
        p.setContentSize(NSSize(width: 320, height: 420))
        p.delegate = self
        return p
    }
}
