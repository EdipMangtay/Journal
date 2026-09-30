import Foundation

enum TradeSearch {
    static func matches(_ trade: TradeRecord, query: String) -> Bool {
        let query = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else { return true }
        var rest = query
        let special: [(String, Bool)] = [
            ("invalid winner", trade.classification == .invalidWinner), ("invalid loser", trade.classification == .invalidLoser),
            ("valid winner", trade.classification == .validWinner), ("valid loser", trade.classification == .validLoser),
            ("crt only", trade.hasCRT && !trade.hasSSMT && !trade.hasTSMO && !trade.hasQT && !trade.hasMMXM),
            ("no ssmt", !trade.hasSSMT), ("no tsmo", !trade.hasTSMO), ("ssmt", trade.hasSSMT), ("tsmo", trade.hasTSMO),
            ("crt", trade.hasCRT), ("qt", trade.qt.enabled), ("mmxm", trade.mmxm.model != "None"),
            ("loser", trade.netPnL <= -0.005), ("winner", trade.netPnL >= 0.005)
        ]
        for (phrase, match) in special {
            let tokens = rest.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
            let phraseTokens = phrase.split(separator: " ").map(String.init)
            if tokens.count >= phraseTokens.count, let start = (0...(tokens.count - phraseTokens.count)).first(where: { Array(tokens[$0..<($0 + phraseTokens.count)]) == phraseTokens }) {
                if !match { return false }
                var remaining = tokens; remaining.removeSubrange(start..<(start + phraseTokens.count)); rest = remaining.joined(separator: " ")
            }
        }
        let aliases = trade.instrument.uppercased() == "XAUUSD" ? "gold xauusd" : trade.instrument
        let haystack = ([trade.instrument, aliases, trade.direction, trade.session, trade.setupName, trade.grade, trade.qt.dailyQuarter, trade.qt.higherQuarter, trade.entryTimeframe, trade.drawOnLiquidity, trade.notes.thesis, trade.notes.lesson, trade.classification.rawValue] + trade.tags + trade.brokenRules + trade.confirmations + trade.emotional.emotions).joined(separator: " ").lowercased()
        return rest.split(whereSeparator: { $0.isWhitespace }).allSatisfy { haystack.contains($0) }
    }
}
struct TradeFilter {
    var query = ""
    var from: Date?, to: Date?
    var facets: [AnalysisDimension: String] = [:]
    func apply(_ trades: [TradeRecord], calendar: Calendar) -> [TradeRecord] {
        trades.filter { t in
            if let from, t.date < calendar.startOfDay(for: from) { return false }
            if let to, let end = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: to)), t.date >= end { return false }
            return TradeSearch.matches(t, query: query) && facets.allSatisfy { dimension, value in value.isEmpty || dimension.keys(t, calendar: calendar).contains(value) }
        }
    }
}
