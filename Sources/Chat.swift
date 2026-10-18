// Chat session: conversations with the whale girl over the DeepSeek chat API (streamed), long-term memory
// extraction after each reply, conversation titles, and short AI remarks in the pet's bubble.
import Foundation

enum ChatClient {
    static let url = URL(string: "https://api.deepseek.com/chat/completions")!

    struct Reply { var text = ""; var reasoning: String? }

    private static func request(key: String, body: [String: Any], timeout: Double) throws -> URLRequest {
        var req = URLRequest(url: url, timeoutInterval: timeout)
        req.httpMethod = "POST"
        req.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        return req
    }

    private static func body(model: String, messages: [[String: String]], thinking: Bool, maxTokens: Int?, stream: Bool) -> [String: Any] {
        var b: [String: Any] = ["model": model, "messages": messages, "stream": stream,
                                "thinking": ["type": thinking ? "enabled" : "disabled"]]
        if let maxTokens { b["max_tokens"] = maxTokens }
        if !thinking { b["temperature"] = 1.0 }
        return b
    }

    /// One complete answer (used for bubble remarks, titles and memory extraction).
    static func complete(key: String, model: String, messages: [[String: String]], thinking: Bool, maxTokens: Int,
                         json: Bool = false) async throws -> Reply {
        var b = body(model: model, messages: messages, thinking: thinking, maxTokens: thinking ? maxTokens + 1500 : maxTokens, stream: false)
        if thinking { b["reasoning_effort"] = "low" }
        if json { b["response_format"] = ["type": "json_object"] }
        let (data, resp) = try await URLSession.shared.data(for: request(key: key, body: b, timeout: thinking ? 60 : 30))
        let code = (resp as? HTTPURLResponse)?.statusCode ?? 0
        let obj = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
        guard code == 200 else { throw ChatError(code: code, message: errorMessage(obj, data)) }
        guard let msg = ((obj?["choices"] as? [[String: Any]])?.first?["message"]) as? [String: Any],
              let text = msg["content"] as? String else { throw ChatError(code: code, message: "返回内容看不懂") }
        return Reply(text: text, reasoning: msg["reasoning_content"] as? String)
    }

    /// Streamed answer: `onDelta(reasoningDelta, contentDelta)` is called for every chunk.
    static func stream(key: String, model: String, messages: [[String: String]], thinking: Bool,
                       onDelta: @escaping (String, String) -> Void) async throws {
        let req = try request(key: key, body: body(model: model, messages: messages, thinking: thinking, maxTokens: nil, stream: true), timeout: 120)
        let (bytes, resp) = try await URLSession.shared.bytes(for: req)
        let code = (resp as? HTTPURLResponse)?.statusCode ?? 0
        guard code == 200 else {
            var data = Data()
            for try await b in bytes { data.append(b); if data.count > 4000 { break } }
            throw ChatError(code: code, message: errorMessage((try? JSONSerialization.jsonObject(with: data)) as? [String: Any], data))
        }
        for try await line in bytes.lines {
            try Task.checkCancellation()
            guard line.hasPrefix("data:") else { continue }
            let payload = line.dropFirst(5).trimmingCharacters(in: .whitespaces)
            if payload == "[DONE]" { break }
            guard let obj = try? JSONSerialization.jsonObject(with: Data(payload.utf8)) as? [String: Any],
                  let delta = ((obj["choices"] as? [[String: Any]])?.first?["delta"]) as? [String: Any] else { continue }
            let r = delta["reasoning_content"] as? String ?? "", c = delta["content"] as? String ?? ""
            if !r.isEmpty || !c.isEmpty { onDelta(r, c) }
        }
    }

    private static func errorMessage(_ obj: [String: Any]?, _ data: Data) -> String {
        ((obj?["error"] as? [String: Any])?["message"] as? String) ?? String(data: data.prefix(200), encoding: .utf8) ?? ""
    }
}

struct ChatError: LocalizedError {
    var code: Int
    var message: String
    var errorDescription: String? {
        switch code {
        case 401: return "密钥不对，DeepSeek 不认识我（401）"
        case 402: return "余额不足，真·没米了（402）"
        case 429: return "说得太快啦，歇一会儿再聊（429）"
        case 500...599: return "DeepSeek 服务器在打瞌睡（\(code)）"
        case 0: return message
        default: return "出错了（\(code)）：\(message)"
        }
    }
}

