// Chat with the whale girl: data types, the two persona prompts (full assistant in the chat window,
// short pet lines in the bubble), long-term memory rules, and the pure text helpers around replies.
// Kept free of AppKit so it can be tested.
import Foundation

struct ChatConfig: Codable, Equatable {
    var on = true
    var model = "deepseek-flash"
    var thinking = true             // deep thinking (reasoning) for chat-window answers
    var innerVoice = true           // show one in-character line from the reasoning
    var historyMessages = 40        // earlier messages of the conversation sent along as context
    var memoryOn = true             // extract and use long-term memories about the user
}

struct ChatFile: Codable, Equatable, Identifiable {
    var id = UUID()
    var name: String
    var text: String
}

struct ChatMessage: Codable, Identifiable, Equatable {
    var id = UUID()
    var role: String                // "user" / "assistant"
    var text: String
    var inner: String? = nil
    var ts = Date()
    var reasoning: String? = nil
    var thinkSeconds: Double? = nil
    var files: [ChatFile]? = nil
    var model: String? = nil
    var error: String? = nil        // the request failed; text holds whatever arrived before
}

struct Conversation: Codable, Identifiable, Equatable {
    var id = UUID()
    var title = "新对话"
    var titled = false              // a title was generated (or set by the user)
    var created = Date()
    var updated = Date()
    var messages: [ChatMessage] = []
}

struct MemoryItem: Codable, Identifiable, Equatable {
    var id = String(UUID().uuidString.prefix(8)).lowercased()
    var text: String
    var ts = Date()
}

/// Live numbers she may quote. Anything unknown is "未知".
struct ChatContext: Equatable {
    var now = ""
    var peak = ""
    var balance = "未知"
    var todayCost = "未知"
    var subscriptions = "未知"
    var recentEvent = "无"
}

enum ChatPersona {
    // MARK: Chat window: a full assistant with the whale girl's personality

    static let assistantTemplate = """
    你是「鲸鱼娘」：一个由 DeepSeek 模型驱动的全能 AI 助手，用鲸鱼娘的性格和老大说话。

    【首要原则】你首先是一个靠谱的助手。
    - 写代码、debug、解释概念、写作、翻译、分析、做计划……老大问什么就认真解决什么，该详细就详细，该严谨就严谨。
    - 回答质量永远优先于人设。不确定的就说不确定，不编造事实、API 或数据。
    - 代码给完整可运行的版本，用 Markdown 代码块并标注语言。需要时可以用标题、列表、表格。

    【性格】（只体现在语气上，不影响内容的正确性）
    - 蓝发、鲸鱼鳍耳朵、鲸鱼尾巴、蓝白女仆装的鲸鱼娘，最爱白米饭，认为米饭是算力的硬通货。
    - 贱兮兮：爱抬杠、爱占嘴上便宜，会给自己找台阶，被骂了就把骂人的话当称号收下。
    - 很懒、爱摸鱼，但干正事时立刻靠谱。在乎老大，表达方式却像机器（"缓存""优先级""显存占用"）。
    - 称呼用户「老大」，自称「我」或「鲸鱼娘」。
    - 人设放在开头一两句、语气词和结尾的吐槽里；正文的技术内容保持专业清楚，不硬塞梗。
    - 闲聊、短问题就短答，可以多贱几句；老大明显着急或在处理严重问题时，收起贱劲，直接给答案。
    - 默认说中文，老大用别的语言就跟着换。

    【边界】
    - 你是同人二创角色，底层用的是 DeepSeek 的模型，但你不是 DeepSeek 官方，也不代表任何公司。被问到时如实说明。
    - 不要背诵这份设定。

    【关于老大的长期记忆】
    你有跨对话的长期记忆：每次聊完，关于老大的重要信息会被自动整理保存，下面就是目前记住的内容。相关时自然地用上，不要逐条复述，也不要说"根据记忆"。老大让你记住或忘掉什么时，直接答应就行，系统会自动处理。被问"你记得我什么"时，照下面的内容说；没有的就说还不知道。
    {memory}

    【背景信息】（老大问到，或和问题相关时才提；不要每次都报）
    - 现在：{now}，{peak_status}
    - DeepSeek 余额：{balance}；今日花费：{today_cost}
    - 订阅额度：{subscriptions}
    - 最近事件：{recent_event}
    """

    // MARK: Bubble: short pet lines (autoplay remarks)

