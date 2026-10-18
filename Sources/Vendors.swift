// Vendor templates and balance / quota fetching.
// Templates ported from lib/index.js (API_TEMPLATES) of MeteorNOX/DeepSeek-Balance-Whale-Widget (MIT).
import Foundation

struct QuotaWindowSpec {
    var key: String
    var label: String
    var percent: String          // JSON path to "used %" (or "remaining %" when percentIsRemaining)
    var resetAt: String
    var pickList: String? = nil  // pick an element from this array by type/unit first
    var pickTypes: [String] = []
    var pickUnit: Int? = nil
    var percentIsRemaining = false
}

struct BalanceSpec {
    var url: String
    var auth: String
    var remaining: String = ""
    var total: String = ""
    var used: String = ""
    var scale: Double = 1
    var usageURL: String = ""
    var usageUsed: String = ""
    var usageScale: Double = 1
}

struct QuotaSpec {
    var url: String
    var auth: String
    var level: String = ""
    var windows: [QuotaWindowSpec] = []
    // single-window "remaining / total" style
    var remain: String = ""
    var total: String = ""
    var resetAt: String = ""
}

enum VendorKind: String, Codable { case balance, quota, codex, costs }

struct VendorTemplate: Identifiable {
    var id: String
    var name: String
    var currency: String
    var keyRef: String
    var kind: VendorKind = .balance
    var builtin = false
    var balance: BalanceSpec? = nil
    var quota: QuotaSpec? = nil
    var probeURL: String = ""
    var noBalanceAPI = false
    var needsBaseURL = false
    var note: String = ""

    var hasBalanceAPI: Bool { !(balance?.url ?? "").isEmpty }
}

enum Vendors {
    static let noAPI = "官方没有「用 API key 查余额」的公开接口 → 余额显示「—」，可用「测试连通性」验证 key。"
    private static func probeOnly(_ id: String, _ name: String, _ cur: String, _ ref: String, _ probe: String,
                                  note: String = noAPI, auth: String = "Bearer {key}", base: Bool = false) -> VendorTemplate {
        VendorTemplate(id: id, name: name, currency: cur, keyRef: ref,
                       balance: BalanceSpec(url: "", auth: auth), probeURL: probe, noBalanceAPI: true,
                       needsBaseURL: base, note: note)
    }
    private static func zhipu(_ id: String, _ name: String, _ cur: String, _ ref: String, _ host: String) -> VendorTemplate {
        let url = "https://\(host)/api/monitor/usage/quota/limit"
        return VendorTemplate(id: id, name: name, currency: cur, keyRef: ref, kind: .quota,
            quota: QuotaSpec(url: url, auth: "{key}", level: "data.level", windows: [
                QuotaWindowSpec(key: "rolling", label: "5h", percent: "percentage", resetAt: "nextResetTime",
                                pickList: "data.limits", pickTypes: ["TOKENS_LIMIT", "CREDIT_LIMIT"], pickUnit: 3),
                QuotaWindowSpec(key: "weekly", label: "周", percent: "percentage", resetAt: "nextResetTime",
                                pickList: "data.limits", pickTypes: ["TOKENS_LIMIT", "CREDIT_LIMIT"], pickUnit: 6),
            ]), probeURL: url, note: "只对 Coding Plan 订阅账号有效。")
    }
    private static func minimax(_ id: String, _ name: String, _ cur: String, _ ref: String, _ host: String) -> VendorTemplate {
        let url = "https://\(host)/v1/api/openplatform/coding_plan/remains"
        return VendorTemplate(id: id, name: name, currency: cur, keyRef: ref, kind: .quota,
            quota: QuotaSpec(url: url, auth: "Bearer {key}", windows: [
                QuotaWindowSpec(key: "rolling", label: "5h", percent: "model_remains[0].current_interval_remaining_percent",
                                resetAt: "model_remains[0].end_time", percentIsRemaining: true),
                QuotaWindowSpec(key: "weekly", label: "周", percent: "model_remains[0].current_weekly_remaining_percent",
                                resetAt: "", percentIsRemaining: true),
            ]), probeURL: url, note: "只对 Coding Plan 订阅账号有效。")
    }

