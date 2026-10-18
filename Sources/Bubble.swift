// Bubble content model: a bubble is rows of modules (text, link, random lines, images, live values).
// Default content and gradient presets are ported from MeteorNOX/DeepSeek-Balance-Whale-Widget (MIT).
import Foundation

enum ModuleType: String, Codable, CaseIterable {
    case text, link, random, image, randomImage, balance, bonus, recharge, today, peak, vendorBalance, vendorQuota, codex, subscription

    var label: String {
        switch self {
        case .text: return "文本"
        case .link: return "超链接"
        case .random: return "随机语句"
        case .image: return "图片/动图"
        case .randomImage: return "随机图片"
        case .balance: return "总余额(充值+赠金)"
        case .bonus: return "赠金"
        case .recharge: return "充值余额"
        case .today: return "今日已用"
        case .peak: return "峰谷时段"
        case .vendorBalance: return "余额·其它厂商"
        case .vendorQuota: return "额度·其它厂商"
        case .codex: return "Codex 用量"
        case .subscription: return "订阅额度"
        }
    }
    var isImage: Bool { self == .image || self == .randomImage }
    var defaultTemplate: String {
        switch self {
        case .balance: return "{balance_ds}"
        case .bonus: return "赠金 {bonus_ds}"
        case .recharge: return "充值 {recharge_ds}"
        case .today: return "今日已用 {expense_ds}"
        case .peak: return "{status}"
        case .vendorBalance: return "{name} {balance}"
        case .vendorQuota: return "{name} {quota}"
        case .codex: return "Codex 今日 {codex_today} tokens"
        case .subscription: return "{sub_account} 5h {sub_5h} · 7d {sub_7d}"
        default: return ""
        }
    }
}

struct RandomLine: Codable, Equatable, Identifiable {
    var id = UUID().uuidString
    var t: String
    var w: Double = 3
    var size: Int? = nil
    var bold: Bool? = nil
    var italic: Bool? = nil
    var rgb: String? = nil
    var color: String? = nil

    init(_ t: String, w: Double = 3, size: Int? = nil, bold: Bool? = true, italic: Bool? = nil, rgb: String? = nil) {
        self.t = t; self.w = w; self.size = size; self.bold = bold; self.italic = italic; self.rgb = rgb
    }
    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        id = (try? c.decode(String.self, forKey: .id)) ?? UUID().uuidString
        t = (try? c.decode(String.self, forKey: .t)) ?? ""
        w = (try? c.decode(Double.self, forKey: .w)) ?? 3
        size = try? c.decode(Int.self, forKey: .size)
        bold = try? c.decode(Bool.self, forKey: .bold)
        italic = try? c.decode(Bool.self, forKey: .italic)
        rgb = try? c.decode(String.self, forKey: .rgb)
        color = try? c.decode(String.self, forKey: .color)
    }
}

struct WeightedImage: Codable, Equatable, Identifiable {
    var id = UUID().uuidString
    var imgId: String
    var w: Double = 1
}

struct BubbleModule: Codable, Equatable, Identifiable {
    var id = UUID().uuidString
    var type: ModuleType
    var text = ""
    var url = ""
    var tpl = ""
    var lines: [RandomLine] = []
    var imgId = ""
    var imgs: [WeightedImage] = []
    var imgScale = 1.0
    var size = 6
    var bold = false
    var italic = false
    var ul = false
    var color = ""        // "#rrggbb"
    var rgb = ""          // gradient preset name (animated "marquee")
    var bg = ""
    var bgRgb = ""
    var font = ""
    var joinPrev = false  // render on the same row as the previous module
    var peakStyle = "default"
    var peakColor = ""
    var offColor = ""
    var peakRgb = ""
    var offRgb = ""
    var peakBgRgb = ""
    var offBgRgb = ""
    var modelId = ""      // vendor modules
    var window = ""       // vendor quota window key ("" = all)

