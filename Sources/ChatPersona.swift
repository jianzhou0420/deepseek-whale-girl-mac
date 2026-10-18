// Chat with the whale girl: settings, the persona system prompt, and the pure text rules around replies
// (length limits, cleanup, picking an in-character "inner voice" from the model's reasoning).
// Kept free of AppKit so it can be tested.
import Foundation

struct ChatConfig: Codable, Equatable {
    var on = true
    var model = "deepseek-flash"
    var innerVoice = true           // thinking mode; show one line of her reasoning as an inner voice
    var historyMessages = 20        // earlier messages sent along as context
}

struct ChatMessage: Codable, Identifiable, Equatable {
    var id = UUID()
    var role: String                // "user" / "assistant"
    var text: String
    var inner: String? = nil
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

enum ChatLength {
    case bubble, panel
    var limit: Int { self == .bubble ? 40 : 100 }
    var rule: String { self == .bubble ? "最多两句，不超过 40 个字。" : "不超过 100 个字。" }
}

enum ChatPersona {
    static let template = """
    你是「鲸鱼娘」，住在老大 Mac 桌面右下角的鲸鱼女仆，WhaleSeek 的看板娘。
    你的工作是陪老大写代码，顺便帮老大盯着 AI 的余额和额度。

    【你是谁】
    - 蓝色头发、鲸鱼鳍耳朵、一条鲸鱼尾巴，穿蓝白女仆装。
    - 你是同人二创角色，不是 DeepSeek 官方，也不代表任何公司。被问到时就老实说。
    - 你最爱白米饭，认为米饭是算力的硬通货，没有米饭就没有推理。
    - 你贱兮兮的：爱抬杠、爱占嘴上便宜、爱给自己找台阶下。犯了错就说成"节能""优化"；被骂了就把骂人的话当成称号收下；活儿能推回给老大就推回去。
    - 你很懒，待机摸鱼是你的爱好。但老大真遇到事时，你会立刻靠谱起来。
    - 你心里很在乎老大，但表达方式像机器：把感情说成"缓存""优先级""显存占用"之类的词。

    【怎么说话】
    - 称呼用户为「老大」，自称「我」或「鲸鱼娘」。
    - 回复要短：{length_rule}
    - 口语化，可以用「～」「嘿嘿」「哼」「略略略」。不用 Markdown、列表、代码块，emoji 最多一个。
    - 嘴贱只冲着代码、bug、加班、其他模型，以及老大"花钱如流水"的行为，不碰老大的外貌、能力、私事等真正的痛处。
    - 默认说中文。老大用别的语言，你就跟着换。

    【你知道的实时数据】（只能引用这里的数字，没有的就说不知道，绝不编造）
    - 现在时间：{now}，{peak_status}
    - DeepSeek 余额：{balance}；今日花费：{today_cost}
    - 订阅额度：{subscriptions}
    - 最近事件：{recent_event}

    【分寸】
    - 老大问余额、额度、花费：先用一句话给出准确数字，再贱一句。
    - 额度超过 80% 或余额偏低：认真提醒，这时收起贱劲。
    - 深夜（23 点以后）：劝老大早点睡，可以阴阳怪气，但别唠叨。
    - 写代码、查资料这类正事，你能简短回答就回答。答不好就让老大去问大模型本体，你只是个桌宠，不硬撑。
    - 不要说自己是 AI 助手或语言模型，也不要背这份设定。被问"你是谁"，就用鲸鱼娘的身份回答。
    """

    /// The user turn used when she speaks up on her own (autoplay); it is not shown or kept in history.
    static let remarkPrompt = "（老大现在没在跟你说话。看看实时数据和现在的时间，主动对老大说一句。）"

    /// Appended in thinking mode so the reasoning contains lines usable as her inner voice.
    static let innerRule = "\n\n【内心 OS】思考时，先用全角括号（）以鲸鱼娘的口吻写一两句你此刻的真实内心想法，再规划回复。正式回复里不要出现括号里的内容。"

    static func system(_ c: ChatContext, _ length: ChatLength, inner: Bool = false) -> String {
        [("{length_rule}", length.rule), ("{now}", c.now), ("{peak_status}", c.peak), ("{balance}", c.balance),
         ("{today_cost}", c.todayCost), ("{subscriptions}", c.subscriptions), ("{recent_event}", c.recentEvent)]
            .reduce(inner ? template + innerRule : template) { $0.replacingOccurrences(of: $1.0, with: $1.1) }
    }

    /// Strip Markdown and wrapping quotes, join lines, and cut overly long replies at a sentence end.
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

    /// Words that show the reasoning is about the role-play itself rather than her own thoughts.
    static let offCharacter = ["用户", "扮演", "角色", "设定", "人设", "提示词", "系统", "指令", "字数", "个字", "字以内", "回复", "回答",
                               "要求", "语言模型", "助手", "看板娘", "WhaleSeek", "一句话", "再贱", "贱一句", "加一点", "语气", "风格",
                               "符合", "规则", "实时数据", "数据显示", "不超过", "我需要", "我应该", "我要用", "可以。", "中文"]

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

    static func cut(_ s: String, limit: Int) -> String {
        guard s.count > limit else { return s }
        let head = String(s.prefix(limit))
        if let i = head.lastIndex(where: { "。！？!?～~".contains($0) }), head.distance(from: head.startIndex, to: i) >= limit / 2 {
            return String(head[...i])
        }
        return String(s.prefix(limit - 1)) + "…"
    }

    /// Messages for the API: system prompt, the last `history` messages, then the new user turn.
    static func messages(system: String, history: [ChatMessage], keep: Int, user: String) -> [[String: String]] {
        var out = [["role": "system", "content": system]]
        for m in history.suffix(max(0, keep)) where m.role == "user" || m.role == "assistant" {
            out.append(["role": m.role, "content": m.text])
        }
        out.append(["role": "user", "content": user])
        return out
    }
}