    static let all: [VendorTemplate] = [
        VendorTemplate(id: "deepseek", name: "DeepSeek", currency: "CNY", keyRef: "DEEPSEEK_API_KEY", builtin: true,
                       balance: BalanceSpec(url: "https://api.deepseek.com/user/balance", auth: "Bearer {key}",
                                            remaining: "balance_infos[0].total_balance")),
        VendorTemplate(id: "openrouter", name: "OpenRouter", currency: "USD", keyRef: "OPENROUTER_API_KEY",
                       balance: BalanceSpec(url: "https://openrouter.ai/api/v1/credits", auth: "Bearer {key}",
                                            total: "data.total_credits", used: "data.total_usage")),
        VendorTemplate(id: "moonshot", name: "Kimi / Moonshot（CN）", currency: "CNY", keyRef: "MOONSHOT_API_KEY",
                       balance: BalanceSpec(url: "https://api.moonshot.cn/v1/users/me/balance", auth: "Bearer {key}",
                                            remaining: "data.available_balance"),
                       probeURL: "https://api.moonshot.cn/v1/models"),
        VendorTemplate(id: "moonshot_intl", name: "Kimi / Moonshot（国际）", currency: "USD", keyRef: "MOONSHOT_INTL_API_KEY",
                       balance: BalanceSpec(url: "https://api.moonshot.ai/v1/users/me/balance", auth: "Bearer {key}",
                                            remaining: "data.available_balance"),
                       probeURL: "https://api.moonshot.ai/v1/models"),
        VendorTemplate(id: "stepfun", name: "阶跃星辰 StepFun", currency: "CNY", keyRef: "STEPFUN_API_KEY",
                       balance: BalanceSpec(url: "https://api.stepfun.com/v1/accounts", auth: "Bearer {key}", remaining: "balance")),
        VendorTemplate(id: "novita", name: "Novita AI", currency: "USD", keyRef: "NOVITA_API_KEY",
                       balance: BalanceSpec(url: "https://api.novita.ai/v3/user/balance", auth: "Bearer {key}",
                                            remaining: "availableBalance", scale: 0.0001)),
        zhipu("zhipu_glm_coding", "智谱 GLM Coding Plan（订阅）", "CNY", "ZHIPU_API_KEY", "open.bigmodel.cn"),
        zhipu("zhipu_glm_coding_intl", "智谱 GLM Coding Plan（国际 z.ai）", "USD", "ZHIPU_INTL_API_KEY", "api.z.ai"),
        VendorTemplate(id: "kimi_coding", name: "Kimi Coding（订阅）", currency: "CNY", keyRef: "KIMI_CODING_KEY", kind: .quota,
                       quota: QuotaSpec(url: "https://api.kimi.com/coding/v1/usages", auth: "Bearer {key}",
                                        remain: "usage.remaining", total: "usage.limit", resetAt: "usage.resetTime"),
                       probeURL: "https://api.kimi.com/coding/v1/usages"),
        minimax("minimax_coding", "MiniMax Coding（订阅）", "CNY", "MINIMAX_API_KEY", "api.minimaxi.com"),
        minimax("minimax_coding_intl", "MiniMax Coding（国际）", "USD", "MINIMAX_INTL_API_KEY", "api.minimax.io"),
        VendorTemplate(id: "opencode_go", name: "OpenCode Go（订阅）", currency: "USD", keyRef: "OPENCODE_GO_API_KEY", kind: .quota,
                       quota: QuotaSpec(url: "https://opencode.ai/zen/go/v1/usage", auth: "Bearer {key}", windows: [
                           QuotaWindowSpec(key: "rolling", label: "5h", percent: "usage.rolling.percent", resetAt: "usage.rolling.resetsAt"),
                           QuotaWindowSpec(key: "weekly", label: "周", percent: "usage.weekly.percent", resetAt: "usage.weekly.resetsAt"),
                           QuotaWindowSpec(key: "monthly", label: "月", percent: "usage.monthly.percent", resetAt: "usage.monthly.resetsAt"),
                       ]), probeURL: "https://opencode.ai/zen/go/v1/usage"),
        VendorTemplate(id: "openai_compat", name: "OpenAI 兼容中转站", currency: "USD", keyRef: "CUSTOM_API_KEY",
                       balance: BalanceSpec(url: "{base}/v1/dashboard/billing/subscription", auth: "Bearer {key}",
                                            total: "hard_limit_usd",
                                            usageURL: "{base}/v1/dashboard/billing/usage", usageUsed: "total_usage", usageScale: 0.01),
                       needsBaseURL: true, note: "OneAPI / New API 一类网关。需要填 Base URL，并勾选「允许把密钥发送到自定义地址」。"),
        VendorTemplate(id: "custom", name: "自定义 HTTP", currency: "CNY", keyRef: "CUSTOM_API_KEY",
                       balance: BalanceSpec(url: "", auth: "Bearer {key}"),
                       note: "自己填接口地址与 JSON 字段路径（支持 a.b[0].c）。需要勾选「允许把密钥发送到自定义地址」。"),
        VendorTemplate(id: "openai_costs", name: "OpenAI API 费用（Admin Key）", currency: "USD", keyRef: "OPENAI_ADMIN_KEY", kind: .costs,
                       probeURL: "https://api.openai.com/v1/organization/costs",
                       note: "需要组织的 Admin Key（sk-admin-…，在 platform.openai.com 的 Admin keys 页面创建），普通 API Key 查不到费用。显示本月和今天的 API 费用（UTC 计日）。"),
        VendorTemplate(id: "anthropic_costs", name: "Claude API 费用（Admin Key）", currency: "USD", keyRef: "ANTHROPIC_ADMIN_KEY", kind: .costs,
                       probeURL: "https://api.anthropic.com/v1/organizations/cost_report",
                       note: "需要组织的 Admin Key（sk-ant-admin01-…，在 Claude Console 创建）。个人账号没有 Admin API。显示本月和今天的 API 费用（UTC 计日）。Claude 订阅（Pro / Max）的额度请看「订阅」页。"),
        VendorTemplate(id: "codex", name: "Codex（本地会话）", currency: "CNY", keyRef: "", kind: .codex,
                       note: "读取本机 ~/.codex/sessions 里的会话日志统计 token，不联网、不需要密钥。"),
        probeOnly("siliconflow_cn", "硅基流动（CN）", "CNY", "SILICONFLOW_API_KEY", "https://api.siliconflow.cn/v1/models",
                  note: "官方已下线 /user/info 余额接口（2026-08-14 起）→ 余额显示「—」。"),
        probeOnly("siliconflow_en", "硅基流动（EN）", "USD", "SILICONFLOW_API_KEY", "https://api.siliconflow.com/v1/models",
                  note: "官方已下线余额接口 → 余额显示「—」。"),
        probeOnly("volcengine_ark", "火山方舟 Ark", "CNY", "ARK_API_KEY", "https://ark.cn-beijing.volces.com/api/v3/models",
                  note: "余额需火山引擎 AK/SK 签名接口 → 余额显示「—」。"),
        probeOnly("openai", "OpenAI", "USD", "OPENAI_API_KEY", "https://api.openai.com/v1/models"),
        probeOnly("anthropic", "Anthropic Claude", "USD", "ANTHROPIC_API_KEY", "https://api.anthropic.com/v1/models",
                  auth: "x-api-key:{key};anthropic-version:2023-06-01"),
        probeOnly("gemini", "Google Gemini", "USD", "GEMINI_API_KEY",
                  "https://generativelanguage.googleapis.com/v1beta/models?key={key}", auth: ""),
        probeOnly("xai", "xAI Grok", "USD", "XAI_API_KEY", "https://api.x.ai/v1/models"),
        probeOnly("groq", "Groq", "USD", "GROQ_API_KEY", "https://api.groq.com/openai/v1/models"),
        probeOnly("mistral", "Mistral AI", "USD", "MISTRAL_API_KEY", "https://api.mistral.ai/v1/models"),
        probeOnly("together", "Together AI", "USD", "TOGETHER_API_KEY", "https://api.together.xyz/v1/models"),
        probeOnly("fireworks", "Fireworks AI", "USD", "FIREWORKS_API_KEY", "https://api.fireworks.ai/inference/v1/models"),
        probeOnly("deepinfra", "DeepInfra", "USD", "DEEPINFRA_API_KEY", "https://api.deepinfra.com/v1/openai/models"),
        probeOnly("cerebras", "Cerebras", "USD", "CEREBRAS_API_KEY", "https://api.cerebras.ai/v1/models"),
        probeOnly("dashscope", "阿里云百炼（通义千问）", "CNY", "DASHSCOPE_API_KEY",
                  "https://dashscope.aliyuncs.com/compatible-mode/v1/models", note: "余额需阿里云 AK/SK 接口 → 余额显示「—」。"),
        probeOnly("qianfan", "百度千帆（文心）", "CNY", "QIANFAN_API_KEY", "https://qianfan.baidubce.com/v2/models",
                  note: "余额需百度云 AK/SK → 余额显示「—」。"),
        probeOnly("hunyuan", "腾讯混元", "CNY", "HUNYUAN_API_KEY", "https://api.hunyuan.cloud.tencent.com/v1/models",
                  note: "余额需腾讯云 SecretId/Key → 余额显示「—」。"),
        probeOnly("spark", "讯飞星火", "CNY", "SPARK_API_KEY", "https://spark-api-open.xf-yun.com/v1/models"),
        probeOnly("modelscope", "魔搭 ModelScope", "CNY", "MODELSCOPE_API_KEY", "https://api-inference.modelscope.cn/v1/models"),
        probeOnly("ollama", "本地模型（Ollama / LM Studio）", "CNY", "", "{base}/v1/models",
                  note: "本地推理没有余额概念。填好 Base URL（如 http://127.0.0.1:11434）后可测试连通性。", auth: "", base: true),
    ]