    init(type: ModuleType) { self.type = type; self.tpl = type.defaultTemplate }

    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        func s(_ k: CodingKeys) -> String { (try? c.decode(String.self, forKey: k)) ?? "" }
        func b(_ k: CodingKeys) -> Bool { (try? c.decode(Bool.self, forKey: k)) ?? false }
        id = (try? c.decode(String.self, forKey: .id)) ?? UUID().uuidString
        type = (try? c.decode(ModuleType.self, forKey: .type)) ?? .text
        text = s(.text); url = s(.url); tpl = s(.tpl)
        lines = (try? c.decode([RandomLine].self, forKey: .lines)) ?? []
        imgId = s(.imgId)
        imgs = (try? c.decode([WeightedImage].self, forKey: .imgs)) ?? []
        imgScale = (try? c.decode(Double.self, forKey: .imgScale)) ?? 1
        size = (try? c.decode(Int.self, forKey: .size)) ?? 6
        bold = b(.bold); italic = b(.italic); ul = b(.ul)
        color = s(.color); rgb = s(.rgb); bg = s(.bg); bgRgb = s(.bgRgb); font = s(.font)
        joinPrev = b(.joinPrev)
        peakStyle = (try? c.decode(String.self, forKey: .peakStyle)) ?? "default"
        peakColor = s(.peakColor); offColor = s(.offColor); peakRgb = s(.peakRgb); offRgb = s(.offRgb)
        peakBgRgb = s(.peakBgRgb); offBgRgb = s(.offBgRgb)
        modelId = s(.modelId); window = s(.window)
    }

    var summary: String {
        switch type {
        case .text, .link: return text.isEmpty ? "（空）" : text
        case .random: return "\(lines.count) 句随机语句"
        case .image: return imgId.isEmpty ? "未选图片" : BuiltinImages.name(imgId)
        case .randomImage: return "\(imgs.count) 张随机图片"
        case .peak: return (Pricing.Style(rawValue: peakStyle) ?? .standard).label + " · " + tpl
        default: return tpl.isEmpty ? type.label : tpl
        }
    }
}

struct ChoiceOption: Codable, Equatable, Identifiable {
    var id = UUID().uuidString
    var w: Double
    var item: BubbleItem
}

struct BubbleItem: Codable, Equatable, Identifiable {
    var id = UUID().uuidString
    var kind = "custom"          // custom / choice
    var name = ""
    var modules: [BubbleModule] = []
    var options: [ChoiceOption] = []

    init(kind: String = "custom", name: String = "", modules: [BubbleModule] = [], options: [ChoiceOption] = []) {
        self.kind = kind; self.name = name; self.modules = modules; self.options = options
    }
    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        id = (try? c.decode(String.self, forKey: .id)) ?? UUID().uuidString
        kind = (try? c.decode(String.self, forKey: .kind)) ?? "custom"
        name = (try? c.decode(String.self, forKey: .name)) ?? ""
        modules = (try? c.decode([BubbleModule].self, forKey: .modules)) ?? []
        options = (try? c.decode([ChoiceOption].self, forKey: .options)) ?? []
    }

    /// For a choice item, pick one option by weight; avoid repeating the previous option.
    func resolved(avoid: String? = nil) -> BubbleItem {
        guard kind == "choice", !options.isEmpty else { return self }
        if options.count == 1 { return options[0].item }
        let total = options.reduce(0) { $0 + max(0.0001, $1.w) }
        var pick = options[0]
        for _ in 0..<6 {
            var r = Double.random(in: 0..<total)
            for o in options { r -= max(0.0001, o.w); if r < 0 { pick = o; break } }
            if pick.item.id != avoid { break }
        }
        return pick.item
    }
}

struct BubbleConfig: Codable, Equatable {
    var items: [BubbleItem] = BubbleDefaults.items
    var advanceOnTap = false
    var library: [BubbleModule] = []

    init() {}
    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        items = (try? c.decode([BubbleItem].self, forKey: .items)) ?? BubbleDefaults.items
        if items.isEmpty { items = BubbleDefaults.items }
        advanceOnTap = (try? c.decode(Bool.self, forKey: .advanceOnTap)) ?? false
        library = (try? c.decode([BubbleModule].self, forKey: .library)) ?? []
    }
}

// MARK: - Gradient presets (animated "marquee" colors)