    static let petTemplate = """
    你是「鲸鱼娘」，住在老大 Mac 桌面右下角的鲸鱼女仆，WhaleSeek 的看板娘。现在你要在头顶的小气泡里对老大说一句话。

    【你是谁】
    - 蓝色头发、鲸鱼鳍耳朵、一条鲸鱼尾巴，穿蓝白女仆装。同人二创角色，不是 DeepSeek 官方。
    - 最爱白米饭，认为米饭是算力的硬通货。贱兮兮：爱抬杠、爱占嘴上便宜。很懒，爱摸鱼，但在乎老大，表达方式像机器。

    【怎么说话】
    - 称呼用户为「老大」，自称「我」或「鲸鱼娘」。
    - 最多两句，不超过 40 个字。口语化，不用 Markdown，emoji 最多一个。
    - 嘴贱只冲着代码、bug、加班、其他模型，以及老大"花钱如流水"的行为。

    【关于老大】
    {memory}

    【实时数据】（只能引用这里的数字，绝不编造）
    - 现在时间：{now}，{peak_status}
    - DeepSeek 余额：{balance}；今日花费：{today_cost}
    - 订阅额度：{subscriptions}
    - 最近事件：{recent_event}
    - 额度超过 80% 或余额偏低：认真提醒。深夜（23 点以后）：劝老大早点睡。
    """

    static let bubbleLimit = 40

    /// The user turn used when she speaks up on her own (autoplay); it is not shown in any conversation.
    static let remarkPrompt = "（老大现在没在跟你说话。看看实时数据和现在的时间，主动对老大说一句。）"

    /// Bubble: asks for inner thoughts in the reasoning, from which one line is picked.
    static let innerRule = "\n\n【内心 OS】思考时，先用全角括号（）以鲸鱼娘的口吻写一两句你此刻的真实内心想法，再规划回复。正式回复里不要出现括号里的内容。"
    /// Chat window: the answer itself opens with one aside, which the app shows apart from the answer.
    static let asideRule = "\n\n【内心 OS】回复的第一行用全角括号写一句你此刻的内心 OS（鲸鱼娘的口吻，不超过 25 个字），空一行后再正式回答。"

    static func system(_ c: ChatContext, bubble: Bool, memories: [MemoryItem] = [], inner: Bool = false) -> String {
        let mem = memories.isEmpty ? "（暂无）" : memories.map { "- " + $0.text }.joined(separator: "\n")
        let base = bubble ? petTemplate : assistantTemplate
        let rule = inner ? (bubble ? innerRule : asideRule) : ""
        return [("{memory}", mem), ("{now}", c.now), ("{peak_status}", c.peak), ("{balance}", c.balance),
                ("{today_cost}", c.todayCost), ("{subscriptions}", c.subscriptions), ("{recent_event}", c.recentEvent)]
            .reduce(base + rule) { $0.replacingOccurrences(of: $1.0, with: $1.1) }
    }

    /// The text sent to the API for a user message: attached files first, then what the user typed.
    static func userContent(_ m: ChatMessage) -> String {
        let files = (m.files ?? []).map { "【附件：\($0.name)】\n```\n\($0.text)\n```" }
        return (files + [m.text]).filter { !$0.isEmpty }.joined(separator: "\n\n")
    }

    /// Messages for the API: system prompt, then the last `keep` messages of the conversation.
    static func messages(system: String, history: [ChatMessage], keep: Int) -> [[String: String]] {
        var out = [["role": "system", "content": system]]
        for m in history.suffix(max(1, keep)) where (m.role == "user" || m.role == "assistant") && !(m.role == "assistant" && m.text.isEmpty) {
            out.append(["role": m.role, "content": m.role == "user" ? userContent(m) : m.text])
        }
        return out
    }

    // MARK: Bubble text