    static func template(_ id: String) -> VendorTemplate? { all.first { $0.id == id } }

    /// Templates sorted for pickers: DeepSeek first, then Latin and pinyin initials mixed A→Z.
    static var sorted: [VendorTemplate] {
        let pinyin: [Character: String] = ["阿": "a", "百": "bai", "本": "ben", "硅": "gui", "火": "huo", "阶": "jie",
                                           "魔": "mo", "腾": "teng", "讯": "xun", "智": "zhi", "自": "zi"]
        func key(_ t: VendorTemplate) -> String {
            if let f = t.name.first, let p = pinyin[f] { return p }
            return t.name.lowercased()
        }
        return all.filter { $0.id != "deepseek" }.sorted { key($0) < key($1) }
    }
}

// MARK: - User-configured models

struct ManualQuota: Codable, Equatable {
    var on = false
    var total: Double = 0
    var used: Double = 0
    var unit = "tokens"        // "tokens" or "元"
    var reset = "none"         // none / daily / monthly
    var source = "manual"      // manual / codex
    var baseline: Double = 0   // codex "none" reset: cumulative tokens at the time the quota was set
}

struct ApiModel: Codable, Identifiable, Equatable {
    var id = UUID().uuidString
    var name: String
    var provider: String
    var keyRef: String
    var currency: String
    var baseURL = ""
    var urlOverride = ""
    var authOverride = ""
    var remainingPath = ""
    var totalPath = ""
    var usedPath = ""
    var scale: Double = 0           // 0 = template default
    var allowCustomEndpoint = false
    var lowBalanceOn = false
    var lowBalance: Double = 0
    var budgetOn = false
    var budget: Double = 0
    var quota = ManualQuota()

