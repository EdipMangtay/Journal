import Foundation

enum CSVError: LocalizedError {
    case invalid(String)
    var errorDescription: String? { if case let .invalid(message) = self { return message }; return nil }
}
enum CSVCodec {
    static let columns = ["id", "date", "instrument", "direction", "session", "setup", "gross_pnl", "fees", "net_pnl", "r_multiple", "risk_dollars", "grade", "follows_plan", "broken_rules", "classification", "notes", "record_json"]
    static func export(_ trades: [TradeRecord]) throws -> String {
        let encoder = JSONEncoder(); encoder.dateEncodingStrategy = .millisecondsSince1970; encoder.outputFormatting = [.sortedKeys]
        let iso = ISO8601DateFormatter()
        let rows = try trades.map { t -> [String] in
            [t.id.uuidString, iso.string(from: t.date), t.instrument, t.direction, t.session, t.setupName, String(t.grossPnL), String(t.fees), String(t.netPnL), t.rMultiple.map(String.init(describing:)) ?? "", t.riskDollars.map(String.init(describing:)) ?? "", t.grade, String(t.followsPlan), t.brokenRules.joined(separator: " | "), t.classification.rawValue, t.notes.thesis, String(decoding: try encoder.encode(t), as: UTF8.self)]
        }
        let textColumns = Set([2, 3, 4, 5, 11, 12, 13, 14, 15])
        let safeRows = rows.map { row in row.enumerated().map { index, value in
            textColumns.contains(index) && ["=", "+", "-", "@", "\t", "\r"].contains(where: { value.hasPrefix($0) }) ? "'" + value : value
        } }
        return ([columns] + safeRows).map { $0.map(escape).joined(separator: ",") }.joined(separator: "\r\n")
    }
    static func escape(_ value: String) -> String { "\"" + value.replacingOccurrences(of: "\"", with: "\"\"") + "\"" }
    static func parse(_ text: String) throws -> [[String]] {
        var rows: [[String]] = [], row: [String] = [], field = "", quoted = false
        let chars = Array(text); var i = 0
        while i < chars.count {
            let c = chars[i]
            if c == "\"" {
                if quoted && i + 1 < chars.count && chars[i + 1] == "\"" { field.append("\""); i += 1 }
                else { quoted.toggle() }
            } else if c == "," && !quoted { row.append(field); field = "" }
            else if (c == "\n" || c == "\r\n" || c == "\r") && !quoted {
                row.append(field); if row.contains(where: { !$0.isEmpty }) { rows.append(row) }; row = []; field = ""
                if c == "\r" && i + 1 < chars.count && chars[i + 1] == "\n" { i += 1 }
            } else { field.append(c) }
            i += 1
        }
        guard !quoted else { throw CSVError.invalid("Unclosed quote in CSV.") }
        if !field.isEmpty || !row.isEmpty { row.append(field); rows.append(row) }
        return rows
    }
    static func decode(_ text: String) throws -> [TradeRecord] {
        let rows = try parse(text)
        guard let header = rows.first else { throw CSVError.invalid("CSV is empty.") }
        let names = header.map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased().replacingOccurrences(of: "\u{feff}", with: "") }
        guard Set(names).count == names.count else { throw CSVError.invalid("Duplicate CSV columns.") }
        let iso = ISO8601DateFormatter(), decoder = JSONDecoder(); decoder.dateDecodingStrategy = .millisecondsSince1970
        return try rows.dropFirst().enumerated().map { index, row in
            guard row.count == names.count else { throw CSVError.invalid("Row \(index + 2) has the wrong number of columns.") }
            let d = Dictionary(uniqueKeysWithValues: zip(names, row))
            if let json = d["record_json"], !json.isEmpty { return try decoder.decode(TradeRecord.self, from: Data(json.utf8)) }
            guard let symbol = d["instrument"], let dateText = d["date"], let date = iso.date(from: dateText), let pnlText = d["gross_pnl"], let pnl = Double(pnlText) else { throw CSVError.invalid("Row \(index + 2) requires instrument, ISO-8601 date and gross_pnl.") }
            var t = TradeRecord(); t.instrument = symbol; t.date = date; t.grossPnL = pnl
            if let idText = d["id"], !idText.isEmpty { guard let id = UUID(uuidString: idText) else { throw CSVError.invalid("Invalid trade ID on row \(index + 2).") }; t.id = id }
            for key in ["fees", "r_multiple", "risk_dollars"] { if let value = d[key], !value.isEmpty, Double(value) == nil { throw CSVError.invalid("Invalid \(key) on row \(index + 2).") } }
            t.fees = Double(d["fees"] ?? "") ?? 0; t.rMultiple = Double(d["r_multiple"] ?? ""); t.riskDollars = Double(d["risk_dollars"] ?? "")
            t.direction = d["direction"] ?? "Long"; t.session = d["session"] ?? "NY AM"; t.setupName = d["setup"] ?? "Unassigned"; t.grade = d["grade"] ?? "B"
            t.followsPlan = d["follows_plan"]?.lowercased() != "false"
            t.brokenRules = (d["broken_rules"] ?? "").components(separatedBy: " | ").filter { !$0.isEmpty }; t.notes.thesis = d["notes"] ?? ""
            return t
        }
    }
}
