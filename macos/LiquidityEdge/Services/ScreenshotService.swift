import AppKit
import Foundation
import ImageIO
import UniformTypeIdentifiers

struct ImageAnnotation: Codable, Identifiable, Hashable {
    var id = UUID()
    var kind: String
    var x: Double, y: Double, endX: Double, endY: Double
    var text = ""
}
struct ScreenshotDraft: Codable, Identifiable, Hashable {
    var id = UUID()
    var name: String, category: String
    var imageData: Data, thumbnailData: Data
    var annotations: [ImageAnnotation] = []
    init(id: UUID = UUID(), name: String, category: String, imageData: Data, thumbnailData: Data, annotations: [ImageAnnotation] = []) {
        self.id = id; self.name = name; self.category = category; self.imageData = imageData; self.thumbnailData = thumbnailData; self.annotations = annotations
    }
    init(_ model: TradeScreenshot) throws {
        id = model.id; name = model.name; category = model.category; imageData = model.imageData; thumbnailData = model.thumbnailData
        annotations = model.annotationData.isEmpty ? [] : try JSONDecoder().decode([ImageAnnotation].self, from: model.annotationData)
    }
}
enum ScreenshotService {
    static func load(_ url: URL, category: String) throws -> ScreenshotDraft {
        let access = url.startAccessingSecurityScopedResource(); defer { if access { url.stopAccessingSecurityScopedResource() } }
        let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
        guard size <= 30_000_000 else { throw JournalError(message: "Images must be smaller than 30 MB.") }
        let data = try Data(contentsOf: url)
        guard let source = CGImageSourceCreateWithData(data as CFData, nil), let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any], let width = properties[kCGImagePropertyPixelWidth] as? Int, let height = properties[kCGImagePropertyPixelHeight] as? Int, width > 0, height > 0, Double(width) * Double(height) <= 100_000_000 else { throw JournalError(message: "Choose a supported image under 100 megapixels.") }
        let options: [CFString: Any] = [kCGImageSourceCreateThumbnailFromImageAlways: true, kCGImageSourceThumbnailMaxPixelSize: 600, kCGImageSourceCreateThumbnailWithTransform: true]
        guard let cg = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary), let thumbnail = NSBitmapImageRep(cgImage: cg).representation(using: .jpeg, properties: [.compressionFactor: 0.8]) else { throw JournalError(message: "Could not generate image preview.") }
        return ScreenshotDraft(name: url.lastPathComponent, category: category, imageData: data, thumbnailData: thumbnail)
    }
}
