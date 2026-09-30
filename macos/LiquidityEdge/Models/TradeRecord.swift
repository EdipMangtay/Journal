import Foundation

enum Catalog {
    static let instruments = ["NQ", "NASDAQ", "US100", "ES", "SP500", "XAUUSD", "EURUSD", "GBPUSD", "US30"]
    static let sessions = ["Asia", "London", "NY AM", "NY Lunch", "NY PM"]
    static let timeframes = ["Monthly", "Weekly", "Daily", "4H", "1H", "15M", "5M", "3M", "1M"]
    static let liquidity = ["BSL", "SSL", "ERL", "IRL", "PDH", "PDL", "PWH", "PWL", "PMH", "PML", "EQH", "EQL", "Session High", "Session Low", "FVG", "NWOG", "NDOG"]
    static let sweeps = ["BSL Sweep", "SSL Sweep", "Equal Highs", "Equal Lows", "Previous Day High", "Previous Day Low", "Previous Week High", "Previous Week Low", "Session High", "Session Low", "Internal Liquidity", "External Liquidity"]
    static let confirmations = ["CISD", "FVG", "Inverse FVG", "Order Block", "Breaker", "Market Structure Shift", "Displacement", "SMT", "SSMT", "CRT", "OTE", "Premium / Discount", "Liquidity Sweep", "Rejection", "Opening Price", "True Open"]
    static let rules = ["Entered before allowed session", "No SSMT", "No TSMO", "No liquidity sweep", "No HTF alignment", "Wrong QT quarter", "No displacement", "Poor location", "Chased entry", "Early entry", "Late entry", "Overtrading", "Revenge trade", "FOMO", "Oversized risk", "Moved stop", "Closed early", "Ignored target", "Pattern recognition override"]
    static let emotions = ["Calm", "Confident", "Focused", "Hesitant", "Fear", "FOMO", "Greed", "Revenge", "Frustrated", "Overconfident", "Impatient"]
    static let screenshotCategories = ["HTF", "Before Entry", "Entry", "During Trade", "Exit", "Post Trade Review"]
}

enum Classification: String, Codable, CaseIterable {
    case validWinner = "VALID WINNER", validLoser = "VALID LOSER", invalidWinner = "INVALID WINNER", invalidLoser = "INVALID LOSER", breakeven = "BREAKEVEN"
    var message: String {
        switch self {
        case .validWinner: return "Good process, positive outcome"
        case .validLoser: return "Good process, normal loss"
        case .invalidWinner: return "Profitable outcome, invalid execution"
        case .invalidLoser: return "Review the process before the outcome"
        case .breakeven: return "Flat outcome. Evaluate execution independently."
        }
    }
}

