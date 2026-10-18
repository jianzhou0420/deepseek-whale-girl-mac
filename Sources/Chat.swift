// Chat session: talks to the DeepSeek chat API with the persona prompt and live usage numbers,
// keeps the history in chat.json, and drives the pet (thinking pose, reply animation, remarks in the bubble).
import Foundation

enum ChatClient {
    static let url = URL(string: "https://api.deepseek.com/chat/completions")!

    struct Reply { var text: String; var reasoning: String? }

    static func complete(key: String, model: String, messages: [[String: String]], thinking: Bool, maxTokens: Int) async throws -> Reply {
        var req = URLRequest(url: url, timeoutInterval: thinking ? 60 : 30)
        req.httpMethod = "POST"
        req.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        var body: [String: Any] = ["model": model, "messages": messages, "stream": false,
                                   "max_tokens": thinking ? maxTokens + 1500 : maxTokens,
                                   "thinking": ["type": thinking ? "enabled" : "disabled"]]
        if thinking { body["reasoning_effort"] = "low" } else { body["temperature"] = 1.1 }
        req.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, resp) = try await URLSession.shared.data(for: req)
        let code = (resp as? HTTPURLResponse)?.statusCode ?? 0
        let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
        guard code == 200 else {
            let msg = ((json?["error"] as? [String: Any])?["message"] as? String) ?? String(data: data.prefix(200), encoding: .utf8) ?? ""
            throw ChatError(code: code, message: msg)
        }
        guard let msg = ((json?["choices"] as? [[String: Any]])?.first?["message"]) as? [String: Any],
              let text = msg["content"] as? String else { throw ChatError(code: code, message: "返回内容看不懂") }
        return Reply(text: text, reasoning: msg["reasoning_content"] as? String)
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
    @Published private(set) var messages: [ChatMessage] = Store.load("chat.json", default: [ChatMessage]())
    @Published private(set) var busy = false
    @Published var error: String?

    private func save() {
        if messages.count > 200 { messages = Array(messages.suffix(200)) }
        Store.save("chat.json", messages)
    }

    func clear() { messages = []; error = nil; save() }

    func context(_ m: AppModel) -> ChatContext {
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN"); f.dateFormat = "M月d日 EEEE HH:mm"
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

    /// The user typed something in the chat panel.
    func send(_ text: String, model m: AppModel) {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty, !busy else { return }
        let history = messages
        messages.append(ChatMessage(role: "user", text: t))
        save()
        ask(t, history: history, length: .panel, model: m) { [weak self] reply in
            guard let self else { return }
            self.messages.append(reply)
            self.save()
            m.playRole(reply.text.contains("哼") ? .sulk : .wave, for: 2)
        }
    }

    /// She speaks up on her own in the bubble (autoplay). Returns false when chat is unavailable.
    @discardableResult func remark(model m: AppModel) -> Bool {
        guard m.settings.chat.on, !busy, m.deepseekKey != nil else { return false }
        ask(ChatPersona.remarkPrompt, history: messages, length: .bubble, model: m) { [weak self] reply in
            guard let self else { return }
            self.messages.append(reply)
            self.save()
            var mods = [BubbleDefaults.text(reply.text, size: 7)]
            if let inner = reply.inner { mods.insert(BubbleDefaults.text("（\(inner)）", size: 5, bold: false, color: "#8a93b8"), at: 0) }
            m.showAlert(kind: "remark", modules: mods, closeSec: max(6, Double(reply.text.count) * 0.25),
                        role: .wave, sound: !m.settings.autoPlay.silent)
        }
        return true
    }

    private func ask(_ user: String, history: [ChatMessage], length: ChatLength, model m: AppModel,
                                done: @escaping (ChatMessage) -> Void) {
        guard let key = m.deepseekKey, !key.isEmpty else { error = "先在设置 → DeepSeek 里填好密钥"; return }
        let cfg = m.settings.chat
        let msgs = ChatPersona.messages(system: ChatPersona.system(context(m), length, inner: cfg.innerVoice), history: history,
                                        keep: cfg.historyMessages, user: user)
        busy = true; error = nil
        m.playRole(.think, for: 60)
        Task {
            do {
                let r = try await ChatClient.complete(key: key, model: cfg.model, messages: msgs, thinking: cfg.innerVoice,
                                                      maxTokens: length == .bubble ? 120 : 300)
                let text = ChatPersona.clean(r.text, limit: length.limit)
                let inner = cfg.innerVoice ? ChatPersona.innerVoice(r.reasoning) : nil
                await MainActor.run {
                    self.busy = false
                    if text.isEmpty { self.error = "她张了张嘴，什么也没说"; m.playRole(m.idleAnim, for: 0.01); return }
                    done(ChatMessage(role: "assistant", text: text, inner: inner))
                }
            } catch {
                await MainActor.run {
                    self.busy = false
                    self.error = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
                    m.playRole(.sulk, for: 2)
                }
            }
        }
    }

    /// Development aid (--chat-test): run each prompt through the API with the live context, print, and quit.
    func devTest(_ prompts: [String], model m: AppModel) {
        guard let key = m.deepseekKey else { print("no DeepSeek key in the Keychain"); exit(1) }
        let cfg = m.settings.chat, ctx = context(m)
        print("model: \(cfg.model)  thinking: \(cfg.innerVoice)\ncontext: \(ctx)\n")
        Task {
            var history: [ChatMessage] = []
            for p in prompts.isEmpty ? [ChatPersona.remarkPrompt] : prompts {
                let length: ChatLength = p == "-" ? .bubble : .panel
                let user = p == "-" ? ChatPersona.remarkPrompt : p
                let msgs = ChatPersona.messages(system: ChatPersona.system(ctx, length, inner: cfg.innerVoice), history: history, keep: cfg.historyMessages, user: user)
                let t0 = Date()
                do {
                    let r = try await ChatClient.complete(key: key, model: cfg.model, messages: msgs, thinking: cfg.innerVoice,
                                                          maxTokens: length == .bubble ? 120 : 300)
                    let text = ChatPersona.clean(r.text, limit: length.limit)
                    print("老大: \(user)\n鲸鱼娘: \(text)  [\(text.count) 字, \(String(format: "%.1f", Date().timeIntervalSince(t0)))s]")
                    print("心声: \(ChatPersona.innerVoice(r.reasoning) ?? "—")")
                    if let raw = r.reasoning { print("reasoning tail: …\(raw.suffix(160).replacingOccurrences(of: "\n", with: " "))") }
                    print("")
                    if user != ChatPersona.remarkPrompt { history.append(ChatMessage(role: "user", text: user)) }
                    history.append(ChatMessage(role: "assistant", text: text))
                } catch { print("error: \((error as? LocalizedError)?.errorDescription ?? "\(error)")") }
            }
            exit(0)
        }
    }
}