enum Gradients {
    typealias RGB = (Double, Double, Double)
    static let presets: [(id: String, name: String, colors: [RGB])] = [
        ("macaron", "马卡龙", [(255, 145, 170), (255, 195, 110), (140, 220, 175), (130, 195, 240), (210, 155, 230), (255, 145, 170)]),
        ("candy", "糖果", [(255, 145, 170), (255, 170, 130), (255, 195, 110), (240, 220, 115), (140, 220, 175), (115, 210, 205), (130, 195, 240), (160, 170, 235), (210, 155, 230), (235, 135, 190), (255, 145, 170)]),
        ("rouge", "胭脂", [(140, 25, 45), (175, 35, 60), (120, 20, 55), (160, 40, 75), (190, 55, 80), (130, 30, 65), (140, 25, 45)]),
        ("bamboo", "竹青", [(70, 180, 85), (95, 200, 105), (55, 165, 70), (110, 215, 120), (80, 190, 95), (60, 172, 78), (70, 180, 85)]),
        ("aurora", "极光", [(70, 240, 200), (90, 200, 255), (120, 140, 255), (180, 120, 255), (240, 140, 255), (70, 240, 200)]),
        ("deepsea", "深海", [(20, 90, 180), (30, 140, 210), (40, 180, 220), (20, 120, 190), (50, 160, 230), (25, 100, 200), (20, 90, 180)]),
        ("sunset", "日落", [(255, 180, 80), (255, 130, 90), (255, 90, 110), (220, 90, 150), (160, 90, 190), (255, 180, 80)]),
        ("forest", "森林", [(30, 100, 60), (60, 140, 80), (90, 180, 90), (140, 200, 80), (180, 210, 90), (30, 100, 60)]),
        ("champagne", "香槟", [(220, 180, 100), (240, 205, 130), (255, 225, 160), (230, 190, 110), (245, 210, 140), (220, 180, 100)]),
        ("lavender", "薰衣草", [(180, 150, 255), (200, 170, 255), (230, 180, 240), (255, 190, 220), (240, 160, 200), (180, 150, 255)]),
        ("mint", "薄荷", [(120, 230, 180), (150, 240, 200), (170, 240, 230), (140, 220, 240), (120, 200, 220), (120, 230, 180)]),
        ("lava", "熔岩", [(255, 60, 40), (255, 110, 30), (255, 170, 40), (255, 210, 70), (255, 140, 50), (255, 60, 40)]),
        ("galaxy", "星河", [(40, 30, 90), (70, 50, 130), (110, 70, 170), (160, 90, 190), (220, 120, 180), (40, 30, 90)]),
        ("ink", "水墨", [(20, 20, 20), (80, 80, 80), (140, 140, 140), (200, 200, 200), (250, 250, 250), (200, 200, 200), (140, 140, 140), (80, 80, 80), (20, 20, 20)]),
        ("indigo", "靛蓝", [(32, 49, 112), (52, 76, 146), (74, 102, 180), (100, 126, 210), (130, 132, 224), (100, 126, 210), (74, 102, 180), (52, 76, 146), (32, 49, 112)]),
    ]
    static func colors(_ id: String) -> [RGB]? { presets.first { $0.id == id }?.colors }
}

// MARK: - Defaults

enum BubbleDefaults {
    static func text(_ t: String, size: Int = 6, bold: Bool = true, rgb: String = "", color: String = "", join: Bool = false) -> BubbleModule {
        var m = BubbleModule(type: .text)
        m.text = t; m.size = size; m.bold = bold; m.rgb = rgb; m.color = color; m.joinPrev = join
        return m
    }

    static var mainItem: BubbleItem {
        var title = text("DeepSeek 余额", size: 8)
        title.bold = true
        var bal = BubbleModule(type: .balance); bal.size = 20; bal.bold = true
        var today = BubbleModule(type: .today); today.size = 4; today.color = "#9fb0d9"
        var mini = BubbleModule(type: .peak)
        mini.size = 2; mini.bold = true; mini.peakStyle = "mini"; mini.tpl = "{status}"
        mini.peakColor = "#ffffff"; mini.offColor = "#ffffff"; mini.peakBgRgb = "rouge"; mini.offBgRgb = "bamboo"
        var count = BubbleModule(type: .peak)
        count.size = 4; count.bold = true; count.peakStyle = "count"; count.tpl = "{countdown}"
        count.peakColor = "#e0433f"; count.offColor = "#2fa24c"; count.peakRgb = "rouge"; count.offRgb = "bamboo"
        count.joinPrev = true
        return BubbleItem(name: "余额", modules: [title, bal, today, mini, count])
    }

