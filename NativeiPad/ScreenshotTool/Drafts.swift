import UIKit
import PencilKit

struct DraftMetadata: Codable {
    let capture: Capture
    var dirty: Bool
    var submission: String?
}
struct SessionMetadata: Codable { var queue: CaptureQueue; var currentID: String? }
final class DraftStore {
    let folder: URL
    init(namespace: String, root: URL? = nil) throws {
        let base = try root ?? FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        folder = base.appendingPathComponent("Drafts/" + namespace, isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        var excluded = folder; var values = URLResourceValues(); values.isExcludedFromBackup = true; try excluded.setResourceValues(values)
    }
    func url(_ id: String, _ ext: String) -> URL { folder.appendingPathComponent(id).appendingPathExtension(ext) }
    func put(_ data: Data, at url: URL) throws { try data.write(to: url, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication]) }
    func store(_ capture: Capture, image: Data) throws { try put(image, at: url(capture.id, "png")) }
    func image(_ id: String) -> UIImage? { (try? Data(contentsOf: url(id, "png"))).flatMap(UIImage.init(data:)) }
    func write(_ draft: DraftMetadata, drawing: PKDrawing) throws {
        try put(drawing.dataRepresentation(), at: url(draft.capture.id, "drawing"))
        try put(JSONEncoder().encode(draft), at: url(draft.capture.id, "json"))
    }
    func draft(_ id: String) -> DraftMetadata? { (try? Data(contentsOf: url(id, "json"))).flatMap { try? JSONDecoder().decode(DraftMetadata.self, from: $0) } }
    func drawing(_ id: String) -> PKDrawing { (try? PKDrawing(data: Data(contentsOf: url(id, "drawing")))) ?? PKDrawing() }
    func session() -> SessionMetadata { (try? Data(contentsOf: folder.appendingPathComponent("session.json"))).flatMap { try? JSONDecoder().decode(SessionMetadata.self, from: $0) } ?? SessionMetadata(queue: CaptureQueue(), currentID: nil) }
    func session(_ value: SessionMetadata) throws { try put(JSONEncoder().encode(value), at: folder.appendingPathComponent("session.json")) }
    func pending(_ id: String) -> Data? { try? Data(contentsOf: url(id, "upload")) }
    func pending(_ data: Data, id: String) throws { try put(data, at: url(id, "upload")) }
}

enum ImageExporter {
    static func png(image: UIImage, drawing: PKDrawing, width: Int, height: Int) throws -> Data {
        guard let cg = image.cgImage, cg.width == width, cg.height == height, width > 0, height > 0, width * height <= 16000000 else { throw AppError.message("The screenshot dimensions do not match. Please open it again.") }
        let format = UIGraphicsImageRendererFormat(); format.scale = 1; format.opaque = true
        let rect = CGRect(x: 0, y: 0, width: width, height: height)
        let output = UIGraphicsImageRenderer(size: rect.size, format: format).image { context in
            UIColor.white.setFill(); context.fill(rect); image.draw(in: rect)
            drawing.image(from: rect, scale: 1).draw(in: rect)
        }
        guard let data = output.pngData(), data.count <= 40 * 1024 * 1024 else { throw AppError.message("The finished image is too large. Capture a smaller area.") }
        return data
    }
}
