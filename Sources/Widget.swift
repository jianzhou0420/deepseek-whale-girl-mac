// The floating widget: character + bubble, drag with edge snapping, mirror when snapped left,
// press "squish", click-through outside the visible parts.
import AppKit
import Combine
import SwiftUI

struct CharacterView: View {
    @ObservedObject var model: AppModel
    var width: CGFloat

    var body: some View {
        let h = width * 208 / 192
        Group {
            if model.settings.roleId != "default",
               let item = Gallery.list("roles").first(where: { $0.id == model.settings.roleId }),
               let ns = NSImage(contentsOf: Gallery.url("roles", item)) {
                AnimatedImage(image: ns).frame(width: width, height: h)
            } else if model.settings.animateRole {
                TimelineView(.animation(minimumInterval: 1.0 / 15)) { tl in
                    let t = tl.date.timeIntervalSince(model.roleAnimStart)
                    if !model.dragging, let id = model.roleClip, let clip = Clips.shared.clip(id) {
                        clipFrame(clip, t, h)
                    } else {
                        let (r, c) = (model.dragging ? Anim.panic : model.roleAnim).frame(at: t)
                        sprite(r, c, h)
                    }
                }
            } else {
                sprite(0, 6, h)
            }
        }
        .frame(width: width, height: h)
    }

    /// A clip frame placed so the feet and figure height match the atlas character.
    func clipFrame(_ clip: Clip, _ t: Double, _ h: CGFloat) -> some View {
        let s = width / CGFloat(Atlas.cellW), k = clip.scale * s
        let img = clip.frame(at: t), feet = Clips.shared.atlasFeet
        var x = feet.x * s - clip.feet.x * k
        x -= max(0, x + clip.right * k - width)   // keep wide poses inside the window's right edge
        return Image(decorative: img, scale: 1).resizable().interpolation(.high)
            .frame(width: CGFloat(img.width) * k, height: CGFloat(img.height) * k)
            .offset(x: x, y: feet.y * s - clip.feet.y * k)
            .frame(width: width, height: h, alignment: .topLeading)
    }

    @ViewBuilder func sprite(_ r: Int, _ c: Int, _ h: CGFloat) -> some View {
        if let img = Atlas.shared.image(r, c) {
            Image(decorative: img, scale: 1).resizable().interpolation(.high).frame(width: width, height: h)
        }
    }
}

struct WidgetView: View {
    @ObservedObject var model: AppModel
    var base: CGFloat
    var openMenu: () -> Void
    var openChat: () -> Void

    static let charWidthRatio: CGFloat = 0.62
    static let menuButtonY: CGFloat = 0.36
    static let chatButtonY: CGFloat = 0.45

    var body: some View {
        let cw = base * Self.charWidthRatio
        ZStack(alignment: .topLeading) {
            CharacterView(model: model, width: cw)
                .scaleEffect(x: model.pressed ? 1.05 : 1, y: model.pressed ? 0.88 : 1, anchor: .bottom)
                .animation(.interpolatingSpring(stiffness: 420, damping: 14), value: model.pressed)
                .frame(width: base, height: base, alignment: .bottomTrailing)

            if let modules = currentModules {
                BubbleView(model: model, modules: modules, base: base, mirrored: model.flipped)
                    .onTapGesture { model.tapBubble() }
                    .transition(.scale(scale: 0.2, anchor: UnitPoint(x: 0.43, y: 0.92)).combined(with: .opacity))
                    .id(bubbleKey)
            }

            if model.hovering && model.settings.showMenuButton && !model.dragging {
                Button(action: openMenu) {
                    Image(systemName: "ellipsis.circle.fill")
                        .font(.system(size: max(14, base * 0.07)))
                        .foregroundStyle(.white, Color.bubbleStroke)
                }
                .buttonStyle(.plain)
                .scaleEffect(x: model.flipped ? -1 : 1, y: 1)
                .position(x: base * 0.95, y: base * Self.menuButtonY)
                .transition(.opacity)
            }
            if model.hovering && model.settings.chat.on && !model.dragging {
                Button(action: openChat) {
                    Image(systemName: "bubble.left.circle.fill")
                        .font(.system(size: max(14, base * 0.07)))
                        .foregroundStyle(.white, Color.bubbleStroke)
                }
                .buttonStyle(.plain)
                .scaleEffect(x: model.flipped ? -1 : 1, y: 1)
                .position(x: base * 0.95, y: base * Self.chatButtonY)
                .transition(.opacity)
                .help("和鲸鱼娘聊天")
            }
        }
        .frame(width: base, height: base, alignment: .topLeading)
        .scaleEffect(x: model.flipped ? -1 : 1, y: 1)
        .animation(.easeInOut(duration: 0.3), value: model.flipped)
        .animation(.easeInOut(duration: 0.15), value: model.hovering)
    }

