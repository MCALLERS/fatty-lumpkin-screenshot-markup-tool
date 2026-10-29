import XCTest
import PencilKit
@testable import ScreenshotToolNative

final class TextNoteRenderingTests: XCTestCase {
    private let imageSize = CGSize(width: 800, height: 600)

    private func capture() -> Capture {
        Capture(id: String(repeating: "a", count: 24), title: "Example", width: 800, height: 600, modified: 1, saved: false)
    }

    @MainActor private func image() -> UIImage {
        let format = UIGraphicsImageRendererFormat(); format.scale = 1; format.opaque = true
        return UIGraphicsImageRenderer(size: imageSize, format: format).image { context in
            UIColor(red: 0.82, green: 0.91, blue: 0.98, alpha: 1).setFill()
            context.fill(CGRect(origin: .zero, size: imageSize))
        }
    }

    private func ink() -> PKDrawing {
        let points = [CGPoint(x: 30, y: 120), CGPoint(x: 750, y: 120)].enumerated().map { index, point in
            PKStrokePoint(location: point, timeOffset: Double(index) * 0.1, size: CGSize(width: 18, height: 18), opacity: 1, force: 1, azimuth: 0, altitude: .pi / 2)
        }
        return PKDrawing(strokes: [PKStroke(ink: PKInk(.pen, color: .red), path: PKStrokePath(controlPoints: points, creationDate: Date(timeIntervalSince1970: 0)))])
    }