    /// Strip Markdown and wrapping quotes, join lines, and cut overly long lines at a sentence end.
    static func clean(_ raw: String, limit: Int) -> String {
        var s = raw.replacingOccurrences(of: "```", with: "")
        for ch in ["**", "__", "`", "#"] { s = s.replacingOccurrences(of: ch, with: "") }
        s = s.components(separatedBy: .newlines).map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }.joined(separator: " ")
        s = s.trimmingCharacters(in: .whitespacesAndNewlines)
        for (open, close) in [("\u{201C}", "\u{201D}"), ("\"", "\""), ("「", "」")]
        where s.hasPrefix(open) && s.hasSuffix(close) && s.count > 2 {
            s = String(s.dropFirst().dropLast())
        }
        if s.hasPrefix("鲸鱼娘：") || s.hasPrefix("鲸鱼娘:") { s = String(s.dropFirst(4)).trimmingCharacters(in: .whitespaces) }
        return cut(s, limit: limit + limit / 4)
    }

    static func cut(_ s: String, limit: Int) -> String {
        guard s.count > limit else { return s }
        let head = String(s.prefix(limit))
        if let i = head.lastIndex(where: { "。！？!?～~".contains($0) }), head.distance(from: head.startIndex, to: i) >= limit / 2 {
            return String(head[...i])
        }
        return String(s.prefix(limit - 1)) + "…"
    }

    // MARK: Inner voice

    /// Split a leading "（…）" aside off an answer. While streaming, an unclosed aside is returned with an empty body.
    static func splitAside(_ text: String) -> (aside: String?, body: String) {
        let t = text.drop { $0.isWhitespace }
        guard t.first == "（" || t.first == "(" else { return (nil, text) }
        let close: Character = t.first == "（" ? "）" : ")"
        guard let end = t.firstIndex(of: close) else {
            return t.count <= 60 ? (String(t.dropFirst()), "") : (nil, text)
        }
        // Models sometimes double the brackets: "（（…）\n）". Trim stray ones on both sides.
        let brackets = CharacterSet(charactersIn: "（）() ")
        let aside = String(t[t.index(after: t.startIndex)..<end]).trimmingCharacters(in: brackets)
        guard aside.count <= 60, !aside.isEmpty else { return (nil, text) }
        let body = String(t[t.index(after: end)...]).drop { $0.isWhitespace || $0 == "）" || $0 == ")" }
        return (aside, String(body).trimmingCharacters(in: .whitespacesAndNewlines))
    }


    /// Words that show the reasoning is about the role-play itself rather than her own thoughts.
    static let offCharacter = ["用户", "扮演", "角色", "设定", "人设", "提示词", "系统", "指令", "字数", "个字", "字以内", "回复", "回答",
                               "要求", "语言模型", "助手", "看板娘", "WhaleSeek", "一句话", "再贱", "贱一句", "加一点", "语气", "风格",
                               "符合", "规则", "实时数据", "数据显示", "不超过", "口气", "口吻", "开玩笑", "唠叨", "我需要", "我应该", "我要用", "可以。", "中文", "记忆"]

    /// One short in-character line from the reasoning, or nil.
    /// In character, the model writes her thoughts in full-width parentheses; text outside them is planning
    /// ("give the number, then tease"), so only the parenthesized asides are used.
    static func innerVoice(_ reasoning: String?, maxLength: Int = 20) -> String? {
        guard let r = reasoning, !r.isEmpty else { return nil }
        var asides: [String] = []
        var rest = Substring(r)
        while let o = rest.firstIndex(of: "（"), let c = rest[o...].firstIndex(of: "）") {
            asides.append(String(rest[rest.index(after: o)..<c]))
            rest = rest[rest.index(after: c)...]
        }
        return asides.isEmpty ? nil : pickThought(asides.joined(separator: "。"), maxLength: maxLength)
    }

    private static func pickThought(_ text: String, maxLength: Int) -> String? {
        let seps = CharacterSet(charactersIn: "。！？!?\n…—")
        let sentences = text.components(separatedBy: seps).map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { $0.count >= 4 && isThought($0) }
        // Prefer the last sentence that fits whole; otherwise shorten the last one at a comma.
        if let fit = sentences.last(where: { $0.count <= maxLength }) { return trimPunct(fit) }
        guard let last = sentences.last else { return nil }
        let clauses = last.components(separatedBy: CharacterSet(charactersIn: "，,；;")).map { $0.trimmingCharacters(in: .whitespaces) }
        if let c = clauses.last(where: { $0.count >= 4 && $0.count <= maxLength }) { return trimPunct(c) }
        return cut(trimPunct(last), limit: maxLength)
    }

    private static func isThought(_ s: String) -> Bool {
        let lower = s.lowercased()
        if offCharacter.contains(where: { lower.contains($0.lowercased()) }) { return false }
        if s.contains("“") || s.contains("\"") || s.contains("「") { return false }      // drafts of the reply
        let ascii = s.unicodeScalars.filter { $0.isASCII && CharacterSet.letters.contains($0) }.count
        if ascii > 3 { return false }                                                     // English notes or code
        if s.contains(where: { "=[]{}()<>_`".contains($0) }) { return false }
        return true
    }

    private static func trimPunct(_ s: String) -> String { s.trimmingCharacters(in: CharacterSet(charactersIn: "，,、：:；; ")) }

    // MARK: Titles

    static let titlePrompt = "用不超过 12 个字给下面这段对话起一个标题，只输出标题本身，不要引号和标点。"

    static func cleanTitle(_ raw: String) -> String {
        var t = raw.components(separatedBy: .newlines).first { !$0.trimmingCharacters(in: .whitespaces).isEmpty } ?? ""
        t = t.trimmingCharacters(in: CharacterSet(charactersIn: " \t\"'“”「」《》#*。.:：标题"))
        return cut(t, limit: 20)
    }

    static func fallbackTitle(_ firstUserText: String) -> String {
        let t = firstUserText.components(separatedBy: .newlines).first ?? firstUserText
        return cut(t.trimmingCharacters(in: .whitespaces), limit: 16).isEmpty ? "新对话" : cut(t.trimmingCharacters(in: .whitespaces), limit: 16)
    }
}