    var template: VendorTemplate? { Vendors.template(provider) }

    static func from(_ t: VendorTemplate) -> ApiModel {
        ApiModel(name: t.name, provider: t.id, keyRef: t.keyRef, currency: t.currency)
    }
}

struct QuotaWindow: Codable, Equatable {
    var key: String
    var label: String
    var usedPct: Double?
    var resetAt: Date?
}

struct VendorStatus: Equatable {
    var balance: Double?
    var total: Double?
    var used: Double?
    var bonus: Double?
    var recharge: Double?
    var currency: String
    var windows: [QuotaWindow] = []
    var level: String?
    var error: String?
    var updatedAt: Date?
    var stale = false
    var costToday: Double?
    var costMonth: Double?
}

// MARK: - JSON path ("a.b[0].c")

enum JSONPath {
    static func get(_ root: Any?, _ path: String) -> Any? {
        guard !path.isEmpty else { return nil }
        var cur: Any? = root
        var token = ""
        var tokens: [String] = []
        for ch in path {
            if ch == "." || ch == "[" || ch == "]" {
                if !token.isEmpty { tokens.append(token); token = "" }
            } else { token.append(ch) }
        }
        if !token.isEmpty { tokens.append(token) }
        for t in tokens {
            if let i = Int(t), let arr = cur as? [Any] {
                cur = i < arr.count ? arr[i] : nil
            } else if let dict = cur as? [String: Any] {
                cur = dict[t]
            } else { return nil }
        }
        return cur
    }
    static func number(_ root: Any?, _ path: String) -> Double? { toNumber(get(root, path)) }
    static func toNumber(_ v: Any?) -> Double? {
        if let n = v as? NSNumber { return n.doubleValue }
        if let s = v as? String { return Double(s.trimmingCharacters(in: .whitespaces)) }
        return nil
    }
    static func date(_ v: Any?) -> Date? {
        if let n = toNumber(v) {
            if n > 1e12 { return Date(timeIntervalSince1970: n / 1000) }
            if n > 1e9 { return Date(timeIntervalSince1970: n) }
            return nil
        }
        if let s = v as? String {
            let f = ISO8601DateFormatter()
            f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let d = f.date(from: s) { return d }
            f.formatOptions = [.withInternetDateTime]
            return f.date(from: s)
        }
        return nil
    }
}