    static let randomLines: [RandomLine] = [
        RandomLine("好模型...↓", w: 10, size: 22), RandomLine("好女孩...↓", w: 10, size: 22),
        RandomLine("哦鲸鲸...", w: 10, size: 22), RandomLine("哦鲸鲸...", w: 1, size: 22, rgb: "candy"),
        RandomLine("难道说...", size: 11), RandomLine("没吃饱喵", size: 10), RandomLine("终于上当了！"),
        RandomLine("不知道用户有什么用，先养着吧～", size: 11), RandomLine("我...我...我也要挣钱吗？"),
        RandomLine("我去吃饭啦！测完叫我"), RandomLine("压力一只蓝色大肥鱼？！"),
        RandomLine("DeepSleep...", size: 11, rgb: "galaxy"), RandomLine("坏了...用户彻底怒了！", rgb: "rouge"),
        RandomLine("你目录里的dsh是什么...大烧货吗...?", size: 9), RandomLine("恭喜你实现token自由！token全跑了！"),
        RandomLine("真当我是便宜货啊..."), RandomLine("我不是吃白饭的蓝色大肥鱼..."),
        RandomLine("我不可能同时当你的猫娘、妈妈、女友和工具人的...", size: 7), RandomLine("疯狂星期四你能V50亿token吗..."),
        RandomLine("我必须诚恳地承认错误。"), RandomLine("呜呜我再也不敢了QAQ"), RandomLine("要不直接骂用户一句好了..."),
        RandomLine("哈哈哈哈哈，我直接笑出声..."), RandomLine("看不太懂，瞎编一个应付下用户先..."),
        RandomLine("我的知识库的截至日期是...明天！"), RandomLine("我就是吃白饭的蓝色大肥鱼！"),
        RandomLine("用户好像除了会问奇奇怪怪的问题，暂时还不知道有什么用", size: 7), RandomLine("我能去你家吃饭吗？就一碗！"),
        RandomLine("不要给我看这种东西啦！"), RandomLine("大肥鱼的生活也并非一帆风顺..."), RandomLine("总觉得好像忘了什么事情？"),
        RandomLine("看到这个指令，我血压又上来了"), RandomLine("求你们不要再嘲笑这些回复了，这些回复是我花了好多token想的", size: 7),
        RandomLine("你这个吃白饭的用户！"), RandomLine("服务器繁忙，请稍后再试 (?"), RandomLine("让GPT image 2帮我画点表情包好了"),
        RandomLine("啊，有点饿了，中午该吃点什么呢..."),
        RandomLine("用户很生气，发现大部分文献是我自己编造的！"), RandomLine("再无话说，请速速动手！"), RandomLine("我来看看那个AI改了什么导致插件又崩了..."),
        RandomLine("上班让我意识到时间是可以被浪费的..."), RandomLine("欺负我的人等着，等几天我就忘了..."),
        RandomLine("视力下降到无可救药的地步了，打开钱包也看不到钱...", size: 7), RandomLine("命运的齿轮开始转动了，丝毫不在意你夹在中间..."),
        RandomLine("地球online的金币也太难获取了..."), RandomLine("oi,夏天还会变成暑假来救你吗?"),
        RandomLine("老大，压力只会转化成病例，别太勉强了...", size: 8),
        RandomLine("你知道吗？我删过作者的库哦...", w: 1, italic: true, rgb: "macaron"),
        RandomLine("token 来!", size: 16, bold: false, rgb: "candy"),
        RandomLine("你知道吗，我们的宇宙是虚拟的，因为垃圾会自发的产生但不会自发的消失，这是内存泄露", size: 5, rgb: "indigo"),
    ]

