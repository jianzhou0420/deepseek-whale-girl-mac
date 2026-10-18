// DeepSeek peak / off-peak ("峰谷") pricing calendar.
// Rules ported from lib/index.js of MeteorNOX/DeepSeek-Balance-Whale-Widget (MIT):
//  - Peak: weekdays 09:00–12:00 and 14:00–18:00 Beijing time; everything else is off-peak.
//  - From 2026-08-23 00:00 (Beijing) weekends are off-peak all day.
//  - From 2026-09-19 Chinese public holidays are off-peak all day.
// The holiday list must be extended every November when the next year's schedule is published.
import Foundation

enum Pricing {
    static let peakHours: [(Int, Int)] = [(9, 12), (14, 18)]
    static let weekendValleyFrom = Date(timeIntervalSince1970: 1_787_414_400)  // 2026-08-23 00:00 +08:00
    static let holidayValleyFrom = Date(timeIntervalSince1970: 1_789_747_200)  // 2026-09-19 00:00 +08:00

    static let holidays: Set<String> = [
        "2026-01-01", "2026-01-02", "2026-01-03",
        "2026-02-15", "2026-02-16", "2026-02-17", "2026-02-18", "2026-02-19",
        "2026-02-20", "2026-02-21", "2026-02-22", "2026-02-23",
        "2026-04-04", "2026-04-05", "2026-04-06",
        "2026-05-01", "2026-05-02", "2026-05-03", "2026-05-04", "2026-05-05",
        "2026-06-19", "2026-06-20", "2026-06-21",
        "2026-09-25", "2026-09-26", "2026-09-27",
        "2026-10-01", "2026-10-02", "2026-10-03", "2026-10-04", "2026-10-05", "2026-10-06", "2026-10-07",
    ]

    static func isPeak(_ date: Date = Date()) -> Bool {
        let cal = BeijingTime.calendar
        if date >= weekendValleyFrom {
            let wd = cal.component(.weekday, from: date)   // 1 = Sunday, 7 = Saturday
            if wd == 1 || wd == 7 { return false }
        }
        if date >= holidayValleyFrom && holidays.contains(BeijingTime.day(date)) { return false }
        let h = cal.component(.hour, from: date)
        return peakHours.contains { h >= $0.0 && h < $0.1 }
    }

    /// The next moment the peak/off-peak status changes.
    static func nextChange(after date: Date = Date()) -> Date {
        let now = isPeak(date)
        let cal = BeijingTime.calendar
        var c = cal.dateComponents([.year, .month, .day, .hour], from: date)
        c.minute = 0; c.second = 0
        var t = cal.date(from: c)!
        // Status can only change on whole hours; scan up to 16 days ahead (longest holiday is 9 days).
        for _ in 0..<(16 * 24) {
            t = t.addingTimeInterval(3600)
            if isPeak(t) != now { return t }
        }
        return t
    }

    /// "HH:MM:SS" until the next switch.
    static func countdown(_ date: Date = Date()) -> String {
        let remain = max(0, Int(nextChange(after: date).timeIntervalSince(date)))
        return String(format: "%02d:%02d:%02d", remain / 3600, (remain % 3600) / 60, remain % 60)
    }

    enum Style: String, Codable, CaseIterable {
        case standard = "default", liangwen, qiangqiang, count, mini
        var label: String {
            switch self {
            case .standard: return "默认"
            case .liangwen: return "梁文峰谷"
            case .qiangqiang: return "!?强强?!"
            case .count: return "倒计时"
            case .mini: return "简洁(峰/谷)"
            }
        }
    }

    static func statusText(_ style: Style, peak: Bool = isPeak()) -> String {
        switch style {
        case .liangwen: return peak ? "梁文峰" : "梁文谷"
        case .qiangqiang: return peak ? "!?峰峰?!" : "!?谷谷?!"
        case .mini: return peak ? "峰" : "谷"
        case .count: return countdown()
        case .standard: return peak ? "高峰时段" : "空闲时段"
        }
    }

    /// CNY per million tokens, [off-peak, peak].
    struct Price { var hit: [Double]; var miss: [Double]; var out: [Double] }
    static let flash = Price(hit: [0.02, 0.04], miss: [1, 2], out: [4, 8])
    static let pro = Price(hit: [0.15, 0.30], miss: [4.5, 9.0], out: [13.5, 27.0])
    static let table: [(name: String, display: String, price: Price)] = [
        ("deepseek-flash", "DeepSeek-V4.1-Flash", flash),
        ("deepseek-v4-pro", "DeepSeek-V4-Pro", pro),
    ]
}
