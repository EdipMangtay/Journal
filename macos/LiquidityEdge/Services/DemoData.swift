import Foundation

enum DemoData {
    @MainActor static func populate(_ store: JournalStore) throws {
        let names = ["QT + SSMT + CRT", "QT + MMXM + SSMT", "CRT Re-entry", "NY Liquidity Reversal"]
        try store.commit {
            for name in names {
                let setup = Setup(name: name, summary: "Liquidity-led execution with a defined invalidation.")
                let playbook = Playbook(); playbook.conditions = "HTF draw on liquidity\nCorrect QT quarter\nConfirmed divergence\nLiquidity sweep\nDisplacement before execution"
                playbook.entryRules = "Wait for M1 CISD after the sweep. Enter on the FVG retracement."
                playbook.invalidationRules = "No displacement, conflicting HTF bias or a broken manipulation extreme."
                playbook.targetRules = "Opposing liquidity; respect the predefined objective."
                playbook.riskRules = "0.5% fixed account risk. Two attempts per session."
                store.context.insert(setup); store.context.insert(playbook); setup.playbook = playbook
            }
        }
        let results = [2.6, -1, 1.8, -1, 3.2, 0, 2.1, -1, 1.4, 2.7, -1, -1, 3.1, 1.2, -0.6, 2.4, -1, 1.7, 2.2, -1, 0.8, 2.9, -1, 1.6, -0.8, 2.3, -1, 2.6]
        let calendar = store.preferences.calendar
        try store.commit {
            for i in results.indices {
                var t = TradeRecord()
                let day = calendar.date(byAdding: .day, value: -(results.count - i) / 2, to: Date())!
                t.date = calendar.date(bySettingHour: i % 4 == 0 ? 3 : 9 + i % 6, minute: i % 2 == 0 ? 30 : 0, second: 0, of: day)!
                t.exitDate = t.date.addingTimeInterval(Double(15 + i * 2) * 60)
                t.instrument = ["NQ", "ES", "XAUUSD"][i % 3]; t.session = i % 4 == 0 ? "London" : (i % 3 == 0 ? "NY PM" : "NY AM")
                t.direction = i % 3 == 0 ? "Short" : "Long"
                let setup = store.setups[i % store.setups.count]; t.setupID = setup.id; t.setupName = setup.name
                t.rMultiple = results[i]; t.riskDollars = 250; t.riskPercent = 0.5; t.fees = 4.5; t.grossPnL = results[i] * 250 + 4.5
                t.bias = t.direction == "Long" ? "Bullish" : "Bearish"; t.htfAligned = i % 7 != 0; t.drawOnLiquidity = i % 2 == 0 ? "PDH" : "PDL"
                t.liquidityTaken = [i % 2 == 0 ? "SSL Sweep" : "BSL Sweep"]; t.sweepValid = i % 5 != 0
                t.qt.enabled = i % 4 != 2; t.qt.valid = true; t.qt.aligned = i % 5 != 0; t.qt.dailyQuarter = ["Q1", "Q2", "Q3", "Q4"][i % 4]
                t.mmxm.model = i % 2 == 0 ? "Market Maker Buy Model" : "Market Maker Sell Model"; t.mmxm.valid = i % 3 == 1
                t.ssmt.confirmation = i % 5 == 0 ? "No" : "Yes"; t.ssmt.valid = i % 5 != 0; t.ssmt.markets = ["NQ", "ES"]
                t.tsmo = i % 3 == 0 ? "No" : "Yes"; t.tsmoValid = i % 3 != 0
                t.crt.enabled = i % 3 != 1; t.crt.confirmed = t.crt.enabled; t.crt.reentry = t.crt.enabled
                t.confirmations = ["CISD", "FVG", "Displacement"]; t.grade = ["A+", "B", "A", "C"][i % 4]
                t.followsPlan = i % 5 != 0; t.brokenRules = t.followsPlan ? [] : [i % 2 == 0 ? "No SSMT" : "Pattern recognition override", "Early entry"]
                t.scores.entry = Double(5 + i % 5); t.scores.compliance = t.compliant ? 10 : 3; t.scores.recognition = Double(6 + i % 4)
                t.emotional.emotions = t.compliant ? ["Calm", "Focused"] : ["FOMO", "Impatient"]
                t.notes.thesis = "Price swept external liquidity into an HTF area of interest. Waited for displacement and a defined execution trigger."
                t.notes.lesson = t.compliant ? "Repeat the process. Accept the distribution of outcomes." : "A profitable outcome does not validate an early entry."
                try store.upsert(t)
            }
        }
    }
}