final class ChatSession: ObservableObject {
    static let shared = ChatSession()
    private let store = ChatStore()

    @Published private(set) var conversations: [Conversation] = []
    @Published var currentId: UUID?
    @Published private(set) var memories: [MemoryItem] = []
    @Published private(set) var streamingId: UUID?      // the assistant message being written
    @Published private(set) var remarking = false
    @Published private(set) var memoryBusy = false
    @Published var error: String?

    private var task: Task<Void, Never>?
    private var memoryQueue: [[ChatMessage]] = []

    init() {
        conversations = store.conversations
        memories = store.memories
        currentId = conversations.first?.id
    }

    var busy: Bool { streamingId != nil }
    var current: Conversation? { conversations.first { $0.id == currentId } }

    // MARK: Conversations

    func newChat() {
        stop()
        error = nil
        if let empty = conversations.first(where: { $0.messages.isEmpty }) { currentId = empty.id; return }
        let c = Conversation()
        conversations.insert(c, at: 0)
        currentId = c.id
    }

    func select(_ id: UUID) {
        if id != currentId { stop() }
        currentId = id
        error = nil
        conversations.removeAll { $0.messages.isEmpty && $0.id != id }   // drop unused empty chats
    }

    func rename(_ id: UUID, _ title: String) {
        guard var c = conversations.first(where: { $0.id == id }) else { return }
        let t = title.trimmingCharacters(in: .whitespaces)
        guard !t.isEmpty else { return }
        c.title = t; c.titled = true
        put(c)
    }

    func delete(_ id: UUID) {
        if id == currentId { stop() }
        store.delete(id)
        conversations.removeAll { $0.id == id }
        if currentId == id { currentId = conversations.first?.id }
    }

    func deleteAll() { stop(); store.deleteAll(); conversations = []; currentId = nil }

    private func put(_ c: Conversation, persist: Bool = true) {
        if let i = conversations.firstIndex(where: { $0.id == c.id }) { conversations[i] = c } else { conversations.insert(c, at: 0) }
        if persist && !c.messages.isEmpty { store.save(c) }
    }

    /// Mark a conversation as just used and move it to the top of the list.
    private func touch(_ c: inout Conversation) {
        c.updated = Date()
        if let i = conversations.firstIndex(where: { $0.id == c.id }), i != 0 {
            conversations.remove(at: i); conversations.insert(c, at: 0)
        }
    }

    // MARK: Memories

