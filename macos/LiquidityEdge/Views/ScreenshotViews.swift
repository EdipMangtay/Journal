import SwiftUI
import UniformTypeIdentifiers
import AppKit

struct ScreenshotAttachmentEditor: View {
    @Binding var shots: [ScreenshotDraft]
    @State private var importing = false
    @State private var targeted = false
    @State private var category = "Entry"
    @State private var selected: ScreenshotDraft?
    @State private var error: String?
    @State private var loading = false
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack { Picker("Category", selection: $category) { ForEach(Catalog.screenshotCategories, id: \.self) { Text($0) } }.frame(width: 270); Spacer(); if loading { ProgressView().controlSize(.small) }; Button("Add images…") { importing = true } }
            VStack(spacing: 8) { Image(systemName: "photo.badge.plus").font(.title2); Text("Drop screenshots from Finder").font(.callout); Text("PNG, JPEG, HEIC, TIFF · up to 30 MB each").font(.caption).foregroundStyle(Palette.muted) }.frame(maxWidth: .infinity).padding(24).background(targeted ? Palette.mint.opacity(0.1) : Palette.raised.opacity(0.5), in: RoundedRectangle(cornerRadius: 8)).overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Palette.muted.opacity(0.3), style: StrokeStyle(dash: [5, 5]))).dropDestination(for: URL.self) { urls, _ in importURLs(urls); return !urls.isEmpty } isTargeted: { targeted = $0 }
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 180))], spacing: 14) {
                ForEach(shots) { shot in
                    VStack(alignment: .leading, spacing: 8) {
                        Button { selected = shot } label: { ScreenshotThumbnail(data: shot.thumbnailData).frame(height: 120).clipped() }.buttonStyle(.plain)
                        HStack { VStack(alignment: .leading, spacing: 3) { Text(shot.category).font(.caption); Text(shot.name).font(.system(size: 9)).foregroundStyle(Palette.muted).lineLimit(1) }; Spacer(); Button { shots.removeAll { $0.id == shot.id } } label: { Image(systemName: "trash") }.buttonStyle(.borderless).help("Remove attachment") }
                    }.padding(8).background(Palette.raised, in: RoundedRectangle(cornerRadius: 8))
                }
            }
            if let error { Text(error).font(.caption).foregroundStyle(Palette.amber) }
        }.fileImporter(isPresented: $importing, allowedContentTypes: [.image], allowsMultipleSelection: true) { result in
            switch result { case .success(let urls): importURLs(urls); case .failure(let failure): error = failure.localizedDescription }
        }.sheet(item: $selected) { shot in ScreenshotViewer(initial: shot) { changed in if let index = shots.firstIndex(where: { $0.id == changed.id }) { shots[index] = changed } } }
    }
    private func importURLs(_ urls: [URL]) {
        loading = true
        let selectedCategory = category
        Task {
            let result = await Task.detached(priority: .userInitiated) { () -> ([ScreenshotDraft], [String]) in
                var imported: [ScreenshotDraft] = [], errors: [String] = []
                for url in urls { do { imported.append(try ScreenshotService.load(url, category: selectedCategory)) } catch { errors.append(error.localizedDescription) } }
                return (imported, errors)
            }.value
            shots.append(contentsOf: result.0); error = result.1.isEmpty ? nil : result.1.joined(separator: "\n"); loading = false
        }
    }
}
struct ScreenshotThumbnail: View {
    var data: Data
    var body: some View {
        Group { if let image = NSImage(data: data) { Image(nsImage: image).resizable().scaledToFit() } else { Image(systemName: "photo").font(.largeTitle).foregroundStyle(Palette.muted) } }.frame(maxWidth: .infinity).background(Palette.canvas)
    }
}
struct ScreenshotViewer: View {
    @Environment(\.dismiss) private var dismiss
    @State private var shot: ScreenshotDraft
    @State private var zoom = 1.0
    @State private var tool = "Pan"
    @State private var label = "Liquidity"
    @State private var pending: ImageAnnotation?
    let onSave: (ScreenshotDraft) -> Void
    init(initial: ScreenshotDraft, onSave: @escaping (ScreenshotDraft) -> Void) { _shot = State(initialValue: initial); self.onSave = onSave }
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(shot.name).font(.headline).lineLimit(1); Spacer()
                Picker("Category", selection: $shot.category) { ForEach(Catalog.screenshotCategories, id: \.self) { Text($0) } }.frame(width: 230)
                Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction)
                Button("Save review") { onSave(shot); dismiss() }.buttonStyle(.borderedProminent)
            }.padding(18)
            HStack {
                Picker("Tool", selection: $tool) { ForEach(["Pan", "Arrow", "Rectangle", "Text", "Liquidity marker"], id: \.self) { Text($0) } }.pickerStyle(.segmented).frame(width: 480)
                if tool == "Text" || tool == "Liquidity marker" { TextField("Label", text: $label).textFieldStyle(.roundedBorder).frame(width: 130) }
                Spacer(); Button { if !shot.annotations.isEmpty { shot.annotations.removeLast() } } label: { Image(systemName: "arrow.uturn.backward") }.disabled(shot.annotations.isEmpty).help("Undo last annotation")
                Slider(value: $zoom, in: 0.5...4).frame(width: 110); Text("\(Int(zoom * 100))%").font(.caption.monospaced()).frame(width: 45)
                Button { NSApp.keyWindow?.toggleFullScreen(nil) } label: { Image(systemName: "arrow.up.left.and.arrow.down.right") }.help("Toggle full screen")
            }.padding(.horizontal, 18).padding(.bottom, 14)
            GeometryReader { available in
                ScrollView([.horizontal, .vertical]) {
                    if let image = NSImage(data: shot.imageData) {
                        let scale = min(available.size.width / max(image.size.width, 1), available.size.height / max(image.size.height, 1))
                        let size = CGSize(width: image.size.width * scale * zoom, height: image.size.height * scale * zoom)
                        ZStack(alignment: .topLeading) {
                            Image(nsImage: image).resizable().frame(width: size.width, height: size.height)
                            AnnotationLayer(annotations: shot.annotations + (pending.map { [$0] } ?? [])).frame(width: size.width, height: size.height).allowsHitTesting(false)
                            if tool != "Pan" {
                                Color.clear.contentShape(Rectangle()).frame(width: size.width, height: size.height).gesture(DragGesture(minimumDistance: 0).onChanged { value in pending = annotation(value, size: size) }.onEnded { value in shot.annotations.append(annotation(value, size: size)); pending = nil })
                            }
                        }.frame(minWidth: available.size.width, minHeight: available.size.height)
                    }
                }
            }.background(Color.black.opacity(0.7))
            HStack { Text("\(shot.annotations.count) annotations · Drag to draw; choose Pan to scroll."); Spacer(); Text("Original image remains intact.") }.font(.caption).foregroundStyle(Palette.muted).padding(14)
        }.frame(minWidth: 1000, idealWidth: 1120, minHeight: 740, idealHeight: 820).background(Palette.panel).foregroundStyle(Palette.ink)
    }
    private func annotation(_ value: DragGesture.Value, size: CGSize) -> ImageAnnotation {
        func clamp(_ value: Double) -> Double { min(1, max(0, value)) }
        return ImageAnnotation(kind: tool, x: clamp(value.startLocation.x / size.width), y: clamp(value.startLocation.y / size.height), endX: clamp(value.location.x / size.width), endY: clamp(value.location.y / size.height), text: label)
    }
}
struct AnnotationLayer: View {
    var annotations: [ImageAnnotation]
    var body: some View {
        Canvas { context, size in
            for a in annotations {
                let start = CGPoint(x: a.x * size.width, y: a.y * size.height), end = CGPoint(x: a.endX * size.width, y: a.endY * size.height)
                var path = Path()
                if a.kind == "Rectangle" { path.addRect(CGRect(x: min(start.x, end.x), y: min(start.y, end.y), width: abs(end.x - start.x), height: abs(end.y - start.y))) }
                else if a.kind == "Arrow" {
                    path.move(to: start); path.addLine(to: end)
                    let angle = atan2(end.y - start.y, end.x - start.x)
                    for delta in [-0.5, 0.5] { path.move(to: end); path.addLine(to: CGPoint(x: end.x - 14 * cos(angle + delta), y: end.y - 14 * sin(angle + delta))) }
                } else if a.kind == "Liquidity marker" { path.move(to: start); path.addLine(to: CGPoint(x: end.x, y: start.y)) }
                context.stroke(path, with: .color(Palette.amber), lineWidth: 2)
                if a.kind == "Text" || a.kind == "Liquidity marker" { context.draw(Text(a.text).font(.system(size: 14, weight: .semibold)).foregroundColor(Palette.amber), at: CGPoint(x: start.x, y: max(12, start.y - 12)), anchor: .leading) }
            }
        }
    }
}
struct ScreenshotLibraryView: View {
    @Environment(JournalStore.self) private var store
    var openTrade: (TradeRecord) -> Void
    @State private var category = "All"
    @State private var selected: ScreenshotDraft?
    @State private var selectedTradeID: UUID?
    private var items: [(TradeRecord, TradeScreenshot)] { store.trades.flatMap { trade in (store.model(trade.id)?.screenshots ?? []).filter { category == "All" || $0.category == category }.map { (trade, $0) } } }
    var body: some View {
        ScrollView { VStack(alignment: .leading, spacing: 24) {
            HStack { PageHeader(eyebrow: "Visual memory", title: "Build your pattern library.", subtitle: "Context, entry and review images linked to real executions."); Spacer(); Picker("Category", selection: $category) { ForEach(["All"] + Catalog.screenshotCategories, id: \.self) { Text($0) } }.frame(width: 230) }
            if items.isEmpty { EmptyJournal(title: "Your visual library is empty.", subtitle: "Attach screenshots to a trade. Review them here by stage.") }
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 260))], spacing: 18) {
                ForEach(items, id: \.1.id) { trade, shot in
                    Panel {
                        Button { do { selected = try ScreenshotDraft(shot); selectedTradeID = trade.id } catch { store.report(error) } } label: { ScreenshotThumbnail(data: shot.thumbnailData).frame(height: 170) }.buttonStyle(.plain)
                        HStack { Text(trade.instrument).fontWeight(.semibold); Badge(text: shot.category); Spacer(); Text(Format.r(trade.rMultiple)).foregroundStyle(Palette.outcome(trade.netPnL)) }
                        Button("Open trade →") { openTrade(trade) }.buttonStyle(.borderless)
                    }
                }
            }
        }.pagePadding() }.sheet(item: $selected) { shot in ScreenshotViewer(initial: shot) { changed in
            guard let id = selectedTradeID, let record = store.trades.first(where: { $0.id == id }) else { return }
            do { var all = try (store.model(id)?.screenshots ?? []).map(ScreenshotDraft.init); if let index = all.firstIndex(where: { $0.id == changed.id }) { all[index] = changed }; try store.save(record, screenshots: all) } catch { store.report(error) }
        } }
    }
}
