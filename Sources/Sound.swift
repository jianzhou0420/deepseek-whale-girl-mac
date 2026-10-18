// Press / release sounds and alert sounds. Built-in groups use macOS system sounds
// (the original widget's sound files are not licensed for redistribution).
import AppKit
import AVFoundation

final class SoundPlayer {
    static let shared = SoundPlayer()
    private var players: [AVAudioPlayer] = []

    static let systemSounds = ["Pop", "Tink", "Bottle", "Frog", "Purr", "Morse", "Glass", "Ping", "Submarine",
                               "Funk", "Hero", "Blow", "Basso", "Sosumi"]

    static let presetGroups: [SoundGroup] = [
        SoundGroup(id: "bubble", name: "泡泡", press: "sys:Pop", release: "sys:Tink", preset: true),
        SoundGroup(id: "bottle", name: "瓶子", press: "sys:Bottle", release: "", preset: true),
        SoundGroup(id: "frog", name: "青蛙", press: "sys:Frog", release: "sys:Purr", preset: true),
        SoundGroup(id: "morse", name: "滴答", press: "sys:Morse", release: "sys:Tink", preset: true),
    ]

    func groups(_ s: Settings) -> [SoundGroup] { Self.presetGroups + s.customGroups }

    func group(_ s: Settings) -> SoundGroup? { groups(s).first { $0.id == s.soundGroup } ?? Self.presetGroups.first }

    func name(of id: String, _ s: Settings) -> String {
        if id.isEmpty { return "（静音）" }
        if id.hasPrefix("sys:") { return "系统·" + id.dropFirst(4) }
        return s.fragments.first { $0.id == id }?.name ?? id
    }

    func play(_ id: String, volume: Double, settings: Settings? = nil) {
        guard !id.isEmpty, volume > 0 else { return }
        let s = settings ?? AppModel.shared.settings
        var url: URL?
        var start = 0.0, end = 0.0
        if id.hasPrefix("sys:") {
            url = URL(fileURLWithPath: "/System/Library/Sounds/\(id.dropFirst(4)).aiff")
        } else if let f = s.fragments.first(where: { $0.id == id }) {
            url = Store.sub("audio").appendingPathComponent(f.file)
            start = f.start; end = f.end
        }
        guard let url, let p = try? AVAudioPlayer(contentsOf: url) else { return }
        p.volume = Float(min(1, max(0, volume)))
        p.currentTime = max(0, min(start, p.duration))
        p.play()
        players.append(p)
        if end > start {
            DispatchQueue.main.asyncAfter(deadline: .now() + (end - start)) { [weak p] in p?.stop() }
        }
        players.removeAll { !$0.isPlaying && $0 !== p }
    }

    func press() {
        let s = AppModel.shared.settings
        guard s.soundOn, let g = group(s) else { return }
        play(g.press, volume: s.volume)
    }
    func release() {
        let s = AppModel.shared.settings
        guard s.soundOn, let g = group(s) else { return }
        play(g.release, volume: s.volume)
    }

    /// Copy an audio file into the data folder and register it as a fragment.
    static func importFragment(_ src: URL) throws -> SoundFragment {
        let ext = src.pathExtension.lowercased()
        guard ["mp3", "wav", "m4a", "aiff", "aif", "caf", "aac"].contains(ext) else {
            throw AccountingError.message("只支持 mp3 / wav / m4a / aiff 音频")
        }
        let id = "frag_" + UUID().uuidString.prefix(8).lowercased()
        let file = id + "." + ext
        try FileManager.default.copyItem(at: src, to: Store.sub("audio").appendingPathComponent(file))
        let dur = (try? AVAudioPlayer(contentsOf: Store.sub("audio").appendingPathComponent(file)).duration) ?? 0
        return SoundFragment(id: id, name: src.deletingPathExtension().lastPathComponent, file: file, start: 0, end: dur)
    }

    static func duration(_ f: SoundFragment) -> Double {
        (try? AVAudioPlayer(contentsOf: Store.sub("audio").appendingPathComponent(f.file)).duration) ?? 0
    }
}