// MARK: - HTTP

enum VendorError: LocalizedError {
    case noKey(String), blocked(String), http(Int, String), network(String), parse(String), notConfigured(String)
    var errorDescription: String? {
        switch self {
        case .noKey(let r): return "还没有填写密钥（\(r)）"
        case .blocked(let u): return "「\(u)」不是该厂商的内置接口，已拒绝把密钥发出去。确认是你自己的网关后，勾选「允许把密钥发送到自定义地址」。"
        case .http(let c, let m): return "HTTP \(c)" + (m.isEmpty ? "" : "：\(m)")
        case .network(let m): return "网络错误：\(m)"
        case .parse(let m): return "解析失败：\(m)"
        case .notConfigured(let m): return m
        }
    }
    var isTransient: Bool {
        switch self { case .network: return true; case .http(let c, _): return c >= 500; default: return false }
    }
}

enum VendorClient {
    static let session: URLSession = {
        let c = URLSessionConfiguration.ephemeral
        c.timeoutIntervalForRequest = 20
        return URLSession(configuration: c)
    }()

    /// Build a request; refuses to attach the key to an endpoint the template does not define,
    /// unless the model explicitly allows custom endpoints.
    static func request(url template: String, defaultURL: String, auth: String, key: String,
                        base: String, allowCustom: Bool) throws -> URLRequest {
        let usesCustom = template != defaultURL || template.contains("{base}")
        let needsKey = auth.contains("{key}") || template.contains("{key}")
        if usesCustom && needsKey && !allowCustom {
            throw VendorError.blocked(template.replacingOccurrences(of: "{base}", with: base))
        }
        var s = template.replacingOccurrences(of: "{base}", with: base.trimmingCharacters(in: CharacterSet(charactersIn: "/ ")))
        s = s.replacingOccurrences(of: "{key}", with: key.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? key)
        guard let url = URL(string: s), let scheme = url.scheme, ["http", "https"].contains(scheme), url.user == nil else {
            throw VendorError.notConfigured("接口地址无效：\(s)")
        }
        var req = URLRequest(url: url)
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        let a = auth.trimmingCharacters(in: .whitespaces)
        if !a.isEmpty {
            if a.contains(";") || (a.contains(":") && !a.hasPrefix("Bearer")) {
                for pair in a.split(separator: ";") {
                    let kv = pair.split(separator: ":", maxSplits: 1).map { String($0).trimmingCharacters(in: .whitespaces) }
                    if kv.count == 2 { req.setValue(kv[1].replacingOccurrences(of: "{key}", with: key), forHTTPHeaderField: kv[0]) }
                }
            } else {
                req.setValue(a.replacingOccurrences(of: "{key}", with: key), forHTTPHeaderField: "Authorization")
            }
        }
        return req
    }

    /// GET JSON with one retry on network errors and 5xx.
    static func getJSON(_ req: URLRequest) async throws -> Any {
        var lastError: VendorError = .network("未知错误")
        for attempt in 0..<2 {
            if attempt > 0 { try? await Task.sleep(nanoseconds: 500_000_000) }
            do {
                let (data, resp) = try await session.data(for: req)
                let code = (resp as? HTTPURLResponse)?.statusCode ?? 0
                if code >= 400 {
                    let body = String(data: data.prefix(200), encoding: .utf8) ?? ""
                    let err = VendorError.http(code, body.replacingOccurrences(of: "\n", with: " "))
                    if code >= 500 { lastError = err; continue }
                    throw err
                }
                do { return try JSONSerialization.jsonObject(with: data) }
                catch { throw VendorError.parse("返回的不是 JSON") }
            } catch let e as VendorError {
                throw e
            } catch {
                lastError = .network(error.localizedDescription)
            }
        }
        throw lastError
    }

