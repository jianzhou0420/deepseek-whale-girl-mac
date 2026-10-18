// Balance-observation ledger. Ported from lib/accounting.mjs of
// MeteorNOX/DeepSeek-Balance-Whale-Widget (MIT).
//
// Balance snapshots are not a transaction API: drops are recorded as observed
// spending, rises (top-ups, grants) are kept separately and never cancel spending.
// A day with unexplained rises "needs review" until the user enters a correction.
import Foundation

enum Money {
    static let scale: Double = 100_000_000

    static func units(_ value: Double) -> Int64 {
        Int64((value * scale).rounded())
    }
    static func value(_ units: Int64) -> Double { Double(units) / scale }

    /// "¥ 12.34" for CNY, "12.34 USD" otherwise.
    static func format(_ value: Double?, currency: String = "CNY", digits: Int = 2) -> String {
        guard let v = value, v.isFinite else { return "—" }
        let s = String(format: "%.\(digits)f", v)
        switch currency.uppercased() {
        case "CNY": return "¥ " + s
        case "USD": return "$ " + s
        default: return s + " " + currency.uppercased()
        }
    }
    static func symbol(_ currency: String) -> String {
        switch currency.uppercased() { case "CNY": return "¥"; case "USD": return "$"; default: return currency.uppercased() + " " }
    }
}

enum BeijingTime {
    static let tz = TimeZone(identifier: "Asia/Shanghai")!
    static var calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = tz
        return c
    }()

    /// "YYYY-MM-DD" in Beijing time.
    static func day(_ date: Date = Date()) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year!, c.month!, c.day!)
    }
    static func startOfDay(_ day: String) -> Date? {
        let p = day.split(separator: "-").compactMap { Int($0) }
        guard p.count == 3 else { return nil }
        return calendar.date(from: DateComponents(year: p[0], month: p[1], day: p[2]))
    }
    static func offset(_ day: String, _ days: Int) -> String {
        guard let d = startOfDay(day) else { return day }
        return self.day(d.addingTimeInterval(Double(days) * 86400 + 3600))
    }
}

struct Correction: Codable, Equatable {
    var at: Double
    var creditsUnits: Int64
    var otherDebitsUnits: Int64
    var amountUnits: Int64
    var debitUnits: Int64
    var creditUnits: Int64
}

struct CorrectionLogEntry: Codable {
    var at: Double
    var previous: Correction?
    var next: Correction?
}

struct DayRow: Codable {
    var day: String
    var firstAt: Double          // ms since epoch
    var lastAt: Double
    var openingUnits: Int64
    var lastUnits: Int64
    var debitUnits: Int64
    var creditUnits: Int64
    var revision: Int
    var correction: Correction?
    var correctionLog: [CorrectionLogEntry]?
}

struct Book: Codable {
    var currency: String
    var days: [String: DayRow]
    var lastAt: Double?
}

/// One observed spending entry (a balance drop between two refreshes).
struct UsageEvent: Codable, Identifiable {
    var id: String { "\(ts)-\(model)" }
    var ts: Double        // ms
    var day: String
    var model: String
    var cost: Double
    var tokens: Int
}

struct DailyArchive: Codable {
    var day: String
    var amount: Double
    var currency: String
}

struct Ledger: Codable {
    static let version = 1
    var version: Int = Ledger.version
    var active: String = ""
    var books: [String: Book] = [:]
    var events: [UsageEvent] = []
    var archive: [DailyArchive] = []
}

struct BalanceSummary {
    enum Source { case observed, corrected, needsReview, otherAccount, none }
    var day: String
    var amount: Double
    var currency: String
    var source: Source
    var label: String
    var firstObservedAt: Double?
    var lastObservedAt: Double?
    var openingBalance: Double?
    var currentBalance: Double?
    var observedDecrease: Double?
    var observedIncrease: Double?
    var needsReview: Bool
    var revision: String
    var partialDay: Bool
    var credits: Double?
    var otherDebits: Double?
    var correctedAt: Double?
    var otherBooks: [(scope: String, currency: String, amount: Double)] = []
}

enum AccountingError: LocalizedError {
    case message(String)
    var errorDescription: String? { if case .message(let m) = self { return m }; return nil }
}

extension Ledger {
    static let partialGapMs: Double = 10 * 60 * 1000
    static let eventRetentionDays = 90
    static let eventMax = 20_000
    static let archiveRetentionDays = 365

    private var currentBook: Book? { books[active] }

    private static func observedAmountUnits(_ row: DayRow) -> Int64 {
        if let c = row.correction { return c.amountUnits + row.debitUnits - c.debitUnits }
        return row.debitUnits
    }

