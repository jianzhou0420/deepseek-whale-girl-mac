// Development aid: WhaleSeek --snapshot <dir> renders widget states and windows to PNG files
// through real (offscreen) windows, so layout passes and AppKit controls render as in the app.
import AppKit
import SwiftUI

enum Snapshots {
    @MainActor static func capture<V: View>(_ view: V, size: NSSize, to url: URL) {
        let host = NSHostingView(rootView: view)
        host.frame = NSRect(origin: .zero, size: size)
        let w = NSWindow(contentRect: NSRect(x: -10000, y: -10000, width: size.width, height: size.height),
                         styleMask: [.borderless], backing: .buffered, defer: false)
        w.contentView = host
        w.orderFrontRegardless()
        RunLoop.main.run(until: Date().addingTimeInterval(0.6))
        host.layoutSubtreeIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.2))
        if let rep = host.bitmapImageRepForCachingDisplay(in: host.bounds) {
            host.cacheDisplay(in: host.bounds, to: rep)
            if let png = rep.representation(using: .png, properties: [:]) { try? png.write(to: url) }
        }
        w.orderOut(nil)
    }

    @MainActor static func render(to dir: String) {
        let out = URL(fileURLWithPath: dir)
        let m = AppModel.shared
        m.balance = 23.45; m.shownBalance = 23.45; m.bonus = 3; m.recharge = 20.45; m.state = .ok
        m.today = BalanceSummary(day: BeijingTime.day(), amount: 1.27, currency: "CNY", source: .observed, label: "已观测消费",
                                 needsReview: false, revision: "", partialDay: false)
        m.subs = SubscriptionsSnapshot.collect(useCswap: true, cswapOverride: m.settings.cswapPath)
        let items = BubbleDefaults.items
        let cases: [(String, BubbleMode, Bool)] = [
            ("main", .item(index: 0, item: items[0]), false),
            ("random", .item(index: 1, item: items[1].options[0].item), false),
            ("alert-low", .alert(kind: "low", modules: BubbleDefaults.lowBalanceAlert), false),
            ("budget-flipped", .alert(kind: "budget", modules: BubbleDefaults.budgetAlert), true),
            ("image", .item(index: 1, item: items[1].options[1].item), false),
            ("hidden", .hidden, false),
        ]
        let bg = Color(.sRGB, red: 0.86, green: 0.89, blue: 0.93, opacity: 1)
        for (name, mode, flip) in cases {
            m.bubble = mode
            m.flipped = flip
            m.hovering = name == "hidden"
            if case .item(_, let it) = mode, let rm = it.modules.first(where: { $0.type == .randomImage }) { m.pickedImages[rm.id] = "gen_rice" }
            capture(WidgetView(model: m, base: 375, openMenu: {}, openChat: {}).background(bg), size: NSSize(width: 375, height: 375),
                    to: out.appendingPathComponent(name + ".png"))
        }
        m.bubble = .hidden
        m.hovering = false
        for id in ["anim_eat", "anim_type", "anim_hop", "anim_dance"] where Clips.shared.clip(id) != nil {
            m.roleClip = id; m.roleAnimStart = Date().addingTimeInterval(-0.2)
            if let line = Clips.shared.clip(id)?.lines.first { m.bubble = .alert(kind: "speech", modules: [BubbleDefaults.text(line, size: 8)]) }
            capture(WidgetView(model: m, base: 375, openMenu: {}, openChat: {}).background(bg), size: NSSize(width: 375, height: 375),
                    to: out.appendingPathComponent("clip-\(id).png"))
        }
        m.roleClip = nil; m.roleAnim = .wave; m.roleAnimStart = Date()
        for (name, inner, text) in [("remark", "老大没理我，那我主动找点话说", "老大，订阅额度一周才用了22%，你这是打算留着过年吗？趁低谷还有两小时，赶紧烧点token～"),
                                    ("remark-short", nil, "低谷时段到啦，快用！")] as [(String, String?, String)] {
            var mods = [BubbleDefaults.text(text, size: 7)]
            if let inner { mods.insert(BubbleDefaults.text("（\(inner)）", size: 5, bold: false, color: "#8a93b8"), at: 0) }
            m.bubble = .alert(kind: "remark", modules: mods)
            capture(WidgetView(model: m, base: 375, openMenu: {}, openChat: {}).background(bg), size: NSSize(width: 375, height: 375),
                    to: out.appendingPathComponent(name + ".png"))
        }
        m.roleClip = nil; m.bubble = .hidden
        if CommandLine.arguments.contains("--windows") {
            for tab in SettingsTab.allCases {
                SettingsState.shared.tab = tab
                capture(SettingsView(model: m, ui: SettingsState.shared), size: NSSize(width: 720, height: 560),
                        to: out.appendingPathComponent("settings-\(tab.rawValue).png"))
            }
            capture(BubbleEditorView(model: m), size: NSSize(width: 1020, height: 640), to: out.appendingPathComponent("editor.png"))
            capture(UsageView(model: m), size: NSSize(width: 720, height: 620), to: out.appendingPathComponent("usage.png"))
            let reply = """
            好了老大，这个我熟。

            ```python
            def quicksort(a):
                if len(a) < 2:
                    return a
                p = a[0]
                return quicksort([x for x in a[1:] if x < p]) + [p] + quicksort([x for x in a[1:] if x >= p])
            ```

            | 决策 | 原因 |
            |---|---|
            | 第一个元素做 pivot | 写起来最短 |
            | 列表推导 | 好读，但会多占内存 |

            - 平均 **O(n log n)**，最坏 O(n²)
            - 不是稳定排序

            要塞进实时控制回路的话，还是直接用 `sorted()` 吧～
            """
            let conv = Conversation(title: "Python 快速排序", titled: true, messages: [
                ChatMessage(role: "user", text: "帮我写个快速排序，要完整的 Python 代码"),
                ChatMessage(role: "assistant", text: reply, inner: "又是快排，面试题吗老大", reasoning: "老大要快排……", thinkSeconds: 3, model: "deepseek-flash"),
            ])
            let demo = ChatSession()
            demo.showDemo([conv, Conversation(title: "悉尼的天气", titled: true, updated: Date().addingTimeInterval(-86400), messages: [ChatMessage(role: "user", text: "x")]),
                           Conversation(title: "论文润色", titled: true, updated: Date().addingTimeInterval(-5 * 86400), messages: [ChatMessage(role: "user", text: "x")])],
                          memories: [MemoryItem(text: "老大在悉尼读博，研究方向是机器人操作"), MemoryItem(text: "老大常用 Python 和 Swift")])
            capture(ChatView(model: m, chat: demo), size: NSSize(width: 860, height: 660), to: out.appendingPathComponent("chat.png"))
            demo.showDemo([Conversation()], memories: [])
            capture(ChatView(model: m, chat: demo), size: NSSize(width: 860, height: 660), to: out.appendingPathComponent("chat-empty.png"))
        }
    }
}
