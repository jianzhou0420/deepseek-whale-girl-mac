// App entry: menu bar item, the widget's menu, auxiliary windows.
import AppKit
import Combine
import SwiftUI


final class WindowManager {
    static let shared = WindowManager()
    private var windows: [String: NSWindow] = [:]

    func show<V: View>(_ id: String, title: String, size: NSSize, @ViewBuilder _ content: () -> V) {
        if let w = windows[id] {
            NSApp.activate(ignoringOtherApps: true)
            w.makeKeyAndOrderFront(nil)
            return
        }
        let w = NSWindow(contentRect: NSRect(origin: .zero, size: size),
                         styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
        w.title = title
        w.contentViewController = NSHostingController(rootView: content())
        w.setContentSize(size)
        w.center()
        w.isReleasedWhenClosed = false
        w.delegate = WindowCloser.shared
        windows[id] = w
        NSApp.activate(ignoringOtherApps: true)
        w.makeKeyAndOrderFront(nil)
    }

    func close(_ id: String) { windows[id]?.close() }
    func forget(_ w: NSWindow) { windows = windows.filter { $0.value !== w } }
}

final class WindowCloser: NSObject, NSWindowDelegate {
    static let shared = WindowCloser()
    func windowWillClose(_ n: Notification) {
        if let w = n.object as? NSWindow { WindowManager.shared.forget(w) }
    }
}

/// An NSMenuItem hosting a slider.
final class SliderMenuItem: NSMenuItem {
    private let onChange: (Double) -> Void
    init(title: String, value: Double, min: Double, max: Double, onChange: @escaping (Double) -> Void) {
        self.onChange = onChange
        super.init(title: title, action: nil, keyEquivalent: "")
        let v = NSView(frame: NSRect(x: 0, y: 0, width: 220, height: 30))
        let label = NSTextField(labelWithString: title)
        label.frame = NSRect(x: 20, y: 7, width: 40, height: 16)
        label.font = .menuFont(ofSize: 13)
        let s = NSSlider(value: value, minValue: min, maxValue: max, target: nil, action: nil)
        s.frame = NSRect(x: 62, y: 5, width: 145, height: 20)
        s.target = self
        s.action = #selector(changed(_:))
        s.isContinuous = true
        v.addSubview(label); v.addSubview(s)
        view = v
    }
    required init(coder: NSCoder) { fatalError() }
    @objc private func changed(_ s: NSSlider) { onChange(s.doubleValue) }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    let model = AppModel.shared
    let widget = WidgetController()
    var statusItem: NSStatusItem!
    private var bag = Set<AnyCancellable>()