    private func pixel(_ image: CGImage, x: Int, y: Int) throws -> [UInt8] {
        let crop = try XCTUnwrap(image.cropping(to: CGRect(x: x, y: y, width: 1, height: 1)))
        var bytes = [UInt8](repeating: 0, count: 4)
        try bytes.withUnsafeMutableBytes { buffer in
            let context = try XCTUnwrap(CGContext(data: buffer.baseAddress, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
            context.draw(crop, in: CGRect(x: 0, y: 0, width: 1, height: 1))
        }
        return bytes
    }

    func testLegacyDraftDecodesWithoutTextNotesAndKeepsRetryIdentity() throws {
        let encodedCapture = try JSONSerialization.jsonObject(with: JSONEncoder().encode(capture()))
        let data = try JSONSerialization.data(withJSONObject: ["capture": encodedCapture, "dirty": true, "submission": "existing-retry"])
        let metadata = try JSONDecoder().decode(DraftMetadata.self, from: data)
        XCTAssertTrue(metadata.notes.isEmpty)
        XCTAssertTrue(metadata.dirty)
        XCTAssertEqual(metadata.submission, "existing-retry")
        XCTAssertEqual(metadata.capture, capture())
        XCTAssertTrue(DraftMetadata(capture: capture(), dirty: false).notes.isEmpty)
    }

    @MainActor func testTextNotesAndInkReopenWithoutChangingOriginalAndDiscardTogether() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = try DraftStore(namespace: "text-note-tests", root: root)
        let original = try XCTUnwrap(image().pngData())
        let note = TextNote(text: "B+ — keep the layout; simplify the colors.", x: 80, y: 240, width: 380, fontSize: 24)
        try store.store(capture(), image: original)
        try store.write(DraftMetadata(capture: capture(), dirty: true, submission: "note-retry", notes: [note]), drawing: ink())
        let reopened = try DraftStore(namespace: "text-note-tests", root: root)
        XCTAssertEqual(reopened.draft(capture().id)?.notes, [note])
        XCTAssertEqual(reopened.draft(capture().id)?.submission, "note-retry")
        XCTAssertEqual(reopened.drawing(capture().id).strokes.count, 1)
        XCTAssertEqual(reopened.imageData(capture().id), original)
        XCTAssertTrue(reopened.unfinishedIDs().contains(capture().id))
        try reopened.discardDrawing(capture())
        XCTAssertEqual(reopened.draft(capture().id)?.notes, [])
        XCTAssertTrue(reopened.drawing(capture().id).strokes.isEmpty)
        XCTAssertEqual(reopened.imageData(capture().id), original, "Discarding annotations must retain the source screenshot")
    }

    @MainActor func testExportPlacesNoteAboveInkAtSourceCoordinatesAndRetainsDimensions() throws {
        let source = image(), original = try XCTUnwrap(source.pngData())
        let note = TextNote(text: "A− / keep this spacing", x: 100, y: 80, width: 300, fontSize: 24)
        XCTAssertTrue(TextNoteRenderer.fits(note, imageSize: imageSize))
        let bytes = try ImageExporter.png(image: source, drawing: ink(), width: 800, height: 600, notes: [note])
        let exported = try XCTUnwrap(UIImage(data: bytes)?.cgImage)
        XCTAssertEqual(exported.width, 800); XCTAssertEqual(exported.height, 600)
        XCTAssertEqual(source.pngData(), original)
        let outside = try pixel(exported, x: 60, y: 120)
        XCTAssertGreaterThan(outside[0], 220); XCTAssertLessThan(outside[1], 70)
        let card = try pixel(exported, x: 390, y: 120)
        XCTAssertGreaterThan(card[1], 200, "The opaque note must cover ink beneath its card")
        let untouched = try pixel(exported, x: 700, y: 500)
        XCTAssertEqual(untouched, try pixel(try XCTUnwrap(source.cgImage), x: 700, y: 500))
        let bounds = TextNoteRenderer.rect(for: note, imageSize: imageSize)
        var darkTextPixels = 0
        for y in stride(from: Int(bounds.minY + 10), to: Int(bounds.maxY - 5), by: 3) {
            for x in stride(from: Int(bounds.minX + 15), to: Int(bounds.maxX - 15), by: 3) {
                let sample = try pixel(exported, x: x, y: y)
                if sample[0] < 100 && sample[1] < 100 && sample[2] < 100 { darkTextPixels += 1 }
            }
        }
        XCTAssertGreaterThan(darkTextPixels, 10, "Export must contain the editable note's actual text")
    }

    @MainActor func testInvalidGeometryIsExplicitlyNormalizedForEditingButRejectedByExport() throws {
        let malformed = TextNote(text: "Keep this", x: .nan, y: .infinity, width: -40, fontSize: -.infinity)
        XCTAssertFalse(TextNoteRenderer.fits(malformed, imageSize: imageSize))
        let repaired = TextNoteRenderer.normalized(malformed, imageSize: imageSize)
        XCTAssertEqual(repaired.id, malformed.id); XCTAssertEqual(repaired.text, malformed.text)
        XCTAssertTrue([repaired.x, repaired.y, repaired.width, repaired.fontSize].allSatisfy(\.isFinite))
        XCTAssertTrue(TextNoteRenderer.fits(repaired, imageSize: imageSize))
        XCTAssertTrue(CGRect(origin: .zero, size: imageSize).contains(TextNoteRenderer.rect(for: repaired, imageSize: imageSize)))
        XCTAssertThrowsError(try ImageExporter.png(image: image(), drawing: PKDrawing(), width: 800, height: 600, notes: [malformed]))
        let edge = TextNoteRenderer.normalized(TextNote(text: "Keep", x: 790, y: 599, width: 6000, fontSize: 600), imageSize: imageSize)
        XCTAssertTrue(TextNoteRenderer.fits(edge, imageSize: imageSize))
        XCTAssertFalse(TextNoteRenderer.fits(repaired, imageSize: CGSize(width: CGFloat.nan, height: 600)))
    }

    @MainActor func testOverflowAndCharacterLimitPreventExportInsteadOfDroppingText() throws {
        let source = image(), original = try XCTUnwrap(source.pngData())
        let tall = TextNote(text: Array(repeating: "Keep this line", count: 35).joined(separator: "\n"), x: 0, y: 0, width: 300, fontSize: 24)
        XCTAssertLessThan(tall.text.count, 1000)
        XCTAssertFalse(TextNoteRenderer.fits(tall, imageSize: imageSize))
        XCTAssertGreaterThan(TextNoteRenderer.rect(for: tall, imageSize: imageSize).height, imageSize.height)
        XCTAssertThrowsError(try ImageExporter.png(image: source, drawing: ink(), width: 800, height: 600, notes: [tall]))
        let tooLong = TextNote(text: String(repeating: "a", count: 1001), x: 0, y: 0, width: 780, fontSize: 12)
        XCTAssertFalse(TextNoteRenderer.fits(tooLong, imageSize: imageSize))
        XCTAssertThrowsError(try ImageExporter.png(image: source, drawing: PKDrawing(), width: 800, height: 600, notes: [tooLong]))
        XCTAssertEqual(tall.text.components(separatedBy: "\n").count, 35)
        XCTAssertEqual(source.pngData(), original)
    }

    @MainActor func testNewNoteUsesSourceScaleAndKeepsAnEdgeTapInsideTheImage() {
        let note = TextNote.new(at: CGPoint(x: 795, y: 595), imageSize: imageSize)
        XCTAssertTrue(TextNoteRenderer.fits(note, imageSize: imageSize))
        XCTAssertTrue(CGRect(origin: .zero, size: imageSize).contains(TextNoteRenderer.rect(for: note, imageSize: imageSize)))
        XCTAssertGreaterThan(note.fontSize, 15)
        XCTAssertGreaterThan(note.width, 250)
        XCTAssertNotEqual(note.id, TextNote.new(at: .zero, imageSize: imageSize).id)
    }
}
