import SwiftUI
import AppKit

enum Palette {
    static let canvas = adaptive(0x0C0F13, 0xF0F2F5)
    static let panel = adaptive(0x14191F, 0xFFFFFF)
    static let raised = adaptive(0x1B222A, 0xE6EBF0)
    static let ink = adaptive(0xEEF2F5, 0x19222C)
    static let muted = adaptive(0xA0AAB7, 0x536274)
    static let mint = adaptive(0x66D8AD, 0x087851)
    static let red = adaptive(0xF17F85, 0xBA3546)
    static let amber = adaptive(0xE9B66D, 0x906018)
    static let blue = adaptive(0x85AEF2, 0x315EAB)
    static func adaptive(_ dark: UInt32, _ light: UInt32) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            let hex = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? dark : light
            return NSColor(srgbRed: Double((hex >> 16) & 255) / 255, green: Double((hex >> 8) & 255) / 255, blue: Double(hex & 255) / 255, alpha: 1)
        })
    }
    static func outcome(_ number: Double) -> Color { number > 0 ? mint : number < 0 ? red : muted }
    static func classification(_ c: Classification) -> Color {
        switch c { case .invalidWinner, .invalidLoser: return amber; case .validWinner: return mint; case .validLoser: return blue; case .breakeven: return muted }
    }
}
enum Format {
    static func money(_ value: Double, currency: String = "USD") -> String { value.formatted(.currency(code: currency).precision(.fractionLength(2))) }
    static func number(_ value: Double, digits: Int = 2) -> String { value.formatted(.number.precision(.fractionLength(digits))) }
    static func r(_ value: Double?) -> String { value.map { ($0 > 0 ? "+" : "") + number($0) + "R" } ?? "—" }
    static func percent(_ value: Double) -> String { number(value, digits: 1) + "%" }
    static func factor(_ p: Performance) -> String { p.profitFactor.map { number($0) } ?? (p.grossProfit > 0 ? "∞" : "—") }
    static func date(_ date: Date, calendar: Calendar, time: Bool = false) -> String {
        var style = Date.FormatStyle(date: .abbreviated, time: time ? .shortened : .omitted)
        style.timeZone = calendar.timeZone
        style.calendar = calendar
        return date.formatted(style)
    }
    static func month(_ date: Date, calendar: Calendar) -> String {
        var style = Date.FormatStyle().month(.wide).year()
        style.timeZone = calendar.timeZone
        style.calendar = calendar
        return date.formatted(style)
    }
}
struct SegmentedTabs<Value: Hashable>: View {
    let options: [Value]
    @Binding var selection: Value
    var title: (Value) -> String
    var body: some View {
        HStack(spacing: 3) {
            ForEach(options, id: \.self) { value in
                Button { selection = value } label: {
                    Text(title(value)).font(.system(size: 10, weight: .medium, design: .monospaced)).foregroundStyle(selection == value ? Palette.ink : Palette.muted).padding(.horizontal, 12).padding(.vertical, 8).background(selection == value ? Palette.raised : .clear, in: RoundedRectangle(cornerRadius: 5))
                }.buttonStyle(.plain).accessibilityAddTraits(selection == value ? [.isSelected] : [])
            }
        }.padding(3).background(Palette.panel, in: RoundedRectangle(cornerRadius: 8)).overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Palette.muted.opacity(0.14)))
    }
}
struct Panel<Content: View>: View {
    var title: String? = nil
    var subtitle: String? = nil
    @ViewBuilder var content: Content
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            if let title { HStack { Text(title).font(.system(size: 11, weight: .semibold, design: .monospaced)).tracking(1.5); Spacer(); if let subtitle { Text(subtitle).font(.caption).foregroundStyle(Palette.muted) } } }
            content
        }.padding(20).frame(maxWidth: .infinity, alignment: .leading).background(Palette.panel, in: RoundedRectangle(cornerRadius: 12)).overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Palette.muted.opacity(0.13), lineWidth: 1))
    }
}
struct Badge: View {
    var text: String
    var color: Color = Palette.muted
    var body: some View { Text(text).font(.system(size: 10, weight: .semibold, design: .monospaced)).tracking(0.5).padding(.horizontal, 8).padding(.vertical, 5).foregroundStyle(color).background(color.opacity(0.1), in: RoundedRectangle(cornerRadius: 5)) }
}
struct MetricCard: View {
    var title: String, value: String, footnote: String = ""
    var color: Color = Palette.ink
    @State private var hovering = false
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title.uppercased()).font(.system(size: 10, weight: .medium, design: .monospaced)).tracking(1).foregroundStyle(Palette.muted)
            Text(value).font(.system(size: 25, weight: .medium, design: .rounded)).monospacedDigit().foregroundStyle(color).contentTransition(.numericText())
            if !footnote.isEmpty { Text(footnote).font(.caption).foregroundStyle(Palette.muted) }
        }.frame(maxWidth: .infinity, alignment: .leading).padding(18).background(hovering ? Palette.raised : Palette.panel, in: RoundedRectangle(cornerRadius: 12)).overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Palette.muted.opacity(0.13))).onHover { hovering = $0 }
    }
}
struct PageHeader: View {
    var eyebrow: String, title: String, subtitle: String
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(eyebrow.uppercased()).font(.system(size: 10, weight: .medium, design: .monospaced)).tracking(2).foregroundStyle(Palette.muted)
            Text(title).font(.system(size: 30, weight: .semibold)).tracking(-1)
            Text(subtitle).font(.system(size: 13)).foregroundStyle(Palette.muted)
        }
    }
}
struct EmptyJournal: View {
    var title = "Your edge starts with one trade."
    var subtitle = "Log the setup, record the process, and let your own data tell the story."
    var actionTitle = "New trade"
    var action: (() -> Void)? = nil
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "chart.xyaxis.line").font(.system(size: 36, weight: .ultraLight)).foregroundStyle(Palette.mint)
            Text(title).font(.title2.weight(.medium)); Text(subtitle).foregroundStyle(Palette.muted).multilineTextAlignment(.center).frame(maxWidth: 440)
            if let action { Button(actionTitle, action: action).buttonStyle(.borderedProminent).tint(Palette.mint).foregroundStyle(Palette.canvas) }
        }.padding(56).frame(maxWidth: .infinity)
    }
}
struct ChipSelection: View {
    let options: [String]
    @Binding var selection: [String]
    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), alignment: .leading)], alignment: .leading, spacing: 8) {
            ForEach(Array(Set(options)).sorted(), id: \.self) { option in
                Button { if selection.contains(option) { selection.removeAll { $0 == option } } else { selection.append(option) } } label: {
                    HStack(spacing: 6) { Image(systemName: selection.contains(option) ? "checkmark.circle.fill" : "circle"); Text(option).font(.caption); Spacer(minLength: 0) }.foregroundStyle(selection.contains(option) ? Palette.mint : Palette.muted).padding(8).background(selection.contains(option) ? Palette.mint.opacity(0.08) : Palette.raised, in: RoundedRectangle(cornerRadius: 6))
                }.buttonStyle(.plain)
            }
        }
    }
}
struct ScoreSlider: View {
    var title: String
    @Binding var value: Double
    var lower = 0.0
    var body: some View { HStack { Text(title).frame(width: 145, alignment: .leading); Slider(value: $value, in: lower...10, step: 1).tint(Palette.mint); Text(Int(value).description).monospacedDigit().frame(width: 24) } }
}
extension View {
    func pagePadding() -> some View { self.padding(28).frame(maxWidth: 1600).frame(maxWidth: .infinity, alignment: .topLeading) }
}