struct QTContext: Codable, Hashable {
    var enabled = false
    var higherQuarter = "Q1", dailyQuarter = "Q1", cycle90 = "Q1", cycle22 = "Q1"
    var phase = "Accumulation"
    var trueOpen = false, aligned = false, valid = false
}
struct MMXMContext: Codable, Hashable {
    var model = "None"
    var consolidation = false, manipulation = false, displacement = false, repricing = false, reversal = false, target = false, valid = false
}
struct PO3Context: Codable, Hashable {
    var phase = "Accumulation", manipulationDirection = "Up"
    var valid = false
}
struct SSMTContext: Codable, Hashable {
    var confirmation = "Not Required", type = "High divergence"
    var markets: [String] = []
    var valid = false
}
struct CRTContext: Codable, Hashable {
    var enabled = false, reentry = false, confirmed = false
    var timeframe = "15M", liquidityTaken = "High"
    var high: Double?, low: Double?
}
struct ProcessScores: Codable, Hashable {
    var marketRead = 5.0, entry = 5.0, compliance = 5.0, risk = 5.0, management = 5.0, psychology = 5.0, recognition = 5.0
    var overall: Double { (marketRead + entry + compliance + risk + management + psychology + recognition) / 7 * 10 }
}
struct EmotionalState: Codable, Hashable {
    var confidence = 5.0, stress = 5.0, fomo = 1.0, focus = 5.0, satisfaction = 5.0
    var takeAgain = true
    var emotions: [String] = []
}
struct TradeNotes: Codable, Hashable {
    var thesis = "", entry = "", confirmation = "", invalidation = "", correct = "", incorrect = "", differently = "", lesson = ""
}
struct TradeRecord: Codable, Identifiable, Hashable {
    var id = UUID()
    var date = Date()
    var exitDate: Date?
    var instrument = "NQ", direction = "Long", session = "NY AM"
    var setupID: UUID?
    var setupName = "Unassigned"
    var entryPrice: Double?, stopLoss: Double?, takeProfit: Double?, exitPrice: Double?, positionSize: Double?
    var riskDollars: Double?, riskPercent: Double?, grossPnL = 0.0, fees = 0.0, rMultiple: Double?
    var bias = "Neutral", contextTimeframes: [String] = [], drawOnLiquidity = "", liquidityTaken: [String] = []
    var sweepValid = false, htfAligned = false
    var qt = QTContext(), mmxm = MMXMContext(), po3 = PO3Context(), ssmt = SSMTContext(), crt = CRTContext()
    var tsmo = "Not Required", tsmoValid = false
    var entryTimeframe = "1M", confirmations: [String] = []
    var followsPlan = true, brokenRules: [String] = [], grade = "B"
    var scores = ProcessScores(), emotional = EmotionalState(), notes = TradeNotes()
    var tags: [String] = []
    var netPnL: Double { grossPnL - fees }
    var compliant: Bool { followsPlan && brokenRules.isEmpty }
    var hasSSMT: Bool { ssmt.confirmation == "Yes" && ssmt.valid }
    var hasTSMO: Bool { tsmo == "Yes" && tsmoValid }
    var hasCRT: Bool { crt.enabled && crt.confirmed }
    var hasQT: Bool { qt.enabled && qt.valid && qt.aligned }
    var hasMMXM: Bool { mmxm.model != "None" && mmxm.valid }
    var classification: Classification {
        if abs(netPnL) < 0.005 { return .breakeven }
        return netPnL > 0 ? (compliant ? .validWinner : .invalidWinner) : (compliant ? .validLoser : .invalidLoser)
    }
    var plannedRR: Double? {
        guard let entryPrice, let stopLoss, let takeProfit, abs(entryPrice - stopLoss) > 0 else { return nil }
        return abs(takeProfit - entryPrice) / abs(entryPrice - stopLoss)
    }
    var duration: TimeInterval? { exitDate.map { $0.timeIntervalSince(date) } }
    var validationError: String? {
        if instrument.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return "Enter an instrument." }
        let numbers = [entryPrice, stopLoss, takeProfit, exitPrice, positionSize, riskDollars, riskPercent, grossPnL, fees, rMultiple, crt.high, crt.low].compactMap { $0 }
        if numbers.contains(where: { !$0.isFinite }) { return "Numeric values must be finite." }
        if fees < 0 || (riskDollars ?? 0) < 0 || (riskPercent ?? 0) < 0 || (positionSize ?? 0) < 0 { return "Fees, size and risk cannot be negative." }
        if let exitDate, exitDate < date { return "Exit time must be after entry time." }
        if let high = crt.high, let low = crt.low, high < low { return "CRT range high must be above range low." }
        let scoresToCheck = [scores.marketRead, scores.entry, scores.compliance, scores.risk, scores.management, scores.psychology, scores.recognition]
        if scoresToCheck.contains(where: { !$0.isFinite || !(0...10).contains($0) }) { return "Process scores must be between 0 and 10." }
        if [emotional.confidence, emotional.stress, emotional.fomo, emotional.focus, emotional.satisfaction].contains(where: { !$0.isFinite || !(1...10).contains($0) }) { return "Emotion scores must be between 1 and 10." }
        if !["Long", "Short"].contains(direction) { return "Direction must be Long or Short." }
        if !["A+", "A", "B", "C", "D", "F"].contains(grade) { return "Choose a valid trade grade." }
        if followsPlan && !brokenRules.isEmpty { return "Clear broken rules or mark this trade as outside your plan." }
        if !followsPlan && brokenRules.isEmpty { return "Select at least one broken rule, or add a custom rule." }
        return nil
    }
}

struct JournalPreferences: Codable, Equatable {
    var accountSize = 50000.0, defaultRiskPercent = 0.5
    var currency = "USD", theme = "Dark", animations = true
    var timezone = "America/New_York"
    var sessions = Catalog.sessions
    var sessionHours = ["Asia": "20:00–00:00", "London": "02:00–05:00", "NY AM": "09:30–11:00", "NY Lunch": "11:00–13:00", "NY PM": "13:00–16:00"]
    var calendar: Calendar {
        var value = Calendar(identifier: .gregorian)
        value.timeZone = TimeZone(identifier: timezone) ?? .current
        value.firstWeekday = 2
        return value
    }
}
