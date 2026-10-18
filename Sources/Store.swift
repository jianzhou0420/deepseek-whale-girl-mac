// Persistence: JSON files in ~/Library/Application Support/WhaleBalance, API keys in the Keychain.
import Foundation
import Security

let appVersion = "0.0.5"

enum Store {
    static let dir: URL = {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let d = base.appendingPathComponent("WhaleBalance", isDirectory: true)
        try? FileManager.default.createDirectory(at: d, withIntermediateDirectories: true)
        return d
    }()
    static func sub(_ name: String) -> URL {
        let d = dir.appendingPathComponent(name, isDirectory: true)
        try? FileManager.default.createDirectory(at: d, withIntermediateDirectories: true)
        return d
    }

    /// Load a Codable value, overlaying saved keys onto the defaults so new fields keep their defaults.
    static func load<T: Codable>(_ name: String, default def: T) -> T {
        let url = dir.appendingPathComponent(name)
        guard let data = try? Data(contentsOf: url) else { return def }
        if let saved = try? JSONSerialization.jsonObject(with: data),
           let defData = try? JSONEncoder().encode(def),
           let base = try? JSONSerialization.jsonObject(with: defData) {
            let merged = merge(base, saved)
            if let mdata = try? JSONSerialization.data(withJSONObject: merged),
               let v = try? JSONDecoder().decode(T.self, from: mdata) { return v }
        }
        // Unreadable file: keep a copy instead of silently overwriting it later.
        let backup = url.appendingPathExtension("broken-\(Int(Date().timeIntervalSince1970))")
        try? FileManager.default.copyItem(at: url, to: backup)
        return def
    }

    private static func merge(_ base: Any, _ over: Any) -> Any {
        guard var b = base as? [String: Any], let o = over as? [String: Any] else { return over }
        for (k, v) in o { b[k] = b[k].map { merge($0, v) } ?? v }
        return b
    }

    @discardableResult
    static func save<T: Encodable>(_ name: String, _ value: T) -> Bool {
        let enc = JSONEncoder()
        enc.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? enc.encode(value) else { return false }
        do { try data.write(to: dir.appendingPathComponent(name), options: .atomic); return true }
        catch { NSLog("WhaleBalance: save \(name) failed: \(error)"); return false }
    }
}

enum Keychain {
    static let service = "io.github.jianzhou0420.whalebalance"

    static func get(_ ref: String) -> String? {
        guard !ref.isEmpty else { return nil }
        let q: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service,
                                kSecAttrAccount as String: ref, kSecReturnData as String: true,
                                kSecMatchLimit as String: kSecMatchLimitOne]
        var out: AnyObject?
        guard SecItemCopyMatching(q as CFDictionary, &out) == errSecSuccess, let d = out as? Data else { return nil }
        return String(data: d, encoding: .utf8)
    }

    @discardableResult
    static func set(_ ref: String, _ value: String) -> Bool {
        guard !ref.isEmpty else { return false }
        let base: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service,
                                   kSecAttrAccount as String: ref]
        SecItemDelete(base as CFDictionary)
        let v = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if v.isEmpty { return true }
        var add = base
        add[kSecValueData as String] = Data(v.utf8)
        add[kSecAttrLabel as String] = "WhaleBalance · \(ref)"
        return SecItemAdd(add as CFDictionary, nil) == errSecSuccess
    }

    static func has(_ ref: String) -> Bool { !(get(ref) ?? "").isEmpty }

    static func isValidRef(_ ref: String) -> Bool {
        ref.range(of: #"^[A-Za-z0-9_]{1,64}$"#, options: .regularExpression) != nil
    }
}

// MARK: - Settings

struct WidgetPosition: Codable, Equatable {
    var screen = ""        // NSScreen localizedName at save time
    var h = "right"        // left / right / free
    var v = "bottom"       // top / bottom / free
    var fx: Double = 0     // free axes: fraction of the visible frame
    var fy: Double = 0
}