    private func revision(of row: DayRow) -> String {
        [active, row.day, String(Int64(row.firstAt)), String(row.lastUnits),
         String(row.debitUnits), String(row.creditUnits), String(row.revision)].joined(separator: ":")
    }

    static func isPartial(day: String, firstAt: Double?, lastAt: Double?, now: Date = Date()) -> Bool {
        guard let start = BeijingTime.startOfDay(day), let first = firstAt, let last = lastAt else { return true }
        let startMs = start.timeIntervalSince1970 * 1000
        let endMs = startMs + 86_400_000
        let nowMs = now.timeIntervalSince1970 * 1000
        let before = first - startMs
        let after = nowMs >= endMs ? (endMs - last) : 0
        return before > partialGapMs || after > partialGapMs
    }

    func summary(day: String, now: Date = Date()) -> BalanceSummary? {
        guard let book = currentBook, let row = book.days[day] else { return nil }
        let correctedCredit = row.correction?.creditUnits ?? 0
        let needsReview = row.creditUnits > correctedCredit
        let source: BalanceSummary.Source = needsReview ? .needsReview : (row.correction != nil ? .corrected : .observed)
        let label = needsReview ? "已观测消费 · 待核对余额调整" : (row.correction != nil ? "已校正消费" : "已观测消费")
        var s = BalanceSummary(
            day: day, amount: Money.value(Self.observedAmountUnits(row)), currency: book.currency,
            source: source, label: label,
            firstObservedAt: row.firstAt, lastObservedAt: row.lastAt,
            openingBalance: Money.value(row.openingUnits), currentBalance: Money.value(row.lastUnits),
            observedDecrease: Money.value(row.debitUnits), observedIncrease: Money.value(row.creditUnits),
            needsReview: needsReview, revision: revision(of: row),
            partialDay: Self.isPartial(day: day, firstAt: row.firstAt, lastAt: row.lastAt, now: now),
            credits: row.correction.map { Money.value($0.creditsUnits) },
            otherDebits: row.correction.map { Money.value($0.otherDebitsUnits) },
            correctedAt: row.correction?.at)
        s.otherBooks = otherBooks(day: day)
        return s
    }

    private func otherBooks(day: String) -> [(scope: String, currency: String, amount: Double)] {
        books.compactMap { scope, book in
            guard scope != active, let row = book.days[day] else { return nil }
            return (scope, book.currency, Money.value(Self.observedAmountUnits(row)))
        }.sorted { $0.scope < $1.scope }
    }

    /// Summary for any day, falling back to books from previously used API keys.
    func daySummary(_ day: String, now: Date = Date()) -> BalanceSummary {
        if let s = summary(day: day, now: now) { return s }
        let others = books.filter { $0.key != active && $0.value.days[day] != nil }
            .sorted { ($0.value.lastAt ?? 0) > ($1.value.lastAt ?? 0) }
        if let (_, book) = others.first, let row = book.days[day] {
            return BalanceSummary(
                day: day, amount: Money.value(Self.observedAmountUnits(row)), currency: book.currency,
                source: .otherAccount, label: "已观测消费 · 历史账户",
                firstObservedAt: row.firstAt, lastObservedAt: row.lastAt,
                needsReview: row.creditUnits > (row.correction?.creditUnits ?? 0), revision: "",
                partialDay: Self.isPartial(day: day, firstAt: row.firstAt, lastAt: row.lastAt, now: now),
                otherBooks: otherBooks(day: day))
        }
        if let a = archive.first(where: { $0.day == day }) {
            return BalanceSummary(day: day, amount: a.amount, currency: a.currency, source: .observed,
                                  label: "已归档", needsReview: false, revision: "", partialDay: false)
        }
        return BalanceSummary(day: day, amount: 0, currency: currentBook?.currency ?? "CNY", source: .none,
                              label: "无观测记录", needsReview: false, revision: "", partialDay: true)
    }

    /// All days that have data in any book or in the archive, ascending.
    var allDays: [String] {
        var set = Set<String>()
        for b in books.values { for d in b.days.keys { set.insert(d) } }
        for a in archive { set.insert(a.day) }
        return set.sorted()
    }

    var bookCount: Int { books.count }

