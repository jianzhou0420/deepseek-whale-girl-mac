// A small Markdown block parser for chat replies: headings, paragraphs, fenced code, lists, quotes, tables, rules.
// Inline syntax (bold, italic, code, links) is left to AttributedString. Tolerates unfinished input while streaming.
import Foundation

enum MDBlock: Equatable {
    case heading(Int, String)
    case paragraph(String)
    case code(String, String)               // language, code
    case list([MDItem])
    case quote(String)
    case table([String], [[String]])
    case rule
}

struct MDItem: Equatable {
    var marker: String                      // "•" or "1."
    var text: String
    var depth: Int
}

enum Markdown {
    static func blocks(_ src: String) -> [MDBlock] {
        let lines = src.replacingOccurrences(of: "\r\n", with: "\n").components(separatedBy: "\n")
        var out: [MDBlock] = []
        var para: [String] = []
        var i = 0
        func flushPara() {
            if !para.isEmpty { out.append(.paragraph(para.joined(separator: "\n"))); para = [] }
        }
        while i < lines.count {
            let line = lines[i]
            let t = line.trimmingCharacters(in: .whitespaces)
            if t.hasPrefix("```") || t.hasPrefix("~~~") {
                flushPara()
                let fence = String(t.prefix(3))
                let lang = String(t.dropFirst(3)).trimmingCharacters(in: .whitespaces)
                var code: [String] = []
                i += 1
                while i < lines.count, !lines[i].trimmingCharacters(in: .whitespaces).hasPrefix(fence) { code.append(lines[i]); i += 1 }
                out.append(.code(lang, code.joined(separator: "\n")))
                i += 1
                continue
            }
            if t.isEmpty { flushPara(); i += 1; continue }
            if let h = heading(t) { flushPara(); out.append(.heading(h.0, h.1)); i += 1; continue }
            if isRule(t) { flushPara(); out.append(.rule); i += 1; continue }
            if t.hasPrefix("|"), i + 1 < lines.count, isTableSeparator(lines[i + 1]) {
                flushPara()
                let header = cells(t)
                var rows: [[String]] = []
                i += 2
                while i < lines.count, lines[i].trimmingCharacters(in: .whitespaces).hasPrefix("|") {
                    var r = cells(lines[i].trimmingCharacters(in: .whitespaces))
                    if r.count < header.count { r += Array(repeating: "", count: header.count - r.count) }
                    rows.append(Array(r.prefix(header.count)))
                    i += 1
                }
                out.append(.table(header, rows))
                continue
            }
            if listItem(line) != nil {
                flushPara()
                var items: [MDItem] = []
                while i < lines.count {
                    if let it = listItem(lines[i]) {
                        // A switch between bullets and numbers at the top level starts a new list.
                        if let first = items.first, it.depth == 0, isOrdered(it) != isOrdered(first) { break }
                        items.append(it); i += 1; continue
                    }
                    let next = lines[i]
                    // An indented line continues the previous item.
                    if !items.isEmpty, next.hasPrefix("  "), !next.trimmingCharacters(in: .whitespaces).isEmpty {
                        items[items.count - 1].text += "\n" + next.trimmingCharacters(in: .whitespaces); i += 1; continue
                    }
                    break
                }
                out.append(.list(items))
                continue
            }
            if t.hasPrefix(">") {
                flushPara()
                var q: [String] = []
                while i < lines.count {
                    let s = lines[i].trimmingCharacters(in: .whitespaces)
                    guard s.hasPrefix(">") else { break }
                    q.append(String(s.dropFirst()).trimmingCharacters(in: .whitespaces)); i += 1
                }
                out.append(.quote(q.joined(separator: "\n")))
                continue
            }
            para.append(t)
            i += 1
        }
        flushPara()
        return out
    }

    private static func heading(_ t: String) -> (Int, String)? {
        let hashes = t.prefix { $0 == "#" }.count
        guard (1...6).contains(hashes), t.dropFirst(hashes).first == " " else { return nil }
        return (hashes, String(t.dropFirst(hashes + 1)).trimmingCharacters(in: CharacterSet(charactersIn: " #")))
    }

    private static func isRule(_ t: String) -> Bool {
        let s = t.replacingOccurrences(of: " ", with: "")
        return s.count >= 3 && (Set(s) == ["-"] || Set(s) == ["*"] || Set(s) == ["_"])
    }

    private static func isTableSeparator(_ line: String) -> Bool {
        let t = line.trimmingCharacters(in: .whitespaces)
        return t.hasPrefix("|") && t.contains("-") && t.allSatisfy { "|-: ".contains($0) }
    }

    private static func cells(_ t: String) -> [String] {
        var s = t
        if s.hasPrefix("|") { s.removeFirst() }
        if s.hasSuffix("|") { s.removeLast() }
        return s.components(separatedBy: "|").map { $0.trimmingCharacters(in: .whitespaces) }
    }

    private static func isOrdered(_ it: MDItem) -> Bool { it.marker.first?.isNumber == true }

    static func listItem(_ line: String) -> MDItem? {
        let indent = line.prefix { $0 == " " || $0 == "\t" }.reduce(0) { $0 + ($1 == "\t" ? 4 : 1) }
        let t = line.trimmingCharacters(in: .whitespaces)
        for b in ["- ", "* ", "+ "] where t.hasPrefix(b) {
            var text = String(t.dropFirst(2))
            var marker = "•"
            if text.hasPrefix("[ ] ") { marker = "☐"; text = String(text.dropFirst(4)) }
            else if text.hasPrefix("[x] ") || text.hasPrefix("[X] ") { marker = "☑"; text = String(text.dropFirst(4)) }
            return MDItem(marker: marker, text: text, depth: indent / 2)
        }
        let digits = t.prefix { $0.isNumber }
        if !digits.isEmpty, digits.count <= 3 {
            let rest = t.dropFirst(digits.count)
            if rest.hasPrefix(". ") || rest.hasPrefix(") ") {
                return MDItem(marker: digits + ".", text: String(rest.dropFirst(2)), depth: indent / 2)
            }
        }
        return nil
    }
}