    func applicationDidFinishLaunching(_ n: Notification) {
        widget.makeMenu = { [weak self] in self?.buildMenu() ?? NSMenu() }
        widget.start()
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.title = model.statusTitle
        statusItem.menu = buildMenu()
        Publishers.CombineLatest3(model.$shownBalance, model.$balance, model.$settings)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                guard let self else { return }
                self.statusItem.button?.title = self.model.statusTitle
                self.statusItem.button?.toolTip = self.tooltip
            }
            .store(in: &bag)
        NotificationCenter.default.addObserver(forName: NSMenu.didBeginTrackingNotification, object: statusItem.menu,
                                               queue: .main) { [weak self] _ in self?.statusItem.menu = self?.buildMenu() }
        model.start()
        let args = CommandLine.arguments
        if let i = args.firstIndex(of: "--open"), i + 1 < args.count {   // development aid
            let what = args[i + 1]
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                if what == "editor" { Windows.bubbleEditor() }
                else if what == "usage" { Windows.usage() }
                else if let t = SettingsTab(rawValue: what) { Windows.settings(tab: t) }
            }
            return
        }
        if model.deepseekKey == nil {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { Windows.settings(tab: .deepseek) }
        }
    }

    private var tooltip: String {
        var s = "DeepSeek 余额：" + model.amountText(model.balance)
        s += "\n今日已用：" + model.todayText
        s += "\n" + Pricing.statusText(.standard) + "，" + Pricing.countdown() + " 后切换"
        return s
    }

    private func item(_ title: String, _ action: @escaping () -> Void, checked: Bool = false) -> NSMenuItem {
        let i = ClosureMenuItem(title: title, action: action)
        i.state = checked ? .on : .off
        return i
    }

    func buildMenu() -> NSMenu {
        let m = NSMenu()
        let s = model.settings
        let head = NSMenuItem(title: "余额 " + model.amountText(model.balance) + "  ·  今日 " + model.todayText, action: nil, keyEquivalent: "")
        head.isEnabled = false
        m.addItem(head)
        m.addItem(item("刷新余额") { [weak self] in self?.model.refresh(manual: true) })
        if case .hidden = model.bubble {
            m.addItem(item("显示气泡") { [weak self] in self?.model.showItem(0) })
        } else {
            m.addItem(item("收起气泡") { [weak self] in self?.model.hideBubble() })
        }
        m.addItem(.separator())

        m.addItem(SliderMenuItem(title: "大小", value: s.scale, min: 0.6, max: 2.5) { [weak self] v in
            self?.model.settings.scale = (v * 10).rounded() / 10
        })

        let sound = NSMenu()
        sound.addItem(item("按压音效", { [weak self] in self?.model.settings.soundOn.toggle() }, checked: s.soundOn))
        sound.addItem(.separator())
        for g in SoundPlayer.shared.groups(s) {
            sound.addItem(item(g.name, { [weak self] in
                self?.model.settings.soundGroup = g.id
                SoundPlayer.shared.press()
            }, checked: s.soundGroup == g.id))
        }
        sound.addItem(.separator())
        sound.addItem(SliderMenuItem(title: "音量", value: s.volume, min: 0, max: 1) { [weak self] v in self?.model.settings.volume = v })
        sound.addItem(item("音效与提示设置…") { Windows.settings(tab: .sound) })
        let soundItem = NSMenuItem(title: "音效", action: nil, keyEquivalent: ""); soundItem.submenu = sound
        m.addItem(soundItem)

        let bubble = NSMenu()
        bubble.addItem(item("点击时弹出气泡", { [weak self] in self?.model.settings.bubbleOn.toggle() }, checked: s.bubbleOn))
        bubble.addItem(item("点按角色推进队列", { [weak self] in self?.model.bubbleConfig.advanceOnTap.toggle() },
                            checked: model.bubbleConfig.advanceOnTap))
        bubble.addItem(item("自定义泡泡…") { Windows.bubbleEditor() })
        let bubbleItem = NSMenuItem(title: "气泡", action: nil, keyEquivalent: ""); bubbleItem.submenu = bubble
        m.addItem(bubbleItem)

        let snap = NSMenu()
        snap.addItem(item("吸附到屏幕边缘", { [weak self] in self?.model.settings.snapOn.toggle() }, checked: s.snapOn))
        snap.addItem(item("贴左时水平翻转", { [weak self] in
            self?.model.settings.flipOnLeft.toggle(); self?.widget.settle(animated: true)
        }, checked: s.flipOnLeft))
        snap.addItem(item("回到右下角") { [weak self] in
            self?.model.settings.position = WidgetPosition(screen: NSScreen.main?.localizedName ?? "", h: "right", v: "bottom")
            self?.widget.settle(animated: true)
        })
        snap.addItem(item("自定义吸附区…") { Windows.settings(tab: .snap) })
        let snapItem = NSMenuItem(title: "吸附与翻转", action: nil, keyEquivalent: ""); snapItem.submenu = snap
        m.addItem(snapItem)
        m.addItem(.separator())

        let auto = NSMenu()
        auto.addItem(item("自动播放", { [weak self] in self?.model.settings.autoPlay.on.toggle() }, checked: s.autoPlay.on))
        auto.addItem(item("现在来一个") { [weak self] in
            guard let self else { return }
            if let a = AutoPlayPolicy.pick(self.model.settings.autoPlay, r: .random(in: 0..<1)) { self.model.autoPlayer.play(a) }
        })
        auto.addItem(item("自动播放设置…") { Windows.settings(tab: .autoplay) })
        let autoItem = NSMenuItem(title: "自动播放", action: nil, keyEquivalent: ""); autoItem.submenu = auto
        m.addItem(autoItem)
        m.addItem(.separator())

        m.addItem(item("小鲸鱼记账…") { Windows.usage() })
        m.addItem(item("订阅与用量…") { Windows.settings(tab: .subscriptions) })
        m.addItem(item("模型与厂商…") { Windows.settings(tab: .vendors) })
        m.addItem(item("余额预警与今日预算…") { Windows.settings(tab: .alerts) })
        m.addItem(item("资源管理…") { Windows.settings(tab: .resources) })
        m.addItem(item("设置…") { Windows.settings(tab: .general) })
        m.addItem(.separator())
        m.addItem(item("显示菜单按钮", { [weak self] in self?.model.settings.showMenuButton.toggle() }, checked: s.showMenuButton))
        m.addItem(item("菜单栏显示余额", { [weak self] in self?.model.settings.menuBarBalance.toggle() }, checked: s.menuBarBalance))
        m.addItem(item("开机自动启动", { [weak self] in
            guard let self else { return }
            self.model.launchAtLogin = !self.model.launchAtLogin
        }, checked: model.launchAtLogin))
        m.addItem(.separator())
        let ver = NSMenuItem(title: "WhaleSeek v\(appVersion)", action: nil, keyEquivalent: "")
        ver.isEnabled = false
        m.addItem(ver)
        m.addItem(item("退出") { NSApp.terminate(nil) })
        return m
    }
}

final class ClosureMenuItem: NSMenuItem {
    private let handler: () -> Void
    init(title: String, action: @escaping () -> Void) {
        handler = action
        super.init(title: title, action: #selector(run), keyEquivalent: "")
        target = self
    }
    required init(coder: NSCoder) { fatalError() }
    @objc private func run() { handler() }
}

enum Windows {
    static func settings(tab: SettingsTab) {
        SettingsState.shared.tab = tab
        WindowManager.shared.show("settings", title: "WhaleSeek 设置", size: NSSize(width: 720, height: 560)) {
            SettingsView(model: AppModel.shared, ui: SettingsState.shared)
        }
    }
    static func bubbleEditor() {
        WindowManager.shared.show("bubble", title: "自定义泡泡", size: NSSize(width: 1020, height: 640)) {
            BubbleEditorView(model: AppModel.shared)
        }
    }
    static func usage() {
        WindowManager.shared.show("usage", title: "小鲸鱼记账", size: NSSize(width: 720, height: 620)) {
            UsageView(model: AppModel.shared)
        }
    }
}

@main
struct Main {
    static func main() {
        Migration.run()
        let args = CommandLine.arguments
        if let i = args.firstIndex(of: "--snapshot"), i + 1 < args.count {
            MainActor.assumeIsolated { Snapshots.render(to: args[i + 1]) }
            exit(0)
        }
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.accessory)
        withExtendedLifetime(delegate) { app.run() }
    }
}