    // MARK: DeepSeek

    struct DeepSeekBalance { var total: Double; var bonus: Double?; var recharge: Double?; var currency: String }

    /// balance_infos order is not stable: prefer CNY with balance > 0, then any non-zero, then CNY, then the first.
    static func parseDeepSeek(_ json: Any) throws -> DeepSeekBalance {
        guard let infos = JSONPath.get(json, "balance_infos") as? [[String: Any]], !infos.isEmpty else {
            throw VendorError.parse("没有 balance_infos")
        }
        func total(_ i: [String: Any]) -> Double { JSONPath.toNumber(i["total_balance"]) ?? 0 }
        func cur(_ i: [String: Any]) -> String { (i["currency"] as? String ?? "CNY").uppercased() }
        let pick = infos.first { cur($0) == "CNY" && total($0) > 0 }
            ?? infos.first { total($0) != 0 }
            ?? infos.first { cur($0) == "CNY" }
            ?? infos[0]
        return DeepSeekBalance(total: total(pick), bonus: JSONPath.toNumber(pick["granted_balance"]),
                               recharge: JSONPath.toNumber(pick["topped_up_balance"]), currency: cur(pick))
    }

    static func fetchDeepSeek(key: String) async throws -> DeepSeekBalance {
        let t = Vendors.template("deepseek")!.balance!
        let req = try request(url: t.url, defaultURL: t.url, auth: t.auth, key: key, base: "", allowCustom: false)
        return try parseDeepSeek(try await getJSON(req))
    }

    // MARK: Other vendors

