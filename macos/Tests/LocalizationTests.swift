import XCTest
#if SWIFT_PACKAGE
@testable import LiquidityEdgeCore
#else
@testable import LiquidityEdge
#endif

final class LocalizationTests: XCTestCase {
    func testTurkishLabelsAndSpecificDynamicMessages() {
        XCTAssertEqual(L10n.text("Dashboard"), "Genel Bakış")
        XCTAssertEqual(L10n.text("RULE COMPLIANCE"), "KURALLARA UYUM")
        XCTAssertEqual(L10n.text("16 wins / 28 trades"), "28 işlemde 16 kazanç")
        XCTAssertEqual(L10n.text("22 of 28 trades respected your plan. Review the exceptions."), "28 işlemin 22 tanesi planına uygun. İstisnaları incele.")
    }
    func testTurkishSearchAndCanonicalBackupValues() throws {
        var record = TradeRecord()
        record.instrument = "XAUUSD"; record.session = "London"; record.grossPnL = 100
        record.followsPlan = false; record.brokenRules = ["Early entry"]
        record.notes.thesis = "Long"; record.notes.lesson = "Türkçe not: ıİğĞüÜşŞöÖçÇ"
        for query in ["KURALSIZ KAZANÇ", "kuralsiz kazanc", "altın Londra", "erken giriş", "invalid winner"] { XCTAssertTrue(TradeSearch.matches(record, query: query), query) }
        for query in ["kurallı kazanç", "kuralli", "kuralsız zarar", "valid winner"] { XCTAssertFalse(TradeSearch.matches(record, query: query), query) }
        let restored = try JSONDecoder().decode(TradeRecord.self, from: JSONEncoder().encode(record))
        XCTAssertEqual(restored, record)
        XCTAssertEqual(restored.direction, "Long")
        XCTAssertEqual(restored.notes.thesis, "Long")
    }
}
