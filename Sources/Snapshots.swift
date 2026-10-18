// Development aid: WhaleBalance --snapshot <dir> renders widget states and windows to PNG files
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
            capture(WidgetView(model: m, base: 375, openMenu: {}).background(bg), size: NSSize(width: 375, height: 375),
                    to: out.appendingPathComponent(name + ".png"))
        }
        m.bubble = .hidden
        if CommandLine.arguments.contains("--windows") {
            for tab in SettingsTab.allCases {
                SettingsState.shared.tab = tab
                capture(SettingsView(model: m, ui: SettingsState.shared), size: NSSize(width: 720, height: 560),
                        to: out.appendingPathComponent("settings-\(tab.rawValue).png"))
            }
            capture(BubbleEditorView(model: m), size: NSSize(width: 1020, height: 640), to: out.appendingPathComponent("editor.png"))
            capture(UsageView(model: m), size: NSSize(width: 720, height: 620), to: out.appendingPathComponent("usage.png"))
        }
    }
}