    func setMemories(_ m: [MemoryItem]) { store.setMemories(m); memories = m }
    func deleteMemory(_ id: String) { setMemories(memories.filter { $0.id != id }) }
    func editMemory(_ id: String, _ text: String) {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { deleteMemory(id); return }
        var m = memories
        if let i = m.firstIndex(where: { $0.id == id }) { m[i].text = t; m[i].ts = Date() }
        setMemories(m)
    }
    func addMemory(_ text: String) {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return }
        setMemories(memories + [MemoryItem(text: t)])
    }

    // MARK: Context

    func context(_ m: AppModel) -> ChatContext {
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN"); f.dateFormat = "yyyy年M月d日 EEEE HH:mm"
        let peak = Pricing.isPeak(m.now)
        var c = ChatContext(now: f.string(from: Date()),
                            peak: "DeepSeek " + (peak ? "高峰时段（贵）" : "低谷时段（便宜）") + "，\(Pricing.countdown(m.now)) 后切换")
        if m.balance != nil { c.balance = m.amountText(m.balance) }
        if m.today != nil { c.todayCost = m.todayText }
        let subs = m.subscriptionOverview
        c.subscriptions = subs.isEmpty ? "没检测到" : subs.joined(separator: "；")
        if let e = m.autoPlayer.recentEvent { c.recentEvent = e }
        return c
    }

    // MARK: Sending

    func send(_ text: String, files: [ChatFile] = [], model m: AppModel) {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty || !files.isEmpty, !busy else { return }
        if current == nil { newChat() }
        guard var c = current else { return }
        c.messages.append(ChatMessage(role: "user", text: t, files: files.isEmpty ? nil : files))
        touch(&c)
        put(c)
        respond(in: c.id, model: m)
    }

    /// Ask again for the last answer.
    func regenerate(model m: AppModel) {
        guard !busy, var c = current else { return }
        while let last = c.messages.last, last.role == "assistant" { c.messages.removeLast() }
        guard c.messages.last?.role == "user" else { return }
        put(c)
        respond(in: c.id, model: m)
    }

    /// Replace a user message, drop everything after it, then answer again.
    func edit(_ messageId: UUID, text: String, model m: AppModel) {
        guard !busy, var c = current, let i = c.messages.firstIndex(where: { $0.id == messageId }) else { return }
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return }
        c.messages[i].text = t
        c.messages[i].ts = Date()
        c.messages.removeSubrange((i + 1)...)
        touch(&c)
        put(c)
        respond(in: c.id, model: m)
    }

    func stop() {
        task?.cancel()
        task = nil
    }

    private func respond(in convId: UUID, model m: AppModel) {
        guard let key = m.deepseekKey, !key.isEmpty else { error = "先在设置 → DeepSeek 里填好密钥"; return }
        guard var c = conversations.first(where: { $0.id == convId }) else { return }
        let cfg = m.settings.chat
        let system = ChatPersona.system(context(m), bubble: false, memories: cfg.memoryOn ? memories : [], inner: cfg.innerVoice)
        let msgs = ChatPersona.messages(system: system, history: c.messages, keep: cfg.historyMessages)
        let reply = ChatMessage(role: "assistant", text: "", reasoning: cfg.thinking ? "" : nil, model: cfg.model)
        c.messages.append(reply)
        put(c, persist: false)
        streamingId = reply.id
        error = nil
        m.playRole(.think, for: 120)

        task = Task { [weak self] in
            let acc = StreamAccumulator(reply, thinking: cfg.thinking)
            do {
                try await ChatClient.stream(key: key, model: cfg.model, messages: msgs, thinking: cfg.thinking) { r, t in
                    if let snap = acc.add(r, t) { DispatchQueue.main.async { ChatSession.shared.update(snap, in: convId) } }
                }
            } catch is CancellationError {
            } catch let e as URLError where e.code == .cancelled {
            } catch {
                acc.fail((error as? LocalizedError)?.errorDescription ?? error.localizedDescription)
            }
            let final = acc.finish(innerVoice: cfg.innerVoice, cancelled: Task.isCancelled)
            guard let self else { return }
            await MainActor.run { self.finish(final, in: convId, model: m) }
        }
    }

    private func update(_ msg: ChatMessage, in convId: UUID, persist: Bool = false) {
        guard var c = conversations.first(where: { $0.id == convId }),
              let i = c.messages.firstIndex(where: { $0.id == msg.id }) else { return }
        c.messages[i] = msg
        put(c, persist: persist)
    }

    private func finish(_ msg: ChatMessage, in convId: UUID, model m: AppModel) {
        update(msg, in: convId, persist: true)
        if streamingId == msg.id { streamingId = nil; task = nil }
        if msg.error != nil && msg.text.isEmpty { m.playRole(.sulk, for: 2); return }
        m.playRole(.wave, for: 2)
        guard let c = conversations.first(where: { $0.id == convId }) else { return }
        if !c.titled { makeTitle(c, model: m) }
        if m.settings.chat.memoryOn, msg.error == nil, let lastUser = c.messages.last(where: { $0.role == "user" }) {
            remember([lastUser, msg], model: m)
        }
    }

    // MARK: Titles

    private func makeTitle(_ c: Conversation, model m: AppModel) {
        guard let key = m.deepseekKey, let first = c.messages.first(where: { $0.role == "user" }) else { return }
        var t = c
        t.title = ChatPersona.fallbackTitle(first.text.isEmpty ? (first.files?.first?.name ?? "") : first.text)
        t.titled = true
        put(t)
        let answer = c.messages.first { $0.role == "assistant" }?.text ?? ""
        let talk = "老大：" + ChatPersona.cut(ChatPersona.userContent(first), limit: 300) + "\n鲸鱼娘：" + ChatPersona.cut(answer, limit: 300)
        Task { [weak self] in
            guard let r = try? await ChatClient.complete(key: key, model: "deepseek-flash",
                                                          messages: [["role": "system", "content": ChatPersona.titlePrompt],
                                                                     ["role": "user", "content": talk]], thinking: false, maxTokens: 30) else { return }
            let title = ChatPersona.cleanTitle(r.text)
            guard !title.isEmpty, let self else { return }
            await MainActor.run {
                guard var cur = self.conversations.first(where: { $0.id == c.id }) else { return }
                cur.title = title
                self.put(cur)
            }
        }
    }

    // MARK: Long-term memory

    private func remember(_ exchange: [ChatMessage], model m: AppModel) {
        memoryQueue.append(exchange)
        runMemory(model: m)
    }

    private func runMemory(model m: AppModel) {
        guard !memoryBusy, !memoryQueue.isEmpty, let key = m.deepseekKey else { return }
        let exchange = memoryQueue.removeFirst()
        memoryBusy = true
        let prompt = ChatMemory.extractPrompt(memories: memories, exchange: exchange)
        Task { [weak self] in
            let r = try? await ChatClient.complete(key: key, model: "deepseek-flash",
                                                   messages: [["role": "user", "content": prompt]], thinking: false,
                                                   maxTokens: 600, json: true)
            guard let self else { return }
            await MainActor.run {
                if let text = r?.text, let ops = ChatMemory.parse(text), !ops.isEmpty {
                    self.setMemories(ChatMemory.apply(ops, to: self.memories))
                }
                self.memoryBusy = false
                self.runMemory(model: m)
            }
        }
    }

    // MARK: Bubble remarks

    /// She speaks up on her own in the bubble (autoplay). Returns false when chat is unavailable.
    @discardableResult func remark(model m: AppModel) -> Bool {
        guard m.settings.chat.on, !remarking, let key = m.deepseekKey else { return false }
        let cfg = m.settings.chat
        let system = ChatPersona.system(context(m), bubble: true, memories: cfg.memoryOn ? memories : [], inner: cfg.innerVoice)
        let msgs = [["role": "system", "content": system], ["role": "user", "content": ChatPersona.remarkPrompt]]
        remarking = true
        Task { [weak self] in
            let r = try? await ChatClient.complete(key: key, model: cfg.model, messages: msgs, thinking: cfg.innerVoice, maxTokens: 120)
            guard let self else { return }
            await MainActor.run {
                self.remarking = false
                guard let r else { return }
                let text = ChatPersona.clean(r.text, limit: ChatPersona.bubbleLimit)
                guard !text.isEmpty else { return }
                var mods = [BubbleDefaults.text(text, size: 7)]
                if cfg.innerVoice, let inner = ChatPersona.innerVoice(r.reasoning) {
                    mods.insert(BubbleDefaults.text("（\(inner)）", size: 5, bold: false, color: "#8a93b8"), at: 0)
                }
                m.showAlert(kind: "remark", modules: mods, closeSec: max(6, Double(text.count) * 0.25),
                            role: .wave, sound: !m.settings.autoPlay.silent)
            }
        }
        return true
    }

    /// Development aid (--snapshot): show the given conversations and memories without touching disk.
    func showDemo(_ list: [Conversation], memories mem: [MemoryItem]) {
        conversations = list; currentId = list.first?.id; memories = mem
    }

    /// Development aid (--chat-test): run the prompts as one conversation, print, and quit. "-" asks for a bubble remark.
    /// Nothing is saved; extracted memories are applied for the rest of the run only.
    func devTest(_ prompts: [String], model m: AppModel) {
        guard let key = m.deepseekKey else { print("no DeepSeek key in the Keychain"); exit(1) }
        let cfg = m.settings.chat, ctx = context(m)
        print("model: \(cfg.model)  thinking: \(cfg.thinking)  memories: \(memories.count)\n")
        Task {
            var history: [ChatMessage] = []
            var memories = self.memories
            for p in prompts {
                let t0 = Date()
                do {
                    if p == "-" {
                        let sys = ChatPersona.system(ctx, bubble: true, memories: memories, inner: cfg.innerVoice)
                        let r = try await ChatClient.complete(key: key, model: cfg.model,
                                                              messages: [["role": "system", "content": sys], ["role": "user", "content": ChatPersona.remarkPrompt]],
                                                              thinking: cfg.innerVoice, maxTokens: 120)
                        print("[气泡] \(ChatPersona.clean(r.text, limit: ChatPersona.bubbleLimit))  心声: \(ChatPersona.innerVoice(r.reasoning) ?? "—")\n===")
                        continue
                    }
                    history.append(ChatMessage(role: "user", text: p))
                    let sys = ChatPersona.system(ctx, bubble: false, memories: memories, inner: cfg.innerVoice)
                    let acc = StreamAccumulator(ChatMessage(role: "assistant", text: ""), thinking: cfg.thinking)
                    var firstToken: Date?
                    try await ChatClient.stream(key: key, model: cfg.model,
                                                messages: ChatPersona.messages(system: sys, history: history, keep: cfg.historyMessages),
                                                thinking: cfg.thinking) { r, c in
                        if firstToken == nil { firstToken = Date() }
                        _ = acc.add(r, c)
                    }
                    let reply = acc.finish(innerVoice: cfg.innerVoice, cancelled: false)
                    print("老大: \(p)\n鲸鱼娘 [首字 \(String(format: "%.1f", firstToken?.timeIntervalSince(t0) ?? 0))s, 共 \(String(format: "%.1f", Date().timeIntervalSince(t0)))s, 思考 \(String(format: "%.1f", reply.thinkSeconds ?? 0))s, \(reply.text.count) 字]:\n\(reply.text)")
                    print("心声: \(reply.inner ?? "—")\n---")
                    history.append(reply)
                    let mem = try await ChatClient.complete(key: key, model: "deepseek-flash",
                                                            messages: [["role": "user", "content": ChatMemory.extractPrompt(memories: memories, exchange: Array(history.suffix(2)))]],
                                                            thinking: false, maxTokens: 600, json: true)
                    print("记忆提取: \(mem.text.replacingOccurrences(of: "\n", with: " "))\n===")
                    if let ops = ChatMemory.parse(mem.text) { memories = ChatMemory.apply(ops, to: memories) }
                } catch { print("error: \((error as? LocalizedError)?.errorDescription ?? "\(error)")") }
            }
            exit(0)
        }
    }
}