    private var currentModules: [BubbleModule]? {
        switch model.bubble {
        case .hidden: return nil
        case .item(_, let item): return item.modules
        case .alert(_, let modules): return modules
        }
    }
    private var bubbleKey: String {
        switch model.bubble {
        case .hidden: return "none"
        case .item(let i, let item): return "item-\(i)-\(item.id)"
        case .alert(let k, _): return "alert-\(k)"
        }
    }
}

enum WidgetRegion { case none, character, bubble, menuButton, chatButton }

final class WidgetHostingView: NSHostingView<WidgetView> {
    weak var controller: WidgetController?
    private var region: WidgetRegion = .none
    private var downEvent: NSEvent?
    private var downMouse = NSPoint.zero
    private var downOrigin = NSPoint.zero
    private var dragged = false

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func mouseDown(with e: NSEvent) {
        guard let c = controller, let w = window else { return }
        region = c.region(at: convert(e.locationInWindow, from: nil))
        downEvent = e
        downMouse = NSEvent.mouseLocation
        downOrigin = w.frame.origin
        dragged = false
        if region == .character {
            c.model.pressed = true
            SoundPlayer.shared.press()
        }
    }

    override func mouseDragged(with e: NSEvent) {
        guard let c = controller, let w = window, region != .none, region != .menuButton, region != .chatButton else { return }
        let m = NSEvent.mouseLocation
        if !dragged && hypot(m.x - downMouse.x, m.y - downMouse.y) > 3 {
            dragged = true
            c.model.dragging = true
            c.model.pressed = false
        }
        if dragged { w.setFrameOrigin(NSPoint(x: downOrigin.x + m.x - downMouse.x, y: downOrigin.y + m.y - downMouse.y)) }
    }

    override func mouseUp(with e: NSEvent) {
        guard let c = controller else { return }
        if region == .character {
            c.model.pressed = false
            SoundPlayer.shared.release()
        }
        if dragged {
            c.model.dragging = false
            c.endDrag()
        } else if region == .character {
            c.model.tapCharacter()
        } else if region != .none, let d = downEvent {
            // Replay the click into SwiftUI (bubble tap, links, menu button).
            super.mouseDown(with: d)
            super.mouseUp(with: e)
        }
        region = .none
        downEvent = nil
        dragged = false
    }

    override func rightMouseDown(with e: NSEvent) {
        controller?.showMenu(with: e, in: self)
    }
}

final class WidgetController: NSObject {
    let model = AppModel.shared
    var window: NSWindow!
    var host: WidgetHostingView!
    var makeMenu: () -> NSMenu = { NSMenu() }
    private var pollTimer: Timer?
    private var bag = Set<AnyCancellable>()

    var base: CGFloat { min(625, max(122, 250 * CGFloat(model.settings.scale))) }

