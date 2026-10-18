// Conversations and long-term memories on disk: one JSON file per conversation in chats/, memories in memory.json.
// The single chat.json of v0.0.7 is imported once as a conversation.
import Foundation

final class ChatStore {
    private(set) var conversations: [Conversation] = []
    private(set) var memories: [MemoryItem] = Store.load("memory.json", default: [MemoryItem]())

    init() {
        let dir = Store.sub("chats")
        let files = (try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)) ?? []
        conversations = files.filter { $0.pathExtension == "json" }.compactMap { u in
            (try? Data(contentsOf: u)).flatMap { try? Self.decoder.decode(Conversation.self, from: $0) }
        }
        importLegacy()
        conversations.sort { $0.updated > $1.updated }
    }

    private static let decoder: JSONDecoder = { let d = JSONDecoder(); return d }()

    private func importLegacy() {
        let legacy = Store.dir.appendingPathComponent("chat.json")
        guard FileManager.default.fileExists(atPath: legacy.path) else { return }
        let old = Store.load("chat.json", default: [ChatMessage]())
        if !old.isEmpty {
            let c = Conversation(title: "以前的聊天", titled: true, created: old.first?.ts ?? Date(), updated: old.last?.ts ?? Date(), messages: old)
            conversations.append(c)
            save(c)
        }
        try? FileManager.default.moveItem(at: legacy, to: legacy.appendingPathExtension("imported"))
    }

    private func url(_ id: UUID) -> URL { Store.sub("chats").appendingPathComponent(id.uuidString + ".json") }

    func save(_ c: Conversation) {
        if let i = conversations.firstIndex(where: { $0.id == c.id }) { conversations[i] = c } else { conversations.insert(c, at: 0) }
        let enc = JSONEncoder()
        enc.outputFormatting = [.prettyPrinted]
        if let d = try? enc.encode(c) { try? d.write(to: url(c.id), options: .atomic) }
    }

    func delete(_ id: UUID) {
        conversations.removeAll { $0.id == id }
        try? FileManager.default.removeItem(at: url(id))
    }

    func deleteAll() { for c in conversations { delete(c.id) } }

    func setMemories(_ m: [MemoryItem]) { memories = m; Store.save("memory.json", m) }
}