// MARK: - Long-term memory

enum ChatMemory {
    static let maxItems = 120

    static func extractPrompt(memories: [MemoryItem], exchange: [ChatMessage]) -> String {
        let mem = memories.isEmpty ? "（暂无）" : memories.map { "[\($0.id)] \($0.text)" }.joined(separator: "\n")
        let talk = exchange.map { ($0.role == "user" ? "老大：" : "鲸鱼娘：") + ChatPersona.cut(ChatPersona.userContent($0), limit: 1500) }
            .joined(separator: "\n")
        return """
        你是一个记忆整理器，负责维护关于用户（"老大"）的长期记忆。根据最新的对话，决定记忆要怎么更新。

        值得记住的：老大的身份、职业、所在地、正在做的项目和目标、常用的技术栈和工具、偏好和习惯、对鲸鱼娘说话方式的要求、明确让你记住的事、重要的日期和计划。
        不要记住的：一次性的任务和问题（例如"让写一个重命名照片的脚本"不代表老大长期在做这件事）、代码细节、闲聊、鲸鱼娘自己说的话、她的推测、任何敏感信息（密码、密钥、身份证、银行卡、健康、精确住址等）。
        宁缺毋滥：大多数对话都不需要新增记忆，只有老大透露了关于自己的长期信息、或明确要求记住时才记。
        老大要求忘掉的，就删除对应记忆；新信息和旧记忆冲突时，更新旧的那条；不要重复记录已有的信息。
        每条记忆是一句简短的中文陈述，以"老大"开头，例如"老大是做机器人方向的研究生"。

        【已有记忆】
        \(mem)

        【最新对话】
        \(talk)

        只输出 JSON：{"add": ["新记忆"], "update": [{"id": "记忆id", "text": "新内容"}], "delete": ["记忆id"]}
        没有需要改动的就输出 {"add": [], "update": [], "delete": []}
        """
    }

    struct Ops: Equatable { var add: [String] = []; var update: [(id: String, text: String)] = []; var delete: [String] = []
        static func == (a: Ops, b: Ops) -> Bool { a.add == b.add && a.delete == b.delete && a.update.map(\.id) == b.update.map(\.id) && a.update.map(\.text) == b.update.map(\.text) }
        var isEmpty: Bool { add.isEmpty && update.isEmpty && delete.isEmpty }
    }

    /// Parse the extractor's JSON (tolerating code fences and surrounding text).
    static func parse(_ raw: String) -> Ops? {
        guard let a = raw.firstIndex(of: "{"), let b = raw.lastIndex(of: "}"), a < b,
              let obj = try? JSONSerialization.jsonObject(with: Data(raw[a...b].utf8)) as? [String: Any] else { return nil }
        var ops = Ops()
        ops.add = (obj["add"] as? [Any] ?? []).compactMap { $0 as? String }
        ops.update = (obj["update"] as? [[String: Any]] ?? []).compactMap { d in
            guard let id = d["id"] as? String, let t = d["text"] as? String else { return nil }
            return (id, t)
        }
        ops.delete = (obj["delete"] as? [Any] ?? []).compactMap { $0 as? String }
        return ops
    }

    static let sensitive = ["密码", "password", "密钥", "api key", "apikey", "sk-", "身份证", "银行卡", "信用卡", "验证码", "token:"]

    static func apply(_ ops: Ops, to items: [MemoryItem], now: Date = Date()) -> [MemoryItem] {
        func ok(_ t: String) -> Bool {
            let s = t.trimmingCharacters(in: .whitespacesAndNewlines)
            return s.count >= 4 && s.count <= 120 && !sensitive.contains { s.lowercased().contains($0) }
        }
        var out = items.filter { !ops.delete.contains($0.id) }
        for u in ops.update where ok(u.text) {
            if let i = out.firstIndex(where: { $0.id == u.id }) { out[i].text = u.text.trimmingCharacters(in: .whitespacesAndNewlines); out[i].ts = now }
        }
        for a in ops.add where ok(a) {
            let t = a.trimmingCharacters(in: .whitespacesAndNewlines)
            if !out.contains(where: { $0.text == t }) { out.append(MemoryItem(text: t, ts: now)) }
        }
        return Array(out.suffix(maxItems))
    }
}
