import { readFileSync, writeFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';

const root = new URL('../', import.meta.url);
const catalog = JSON.parse(readFileSync(new URL('windows/shared/tr.json', root), 'utf8'));
const quote = value => JSON.stringify(value).replaceAll('\\/', '/');
const swift = `// Generated from windows/shared/tr.json by scripts/generate-localization.mjs.
import Foundation

enum L10n {
    static let locale = Locale(identifier: "tr_TR")
    static let translations: [String: String] = [
${Object.entries(catalog).map(([key, value]) => `        ${quote(key)}: ${quote(value)}`).join(',\n')}
    ]
    private static let uppercase = Dictionary(translations.map { ($0.key.uppercased(), $0.value.uppercased(with: locale)) }, uniquingKeysWith: { first, _ in first })
    // Free-form user content must bypass this presentation-only lookup.
    private static let patterns: [(NSRegularExpression, String)] = translations.filter { $0.key.contains("{0}") }.sorted { $0.key.count == $1.key.count ? $0.key < $1.key : $0.key.count > $1.key.count }.compactMap { key, value in
        let parts = key.components(separatedBy: try! NSRegularExpression(pattern: "\\\\{[0-9]+\\\\}"))
        let pattern = "^" + parts.map(NSRegularExpression.escapedPattern).joined(separator: "(.+?)") + "$"
        return (try! NSRegularExpression(pattern: pattern), value)
    }
    static func text(_ key: String) -> String {
        if let exact = translations[key] ?? uppercase[key] { return exact }
        for (regex, translated) in patterns {
            guard let match = regex.firstMatch(in: key, range: NSRange(key.startIndex..., in: key)) else { continue }
            var result = translated
            for index in 1..<match.numberOfRanges {
                if let range = Range(match.range(at: index), in: key) { result = result.replacingOccurrences(of: "{\\(index - 1)}", with: String(key[range])) }
            }
            return result
        }
        return key
    }
    static func message(_ key: String, _ values: String...) -> String {
        var result = text(key)
        for (index, value) in values.enumerated() { result = result.replacingOccurrences(of: "{\\(index)}", with: value) }
        return result
    }
}
private extension String {
    func components(separatedBy regex: NSRegularExpression) -> [String] {
        var parts: [String] = [], start = startIndex
        for match in regex.matches(in: self, range: NSRange(startIndex..., in: self)) {
            guard let range = Range(match.range, in: self) else { continue }
            parts.append(String(self[start..<range.lowerBound])); start = range.upperBound
        }
        parts.append(String(self[start...])); return parts
    }
}
`;
const destination = new URL('macos/LiquidityEdge/Utilities/Localization.swift', root);
if (process.argv.includes('--check')) {
  if (readFileSync(destination, 'utf8') !== swift) throw new Error('Run node scripts/generate-localization.mjs');
} else writeFileSync(destination, swift);
console.log(`${Object.keys(catalog).length} Turkish labels: ${fileURLToPath(destination)}`);