struct AlertConfig: Codable, Equatable {
    var on: Bool
    var threshold: Double
    var closeSec: Double
    var modules: [BubbleModule]
}

struct SoundFragment: Codable, Identifiable, Equatable {
    var id: String
    var name: String
    var file: String      // file name inside audio/
    var start: Double = 0
    var end: Double = 0   // 0 = till the end
}

struct SoundGroup: Codable, Identifiable, Equatable {
    var id: String
    var name: String
    var press: String     // "sys:Pop", a fragment id, or "" for silence
    var release: String
    var preset = false
}

struct Settings: Codable, Equatable {
    var scale = 1.5
    var refreshSeconds = 60.0
    var bubbleOn = true
    var bubbleCloseSec = 5.0
    var showMenuButton = true
    var menuBarBalance = true
    var snapOn = true
    var snapMode = "ratio"         // ratio / pixel
    var snapLeft = 0.25, snapRight = 0.25, snapTop = 0.0, snapBottom = 0.25
    var snapLeftPx = 240.0, snapRightPx = 240.0, snapTopPx = 0.0, snapBottomPx = 200.0
    var flipOnLeft = true
    var position = WidgetPosition()
    var soundOn = true
    var soundGroup = "bubble"
    var volume = 0.7
    var alertSoundOn = false
    var alertSound = "sys:Glass"
    var alertVolume: Double? = nil  // nil = follow the press volume
    var lowAlert = AlertConfig(on: true, threshold: 5, closeSec: 0, modules: BubbleDefaults.lowBalanceAlert)
    var budgetAlert = AlertConfig(on: false, threshold: 10, closeSec: 0, modules: BubbleDefaults.budgetAlert)
    var roleId = "default"
    var animateRole = true
    var customGroups: [SoundGroup] = []
    var subsOn = true                 // auto-detect local subscriptions (cswap, Claude Code, Codex)
    var subsCswapOn = true
    var cswapPath = ""                // empty = auto-detect
    var subsRefreshMinutes = 5.0
    var autoPlay = AutoPlayConfig()
    var fragments: [SoundFragment] = []
}

// MARK: - Galleries (custom character images, bubble images)

struct GalleryItem: Codable, Identifiable, Equatable {
    var id: String
    var name: String
    var file: String
}

enum Gallery {
    static func list(_ kind: String) -> [GalleryItem] { Store.load("\(kind).json", default: [GalleryItem]()) }

    static func url(_ kind: String, _ item: GalleryItem) -> URL { Store.sub(kind).appendingPathComponent(item.file) }

    static func add(_ kind: String, from src: URL) throws -> GalleryItem {
        let ext = src.pathExtension.lowercased()
        guard ["png", "gif", "jpg", "jpeg", "webp", "heic"].contains(ext) else {
            throw AccountingError.message("只支持 png / gif / jpg / webp 图片")
        }
        let id = (kind == "roles" ? "role_" : "bimg_") + UUID().uuidString.prefix(8).lowercased()
        let item = GalleryItem(id: id, name: src.deletingPathExtension().lastPathComponent, file: id + "." + ext)
        try FileManager.default.copyItem(at: src, to: Store.sub(kind).appendingPathComponent(item.file))
        var items = list(kind)
        items.append(item)
        Store.save("\(kind).json", items)
        return item
    }

    static func remove(_ kind: String, _ id: String) {
        var items = list(kind)
        if let it = items.first(where: { $0.id == id }) { try? FileManager.default.removeItem(at: url(kind, it)) }
        items.removeAll { $0.id == id }
        Store.save("\(kind).json", items)
    }

    static func rename(_ kind: String, _ id: String, _ name: String) {
        var items = list(kind)
        if let i = items.firstIndex(where: { $0.id == id }) { items[i].name = name }
        Store.save("\(kind).json", items)
    }
}