/// Collects streamed deltas into a message and hands out throttled snapshots for the UI.
final class StreamAccumulator {
    private var msg: ChatMessage
    private let thinking: Bool
    private let started = Date()
    private var answerStarted: Date?
    private var lastSnapshot = Date.distantPast
    private let lock = NSLock()

    init(_ msg: ChatMessage, thinking: Bool) { self.msg = msg; self.thinking = thinking }

    /// Returns a snapshot at most every 50 ms.
    func add(_ reasoning: String, _ text: String) -> ChatMessage? {
        lock.lock(); defer { lock.unlock() }
        if thinking { msg.reasoning = (msg.reasoning ?? "") + reasoning }
        if !text.isEmpty, answerStarted == nil { answerStarted = Date() }
        msg.text += text
        guard Date().timeIntervalSince(lastSnapshot) > 0.05 else { return nil }
        lastSnapshot = Date()
        return msg
    }

    func fail(_ e: String) { lock.lock(); msg.error = e; lock.unlock() }

    /// `innerVoice`: take the answer's leading "（…）" aside as her inner voice.
    func finish(innerVoice: Bool, cancelled: Bool) -> ChatMessage {
        lock.lock(); defer { lock.unlock() }
        if let r = msg.reasoning, !r.isEmpty {
            msg.thinkSeconds = (answerStarted ?? Date()).timeIntervalSince(started)
        } else { msg.reasoning = nil }
        if innerVoice {
            let (aside, body) = ChatPersona.splitAside(msg.text)
            if let aside, !body.isEmpty { msg.inner = ChatPersona.cut(aside, limit: 30); msg.text = body }
        }
        if cancelled && msg.error == nil { msg.error = msg.text.isEmpty ? "已停止" : "已停止生成" }
        return msg
    }
}