    func start() {
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: base, height: base),
                          styleMask: [.borderless], backing: .buffered, defer: false)
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.level = .floating
        window.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]
        window.isReleasedWhenClosed = false
        host = WidgetHostingView(rootView: WidgetView(model: model, base: base, openMenu: { [weak self] in self?.showMenuAtMouse() },
                   openChat: { [weak self] in self?.toggleChat() }))
        host.controller = self
        window.contentView = host
        settle(animated: false)
        window.orderFrontRegardless()

        model.$settings
            .map { "\($0.scale)|\($0.snapOn)|\($0.flipOnLeft)" }
            .removeDuplicates()
            .dropFirst()
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.resize() }
            .store(in: &bag)
        NotificationCenter.default.addObserver(forName: NSApplication.didChangeScreenParametersNotification, object: nil,
                                               queue: .main) { [weak self] _ in self?.settle(animated: false) }
        pollTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in self?.poll() }
        RunLoop.main.add(pollTimer!, forMode: .common)
    }

    // MARK: Regions (window coordinates, origin bottom-left)

    func region(at p: NSPoint) -> WidgetRegion {
        let b = base
        var x = p.x
        if model.flipped { x = b - x }
        let yTop = b - p.y   // distance from the top
        // menu button
        if model.hovering && model.settings.showMenuButton && hypot(x - b * 0.95, yTop - b * WidgetView.menuButtonY) < max(14, b * 0.05) {
            return .menuButton
        }
        if model.hovering && model.settings.chat.on && hypot(x - b * 0.95, yTop - b * WidgetView.chatButtonY) < max(14, b * 0.05) {
            return .chatButton
        }
        // character body: central part of the sprite cell at the bottom-right
        let cw = b * WidgetView.charWidthRatio
        let charRect = NSRect(x: b - cw * 0.82, y: 0, width: cw * 0.66, height: cw * 208 / 192 * 0.9)
        if charRect.contains(NSPoint(x: x, y: p.y)) { return .character }
        if case .hidden = model.bubble { return .none }
        let u = b / 1026
        let cx = 454 * u, cy = 247 * u, rx = 373 * u, ry = 232 * u
        let dx = (x - cx) / rx, dy = (yTop - cy) / ry
        if dx * dx + dy * dy <= 1 { return .bubble }
        return .none
    }

    private func poll() {
        guard let w = window else { return }
        let m = NSEvent.mouseLocation
        let local = NSPoint(x: m.x - w.frame.minX, y: m.y - w.frame.minY)
        let r = w.frame.contains(m) ? region(at: local) : .none
        let hover = r == .character || r == .menuButton || r == .chatButton
        if model.hovering != hover && !model.dragging { model.hovering = hover }
        let busy = model.pressed || model.dragging || NSEvent.pressedMouseButtons != 0 && !w.ignoresMouseEvents
        let ignore = r == .none && !busy
        if w.ignoresMouseEvents != ignore { w.ignoresMouseEvents = ignore }
    }

    // MARK: Menu

    func showMenu(with e: NSEvent, in view: NSView) {
        NSMenu.popUpContextMenu(makeMenu(), with: e, for: view)
    }
    func toggleChat() { ChatWindow.shared.toggle(near: window) }
    func showMenuAtMouse() {
        let m = makeMenu()
        let p = host.convert(window.mouseLocationOutsideOfEventStream, from: nil)
        m.popUp(positioning: nil, at: p, in: host)
    }

    // MARK: Position & snapping

    private func screen(named name: String) -> NSScreen {
        NSScreen.screens.first { $0.localizedName == name } ?? NSScreen.main ?? NSScreen.screens[0]
    }
    private func screen(containing p: NSPoint) -> NSScreen {
        NSScreen.screens.first { $0.frame.contains(p) } ?? NSScreen.main ?? NSScreen.screens[0]
    }

    func frame(for pos: WidgetPosition, size b: CGFloat) -> NSRect {
        let vf = screen(named: pos.screen).visibleFrame
        let x: CGFloat
        switch pos.h {
        case "left": x = vf.minX
        case "right": x = vf.maxX - b
        default: x = vf.minX + CGFloat(min(1, max(0, pos.fx))) * max(0, vf.width - b)
        }
        let y: CGFloat
        switch pos.v {
        case "top": y = vf.maxY - b
        case "bottom": y = vf.minY
        default: y = vf.minY + CGFloat(min(1, max(0, pos.fy))) * max(0, vf.height - b)
        }
        return NSRect(x: x, y: y, width: b, height: b)
    }

    func settle(animated: Bool) {
        let pos = model.settings.position
        let f = frame(for: pos, size: base)
        model.flipped = model.settings.flipOnLeft && pos.h == "left"
        if animated {
            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = 0.28
                ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
                window.animator().setFrame(f, display: true)
            }
        } else {
            window.setFrame(f, display: true)
        }
    }

    func resize() {
        host.rootView = WidgetView(model: model, base: base, openMenu: { [weak self] in self?.showMenuAtMouse() },
                   openChat: { [weak self] in self?.toggleChat() })
        settle(animated: false)
    }

    func endDrag() {
        let s = model.settings
        let f = window.frame
        let center = NSPoint(x: f.midX, y: f.midY)
        let scr = screen(containing: center)
        let vf = scr.visibleFrame
        var pos = WidgetPosition(screen: scr.localizedName)
        let fromLeft = center.x - vf.minX, fromRight = vf.maxX - center.x
        let fromTop = vf.maxY - center.y, fromBottom = center.y - vf.minY
        func zone(_ ratio: Double, _ px: Double, _ extent: CGFloat) -> CGFloat {
            s.snapMode == "pixel" ? CGFloat(px) : CGFloat(ratio) * extent
        }
        pos.h = "free"; pos.v = "free"
        if s.snapOn {
            if fromLeft < zone(s.snapLeft, s.snapLeftPx, vf.width) { pos.h = "left" }
            else if fromRight < zone(s.snapRight, s.snapRightPx, vf.width) { pos.h = "right" }
            if fromTop < zone(s.snapTop, s.snapTopPx, vf.height) { pos.v = "top" }
            else if fromBottom < zone(s.snapBottom, s.snapBottomPx, vf.height) { pos.v = "bottom" }
        }
        pos.fx = Double((f.minX - vf.minX) / max(1, vf.width - f.width))
        pos.fy = Double((f.minY - vf.minY) / max(1, vf.height - f.height))
        model.settings.position = pos
        settle(animated: true)
    }
}