    static func fetch(model: ApiModel, key: String?) async -> VendorStatus {
        var st = VendorStatus(currency: model.currency)
        guard let t = model.template else { st.error = "未知厂商"; return st }
        do {
            switch t.kind {
            case .codex:
                return st
            case .costs:
                guard let key, !key.isEmpty else { throw VendorError.noKey(model.keyRef) }
                let c = try await CostAPI.fetch(provider: t.id, key: key)
                st.costToday = c.today; st.costMonth = c.month; st.currency = "USD"
            case .quota:
                guard let q = t.quota else { return st }
                guard let key, !key.isEmpty else { throw VendorError.noKey(model.keyRef) }
                let url = model.urlOverride.isEmpty ? q.url : model.urlOverride
                let auth = model.authOverride.isEmpty ? q.auth : model.authOverride
                let req = try request(url: url, defaultURL: q.url, auth: auth, key: key, base: model.baseURL,
                                      allowCustom: model.allowCustomEndpoint)
                let json = try await getJSON(req)
                (st.windows, st.level) = parseQuota(json, q)
            case .balance:
                guard let b = t.balance else { return st }
                let url = model.urlOverride.isEmpty ? b.url : model.urlOverride
                if url.isEmpty {
                    st.error = t.noBalanceAPI ? nil : "还没有填写余额接口地址"
                    return st
                }
                guard let key, !key.isEmpty else { throw VendorError.noKey(model.keyRef) }
                let auth = model.authOverride.isEmpty ? b.auth : model.authOverride
                let req = try request(url: url, defaultURL: b.url, auth: auth, key: key, base: model.baseURL,
                                      allowCustom: model.allowCustomEndpoint)
                let json = try await getJSON(req)
                if t.id == "deepseek" {
                    let d = try parseDeepSeek(json)
                    st.balance = d.total; st.bonus = d.bonus; st.recharge = d.recharge; st.currency = d.currency
                } else {
                    let scale = model.scale > 0 ? model.scale : b.scale
                    let rp = model.remainingPath.isEmpty ? b.remaining : model.remainingPath
                    let tp = model.totalPath.isEmpty ? b.total : model.totalPath
                    let up = model.usedPath.isEmpty ? b.used : model.usedPath
                    if !rp.isEmpty, let r = JSONPath.number(json, rp) {
                        st.balance = r * scale
                    } else if !tp.isEmpty, let total = JSONPath.number(json, tp) {
                        st.total = total * scale
                        var used: Double? = up.isEmpty ? nil : JSONPath.number(json, up).map { $0 * scale }
                        if used == nil, !b.usageURL.isEmpty {
                            let ureq = try request(url: b.usageURL, defaultURL: b.usageURL, auth: auth, key: key,
                                                   base: model.baseURL, allowCustom: model.allowCustomEndpoint)
                            let uj = try await getJSON(ureq)
                            used = JSONPath.number(uj, b.usageUsed).map { $0 * b.usageScale }
                        }
                        st.used = used
                        st.balance = total * scale - (used ?? 0)
                    } else {
                        throw VendorError.parse("字段路径没有取到数值")
                    }
                }
            }
            st.updatedAt = Date()
        } catch {
            st.error = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
        return st
    }

    static func parseQuota(_ json: Any, _ q: QuotaSpec) -> ([QuotaWindow], String?) {
        let level = q.level.isEmpty ? nil : (JSONPath.get(json, q.level) as? String)
        if !q.windows.isEmpty {
            let wins = q.windows.map { w -> QuotaWindow in
                var node: Any? = json
                if let list = w.pickList {
                    let arr = JSONPath.get(json, list) as? [[String: Any]] ?? []
                    node = arr.first { el in
                        let typeOK = w.pickTypes.isEmpty || w.pickTypes.contains(el["type"] as? String ?? "")
                        let unitOK = w.pickUnit == nil || Int(JSONPath.toNumber(el["unit"]) ?? -1) == w.pickUnit
                        return typeOK && unitOK
                    }
                }
                var pct = JSONPath.number(node, w.percent)
                if w.percentIsRemaining, let p = pct { pct = 100 - p }
                return QuotaWindow(key: w.key, label: w.label, usedPct: pct,
                                   resetAt: w.resetAt.isEmpty ? nil : JSONPath.date(JSONPath.get(node, w.resetAt)))
            }
            return (wins, level)
        }
        let remain = JSONPath.number(json, q.remain)
        let total = JSONPath.number(json, q.total)
        var pct: Double? = nil
        if let r = remain, let t = total, t > 0 { pct = (1 - r / t) * 100 }
        return ([QuotaWindow(key: "main", label: "额度", usedPct: pct, resetAt: JSONPath.date(JSONPath.get(json, q.resetAt)))], level)
    }

    /// "Test connectivity": balance/quota endpoint if any, else the probe URL.
    static func test(model: ApiModel, key: String?) async -> String {
        guard let t = model.template else { return "未知厂商" }
        if t.kind == .codex {
            let s = CodexStats.shared.snapshot()
            return "本地统计：今日 \(CodexStats.formatTokens(s.today)) tokens，共 \(s.fileCount) 个会话文件"
        }
        if t.kind == .costs {
            let st = await fetch(model: model, key: key)
            if let e = st.error { return "❌ " + e }
            return "✅ 本月 " + Money.format(st.costMonth, currency: "USD") + "，今天 " + Money.format(st.costToday, currency: "USD")
        }
        if t.hasBalanceAPI || t.kind == .quota || !model.urlOverride.isEmpty {
            let st = await fetch(model: model, key: key)
            if let e = st.error { return "❌ " + e }
            if let b = st.balance { return "✅ 余额 " + Money.format(b, currency: st.currency) }
            if !st.windows.isEmpty {
                return "✅ " + st.windows.map { "\($0.label) 已用 \($0.usedPct.map { String(format: "%.0f%%", $0) } ?? "—")" }.joined(separator: " · ")
            }
            return "✅ 已连通"
        }
        guard !t.probeURL.isEmpty else { return "该厂商没有可用于测试的接口" }
        let needsKey = !t.keyRef.isEmpty
        if needsKey && (key ?? "").isEmpty { return "❌ 还没有填写密钥（\(model.keyRef)）" }
        do {
            let auth = model.authOverride.isEmpty ? (t.balance?.auth ?? "Bearer {key}") : model.authOverride
            let req = try request(url: t.probeURL, defaultURL: t.probeURL, auth: needsKey ? auth : "", key: key ?? "",
                                  base: model.baseURL, allowCustom: model.allowCustomEndpoint || !needsKey)
            _ = try await getJSON(req)
            return "✅ 密钥可用（该厂商没有余额接口，余额显示「—」）"
        } catch {
            return "❌ " + ((error as? LocalizedError)?.errorDescription ?? error.localizedDescription)
        }
    }
}