    /// Record a balance snapshot. Returns the drop observed since the previous
    /// snapshot (0 if none), so callers can log it as a usage event.
    @discardableResult
    mutating func observe(balance: Double, currency rawCurrency: String, scope: String,
                          at date: Date = Date(), model: String = "DeepSeek") -> Double {
        let at = date.timeIntervalSince1970 * 1000
        let day = BeijingTime.day(date)
        let units = Money.units(balance)
        let currency = rawCurrency.uppercased()
        let context = scope + "-" + currency
        var book = books[context] ?? Book(currency: currency, days: [:], lastAt: nil)
        // Ignore duplicate or out-of-order samples.
        if let last = book.lastAt, at <= last { return 0 }
        active = context
        var drop: Int64 = 0
        if var row = book.days[day] {
            let delta = row.lastUnits - units
            if delta > 0 { row.debitUnits += delta; drop = delta }
            if delta < 0 { row.creditUnits -= delta }
            row.lastUnits = units
            row.lastAt = at
            book.days[day] = row
        } else {
            book.days[day] = DayRow(day: day, firstAt: at, lastAt: at, openingUnits: units, lastUnits: units,
                                    debitUnits: 0, creditUnits: 0, revision: 0, correction: nil, correctionLog: nil)
        }
        book.lastAt = at
        books[context] = book
        if drop > 0 {
            events.append(UsageEvent(ts: at, day: day, model: model, cost: Money.value(drop), tokens: 0))
        }
        prune(now: date)
        return Money.value(drop)
    }

    /// Correct a day: credits = total top-ups/grants received in the observed window,
    /// otherDebits = deductions that were not API calls. action "reset" clears the correction.
    mutating func reconcile(day: String, credits: String, otherDebits: String, revision expected: String,
                            confirmed: Bool, reset: Bool = false, now: Date = Date()) throws -> BalanceSummary {
        guard var book = books[active], var row = book.days[day] else {
            throw AccountingError.message("这一天没有余额观测记录，无法校正")
        }
        guard expected == revision(of: row) else {
            throw AccountingError.message("余额或校正记录已更新，请重新打开校正窗口后核对金额")
        }
        var correction: Correction? = nil
        if !reset {
            guard confirmed else { throw AccountingError.message("请先确认已核对本统计区间的全部余额调整") }
            let c = try Self.adjustmentUnits(credits, required: true)
            let o = try Self.adjustmentUnits(otherDebits, required: false)
            let amount = row.openingUnits + c - o - row.lastUnits
            guard amount >= 0 else { throw AccountingError.message("校正后消费为负，请核对统计起点与累计到账金额") }
            correction = Correction(at: now.timeIntervalSince1970 * 1000, creditsUnits: c, otherDebitsUnits: o,
                                    amountUnits: amount, debitUnits: row.debitUnits, creditUnits: row.creditUnits)
        }
        var log = row.correctionLog ?? []
        log.append(CorrectionLogEntry(at: now.timeIntervalSince1970 * 1000, previous: row.correction, next: correction))
        if log.count > 50 { log.removeFirst(log.count - 50) }
        row.correctionLog = log
        row.correction = correction
        row.revision += 1
        book.days[day] = row
        books[active] = book
        return summary(day: day, now: now)!
    }

    static func adjustmentUnits(_ raw: String, required: Bool) throws -> Int64 {
        let s = raw.trimmingCharacters(in: .whitespaces)
        if s.isEmpty {
            if required { throw AccountingError.message("请填写本统计区间的累计到账金额，未充值请填 0") }
            return 0
        }
        let ok = s.range(of: #"^(?:0|[1-9]\d*)(?:\.\d{1,8})?$"#, options: .regularExpression) != nil
        guard ok, let v = Double(s) else { throw AccountingError.message("金额须为非负数，最多保留 8 位小数") }
        return Money.units(v)
    }

    /// Keep per-entry details for 90 days / 20k entries; keep daily totals for 365 days.
    mutating func prune(now: Date = Date()) {
        let today = BeijingTime.day(now)
        let eventCutoff = BeijingTime.offset(today, -Self.eventRetentionDays)
        events.removeAll { $0.day < eventCutoff }
        if events.count > Self.eventMax { events.removeFirst(events.count - Self.eventMax) }

        let dayCutoff = BeijingTime.offset(today, -Self.eventRetentionDays)
        let archiveCutoff = BeijingTime.offset(today, -Self.archiveRetentionDays)
        for (scope, var book) in books {
            for (day, row) in book.days where day < dayCutoff {
                if !archive.contains(where: { $0.day == day }) {
                    archive.append(DailyArchive(day: day, amount: Money.value(Self.observedAmountUnits(row)), currency: book.currency))
                }
                book.days.removeValue(forKey: day)
            }
            books[scope] = book
        }
        archive.removeAll { $0.day < archiveCutoff }
        archive.sort { $0.day < $1.day }
    }
}