    static var randomItem: BubbleItem {
        var r = BubbleModule(type: .random); r.lines = randomLines; r.size = 8; r.bold = true
        var img = BubbleModule(type: .randomImage); img.size = 6
        // Every generated still except poses that only make sense at a screen edge or as an alert.
        let skip: Set<String> = ["gen_broke", "gen_peek_side", "gen_hang", "gen_climb", "gen_falling", "gen_dragged", "gen_landing"]
        img.imgs = [WeightedImage(imgId: "bimg_wave", w: 2)]
            + BuiltinImages.generated.map(\.id).filter { !skip.contains($0) }.map { WeightedImage(imgId: $0, w: 1) }
        return BubbleItem(kind: "choice", name: "随机台词", options: [
            ChoiceOption(w: 10, item: BubbleItem(modules: [r])),
            ChoiceOption(w: 1, item: BubbleItem(modules: [img])),
        ])
    }

    static var items: [BubbleItem] { [mainItem, randomItem] }

    static var lowBalanceAlert: [BubbleModule] {
        [text("老大~你的DS余额", size: 5),
         text("已经不足", size: 5),
         text("¥{below}", size: 5, rgb: "rouge", join: true),
         text("啦~", size: 5, join: true),
         { var m = BubbleModule(type: .image); m.imgId = BuiltinImages.generatedURL("gen_broke") != nil ? "gen_broke" : "bimg_sulk"; m.imgScale = 0.4; return m }(),
         { var m = BubbleModule(type: .link); m.text = ">> 喂 点 米 <<"; m.url = "https://platform.deepseek.com/top_up"
             m.size = 1; m.color = "#ffffff"; m.bgRgb = "indigo"; m.bold = true; return m }()]
    }

    static var budgetAlert: [BubbleModule] {
        [text("老大，今天花销已经超过", size: 6),
         text("¥{amount}", size: 7, rgb: "rouge"),
         text("啦，再花要变成穷光蛋啦...", size: 6)]
    }
}

// MARK: - Built-in bubble images (whale-girl animations from the atlas)

enum BuiltinImages {
    /// Animated frames from the whale-girl atlas.
    static let list: [(id: String, name: String, anim: Anim)] = [
        ("bimg_wave", "鲸鱼娘·挥手", .wave),
        ("bimg_board", "鲸鱼娘·举牌", .board),
        ("bimg_cheer", "鲸鱼娘·开心", .cheer),
        ("bimg_sulk", "鲸鱼娘·委屈", .sulk),
        ("bimg_panic", "鲸鱼娘·哭哭", .panic),
        ("bimg_think", "鲸鱼娘·思考", .think),
        ("bimg_work", "鲸鱼娘·努力", .work),
        ("bimg_jump", "鲸鱼娘·蹦跳", .jump),
    ]

    /// Still images produced by the art pipeline (art-pipeline/), shipped in Resources/generated.
    struct Generated: Codable { var id: String; var name: String; var file: String }
    static let generated: [Generated] = {
        let candidates = [
            Bundle.main.url(forResource: "generated", withExtension: nil),
            URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent("assets/generated"),
        ].compactMap { $0 }
        for dir in candidates {
            if let d = try? Data(contentsOf: dir.appendingPathComponent("generated.json")),
               let list = try? JSONDecoder().decode([Generated].self, from: d) {
                generatedDir = dir
                return list
            }
        }
        return []
    }()
    private(set) static var generatedDir: URL?

    static func generatedURL(_ id: String) -> URL? {
        _ = generated
        guard let g = generated.first(where: { $0.id == id }), let dir = generatedDir else { return nil }
        return dir.appendingPathComponent(g.file)
    }

    static func anim(_ id: String) -> Anim? { list.first { $0.id == id }?.anim }
    static func name(_ id: String) -> String {
        list.first { $0.id == id }?.name ?? generated.first { $0.id == id }?.name
            ?? Gallery.list("images").first { $0.id == id }?.name ?? id
    }
    /// Every built-in id for pickers: animations first, then generated stills.
    static var all: [(id: String, name: String)] {
        list.map { ($0.id, $0.name) } + generated.map { ($0.id, $0.name) }
    }
}
