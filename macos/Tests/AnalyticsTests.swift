import XCTest
#if SWIFT_PACKAGE
@testable import LiquidityEdgeCore
#else
@testable import LiquidityEdge
#endif

final class AnalyticsTests: XCTestCase {
    func trade(_ pnl: Double, r: Double? = nil, day: Int = 0, valid: Bool = true) -> TradeRecord {
        var t = TradeRecord(); t.grossPnL = pnl; t.rMultiple = r; t.date = Date(timeIntervalSince1970: Double(day) * 86400); t.followsPlan = valid; t.brokenRules = valid ? [] : ["Early entry"]; return t
    }
    func testNetMetricsAndDrawdownFromStartingZero() {
        var feeTrade = trade(205, r: 2, day: 1); feeTrade.fees = 5
        let data = [trade(-100, r: -1), feeTrade, trade(-50, r: -0.5, day: 2), trade(0, r: 0, day: 3)]
        let p = AnalyticsEngine.performance(data)
        XCTAssertEqual(p.netPnL, 50); XCTAssertEqual(p.totalR, 0.5); XCTAssertEqual(p.winRate, 25); XCTAssertEqual(p.lossRate, 50)
        XCTAssertEqual(p.profitFactor!, 200 / 150, accuracy: 0.00001); XCTAssertEqual(p.expectancy, 12.5); XCTAssertEqual(p.averageR!, 0.125)
        XCTAssertEqual(p.averageWinner, 200); XCTAssertEqual(p.averageLoser, -75); XCTAssertEqual(p.maxDrawdown, 100)
        XCTAssertEqual(p.recoveryFactor!, 0.5); XCTAssertEqual(p.currentLossStreak, 0)
        XCTAssertEqual(AnalyticsEngine.curve(data).last!.equity, 50)
    }
    func testEmptyAllWinsAllLossesMissingR() {
        XCTAssertNil(AnalyticsEngine.performance([]).averageR)
        XCTAssertEqual(AnalyticsEngine.performance([]).count, 0)
        let winners = AnalyticsEngine.performance([trade(10, r: 1), trade(20)])
        XCTAssertNil(winners.profitFactor); XCTAssertEqual(winners.rCount, 1); XCTAssertEqual(winners.averageR, 1)
        let losers = AnalyticsEngine.performance([trade(-10), trade(-20, day: 1)])
        XCTAssertEqual(losers.profitFactor, 0); XCTAssertEqual(losers.maxDrawdown, 30); XCTAssertEqual(losers.bestTrade, -10)
    }
    func testClassificationRespectsProcessAndFees() {
        XCTAssertEqual(trade(100, valid: false).classification, .invalidWinner)
        XCTAssertEqual(trade(-100).classification, .validLoser)
        XCTAssertEqual(trade(0, valid: false).classification, .breakeven)
        var t = trade(2); t.fees = 5; XCTAssertEqual(t.classification, .validLoser)
        t = trade(100); t.brokenRules = ["No SSMT"]; XCTAssertFalse(t.compliant); XCTAssertEqual(t.classification, .invalidWinner)
        XCTAssertNotNil(t.validationError)
    }
    func testStreaksSortByDateAndResetOnBreakeven() {
        let data = [trade(-1, day: 5), trade(10, day: 1), trade(10, day: 2), trade(0, day: 3), trade(-1, day: 4)]
        let p = AnalyticsEngine.performance(data)
        XCTAssertEqual(p.longestWinStreak, 2); XCTAssertEqual(p.currentLossStreak, 2); XCTAssertEqual(p.currentWinStreak, 0)
    }
    func testConfirmationAndCombinationCohorts() {
        var a = trade(100, r: 1); a.qt.enabled = true; a.qt.valid = true; a.qt.aligned = true; a.ssmt.confirmation = "Yes"; a.ssmt.valid = true; a.crt.enabled = true; a.crt.confirmed = true
        var b = trade(-100, r: -1, day: 1); b.crt.enabled = true; b.crt.confirmed = true
        let edges = AnalyticsEngine.edgeMatrix([a, b])
        XCTAssertEqual(edges.first { $0.name == "QT + SSMT + CRT" }?.performance.count, 1)
        XCTAssertEqual(edges.first { $0.name == "CRT Only" }?.performance.count, 1)
        XCTAssertEqual(edges.first?.sampleLabel, "LOW SAMPLE SIZE")
        let comparison = AnalyticsEngine.comparisons([a, b]).first { $0.title == "CRT × SSMT" }!
        XCTAssertEqual(comparison.left.performance.count, 1); XCTAssertEqual(comparison.right.performance.count, 1)
        a.ssmt.valid = false; XCTAssertFalse(a.hasSSMT)
    }
    func testSearchQueriesDoNotConfuseInvalidWithValid() {
        var t = trade(100, valid: false); t.instrument = "XAUUSD"; t.session = "London"; t.qt.enabled = true; t.qt.dailyQuarter = "Q3"
        XCTAssertTrue(TradeSearch.matches(t, query: "Gold London")); XCTAssertTrue(TradeSearch.matches(t, query: "Invalid Winner"))
        XCTAssertFalse(TradeSearch.matches(t, query: "Valid Winner")); XCTAssertTrue(TradeSearch.matches(t, query: "QT Q3")); XCTAssertFalse(TradeSearch.matches(t, query: "SSMT loser"))
        t.grossPnL = -100; t.ssmt.confirmation = "Yes"; t.ssmt.valid = true; XCTAssertTrue(TradeSearch.matches(t, query: "SSMT loser"))
    }
    func testCSVQuotedMultilineAndCompleteRoundTrip() throws {
        var t = trade(140, r: 1.4); t.notes.thesis = "Sweep, then \"CISD\"\nWait for entry"; t.confirmations = ["FVG", "CISD"]; t.qt.enabled = true
        let csv = try CSVCodec.export([t]); let decoded = try CSVCodec.decode(csv)
        XCTAssertEqual(decoded, [t]); XCTAssertEqual(try CSVCodec.parse("a,b\r\n\"x,y\",\"two\nlines\"\r\n"), [["a", "b"], ["x,y", "two\nlines"]])
        XCTAssertThrowsError(try CSVCodec.parse("a,\"unclosed"))
        XCTAssertThrowsError(try CSVCodec.decode("date,date\n1,2"))
    }
    func testCSVProtectsSpreadsheetCellsAndPreservesPreciseRecord() throws {
        var t = trade(100, r: 1)
        t.instrument = "=1+1"
        t.notes.thesis = "@SUM(1,2)"
        t.date = Date(timeIntervalSince1970: 1_800_000_000.123456)
        let csv = try CSVCodec.export([t])
        let rows = try CSVCodec.parse(csv)
        XCTAssertEqual(rows[1][2], "'=1+1")
        XCTAssertEqual(rows[1][15], "'@SUM(1,2)")
        XCTAssertEqual(try CSVCodec.decode(csv), [t])
    }
    func testBreakevenThresholdIsConsistent() {
        for value in [-0.005, 0, 0.004, 0.005] {
            let t = trade(value), p = AnalyticsEngine.performance([trade(value)])
            XCTAssertEqual(p.wins == 1, t.classification == .validWinner)
            XCTAssertEqual(p.losses == 1, t.classification == .validLoser)
        }
    }
    func testDateFiltersUseConfiguredTimeZone() {
        var calendar = Calendar(identifier: .gregorian); calendar.timeZone = TimeZone(identifier: "America/New_York")!
        let date = ISO8601DateFormatter().date(from: "2026-01-02T02:00:00Z")!
        var t = trade(1); t.date = date
        let day = ISO8601DateFormatter().date(from: "2026-01-01T12:00:00Z")!
        var filter = TradeFilter(); filter.from = day; filter.to = day
        XCTAssertEqual(filter.apply([t], calendar: calendar).count, 1)
        filter.facets[.direction] = "Short"; XCTAssertEqual(filter.apply([t], calendar: calendar).count, 0)
    }
    func testCorrelationAndDuration() {
        XCTAssertEqual(AnalyticsEngine.correlation([(1, 2), (2, 4), (3, 6)])!, 1, accuracy: 0.0001)
        XCTAssertNil(AnalyticsEngine.correlation([(1, 2), (1, 3), (1, 4)]))
        var t = trade(1); t.exitDate = t.date.addingTimeInterval(3600); XCTAssertEqual(AnalyticsEngine.performance([t]).averageDuration, 3600)
        t.exitDate = t.date.addingTimeInterval(-1); XCTAssertNotNil(t.validationError)
    }
    func testThousandTradeAnalysis() {
        let data = (0..<1000).map { i -> TradeRecord in var t = trade(i % 3 == 0 ? -100 : 150, r: i % 3 == 0 ? -1 : 1.5, day: i); t.qt.enabled = true; t.qt.valid = true; t.qt.aligned = true; t.crt.enabled = true; t.crt.confirmed = true; return t }
        measure {
            XCTAssertEqual(AnalyticsEngine.performance(data).count, 1000)
            XCTAssertEqual(AnalyticsEngine.curve(data).count, 1001)
            XCTAssertFalse(AnalyticsEngine.edgeMatrix(data).isEmpty)
            _ = AnalyticsEngine.comparisons(data)
            for dimension in AnalysisDimension.allCases { _ = AnalyticsEngine.groups(data, by: dimension, calendar: .current) }
        }
    }
}
