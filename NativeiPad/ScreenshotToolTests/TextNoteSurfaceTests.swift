import XCTest
import SwiftUI
import PencilKit
@testable import ScreenshotToolNative

final class TextNoteSurfaceTests: XCTestCase {
    private let imageSize = CGSize(width: 1200, height: 900)

    @MainActor func testNotesStayAlignedWithSourcePixelsAcrossZoomPanAndRotationLayout() throws {
        let (controller, note) = fixture()
        layout(controller, size: CGSize(width: 1000, height: 700))
        let noteView = try noteView(in: controller, note: note)
        let sourceRect = TextNoteRenderer.rect(for: note, imageSize: imageSize)
        assertAligned(noteView, sourceRect: sourceRect, controller: controller)

        controller.scroll.setZoomScale(1.7, animated: false)
        controller.scroll.contentOffset = CGPoint(x: 180, y: 110)
        controller.view.layoutIfNeeded()
        XCTAssertEqual(controller.scroll.zoomScale, 1.7, accuracy: 0.001)
        assertAligned(noteView, sourceRect: sourceRect, controller: controller)

        // Changing the available viewport exercises the same layout path as rotation.
        layout(controller, size: CGSize(width: 700, height: 1000))
        XCTAssertEqual(controller.scroll.bounds.size, CGSize(width: 700, height: 1000))
        XCTAssertLessThan(controller.scroll.zoomScale, 1.7)
        assertAligned(noteView, sourceRect: sourceRect, controller: controller)
        controller.scroll.setZoomScale(2.2, animated: false)
        assertAligned(noteView, sourceRect: sourceRect, controller: controller)
        XCTAssertEqual(controller.canvas.drawing.strokes.count, 1, "Layout and zoom must preserve Pencil ink")
    }

    @MainActor func testNoteModeRoutesHitTestingAndAccessibilityWithoutChangingInk() throws {
        let (controller, note) = fixture()
        layout(controller, size: CGSize(width: 1000, height: 700))
        let overlay = try overlay(in: controller)
        let item = try noteView(in: controller, note: note)
        let originalInk = controller.canvas.drawing.dataRepresentation()
        let notePoint = CGPoint(x: item.frame.midX, y: item.frame.midY)

        controller.setInteraction(active: true, noteMode: false)
        XCTAssertTrue(controller.canvas.isUserInteractionEnabled)
        XCTAssertFalse(overlay.isUserInteractionEnabled)
        XCTAssertNil(overlay.hitTest(notePoint, with: nil), "Visible notes must not intercept Pencil strokes in Draw mode")
        XCTAssertTrue(item.accessibilityTraits.contains(.staticText))
        XCTAssertFalse(item.accessibilityActivate())

        var editedID: UUID?
        var placement: CGPoint?
        controller.editNote = { editedID = $0 }
        controller.newNote = { placement = $0 }
        controller.setInteraction(active: true, noteMode: true)
        XCTAssertFalse(controller.canvas.isUserInteractionEnabled)
        XCTAssertTrue(overlay.isUserInteractionEnabled)
        XCTAssertTrue(overlay.hitTest(notePoint, with: nil) === item)
        XCTAssertTrue(controller.scroll.isUserInteractionEnabled)
        XCTAssertTrue(controller.scroll.panGestureRecognizer.isEnabled)
        XCTAssertEqual(controller.scroll.panGestureRecognizer.minimumNumberOfTouches, 2)
        XCTAssertTrue(controller.scroll.pinchGestureRecognizer?.isEnabled == true)
        XCTAssertTrue(item.accessibilityActivate())
        XCTAssertEqual(editedID, note.id)
        XCTAssertEqual(Set(item.accessibilityCustomActions?.map(\.name) ?? []), Set(["Move left", "Move right", "Move up", "Move down"]))
        let add = try XCTUnwrap(overlay.accessibilityElements?.compactMap { $0 as? UIAccessibilityElement }.first)
        XCTAssertEqual(add.accessibilityLabel, "Add text note at center")
        XCTAssertTrue(add.accessibilityActivate())
        XCTAssertEqual(placement, CGPoint(x: imageSize.width / 2, y: imageSize.height / 2))

        controller.setInteraction(active: false, noteMode: true)
        XCTAssertFalse(controller.view.isUserInteractionEnabled)
        XCTAssertFalse(controller.canvas.isUserInteractionEnabled)
        XCTAssertFalse(overlay.isUserInteractionEnabled)
        XCTAssertFalse(add.accessibilityActivate(), "A modal composer must block additional placement")
        XCTAssertFalse(item.accessibilityActivate())
        controller.setInteraction(active: true, noteMode: false)
        XCTAssertEqual(controller.canvas.drawing.dataRepresentation(), originalInk)
    }

    @MainActor func testEmptyScreenshotOffersAccessiblePlacementOnlyInNoteMode() throws {
        let controller = DrawingController()
        controller.configure(image: screenshot(), size: imageSize, drawing: PKDrawing(), notes: [], selection: UUID())
        layout(controller, size: CGSize(width: 1000, height: 700))
        let overlay = try overlay(in: controller)
        var placement: CGPoint?
        controller.newNote = { placement = $0 }
        controller.setInteraction(active: true, noteMode: true)
        XCTAssertEqual(overlay.accessibilityElements?.count, 1)
        let add = try XCTUnwrap(overlay.accessibilityElements?.first as? UIAccessibilityElement)
        XCTAssertTrue(add.accessibilityActivate())
        XCTAssertEqual(placement, CGPoint(x: 600, y: 450))
        controller.setInteraction(active: true, noteMode: false)
        XCTAssertTrue(overlay.accessibilityElements?.isEmpty == true)
        XCTAssertFalse(add.accessibilityActivate())
    }

    @MainActor func testInactiveSurfaceNeverTakesKeyboardFocusFromTextEditor() async throws {
        let (controller, _) = fixture()
        let container = UIViewController()
        container.loadViewIfNeeded()
        container.addChild(controller)
        container.view.addSubview(controller.view)
        controller.view.frame = CGRect(x: 0, y: 0, width: 900, height: 650)
        controller.didMove(toParent: container)
        let editor = UITextView(frame: CGRect(x: 40, y: 700, width: 700, height: 160))
        editor.text = "A-minus: clean layout, make the headline larger."
        container.view.addSubview(editor)
        let host = try SurfaceTestWindow(controller: container)
        defer { editor.resignFirstResponder(); host.close() }
        await settleUI()
        controller.setInteraction(active: true, noteMode: false)
        XCTAssertTrue(controller.canvas.becomeFirstResponder())
        XCTAssertTrue(controller.canvas.isFirstResponder)

        controller.setInteraction(active: false, noteMode: true)
        XCTAssertFalse(controller.canvas.isFirstResponder)
        XCTAssertTrue(editor.becomeFirstResponder())
        await settleUI()
        XCTAssertTrue(editor.isFirstResponder)
        // SwiftUI may update modes, layout, or appearance while a composer is open.
        controller.setInteraction(active: false, noteMode: false)
        layout(controller, size: CGSize(width: 650, height: 900))
        controller.viewDidAppear(false)
        controller.setInteraction(active: false, noteMode: true)
        await settleUI()
        XCTAssertTrue(editor.isFirstResponder, "An inactive drawing surface must leave the note editor's keyboard alone")
        XCTAssertFalse(controller.canvas.isFirstResponder)
        XCTAssertFalse(controller.canvas.isUserInteractionEnabled)
    }

    @MainActor func testSyntheticWorkspaceProducesReviewAttachmentWithTextAndPencilInk() async throws {
        // Explicit nil avoids reading pairing credentials; no client or draft store is created.
        let model = WorkspaceModel(connection: nil)
        model.showPairing = false
        let capture = Capture(id: String(repeating: "c", count: 24), title: "Synthetic design feedback", width: 1200, height: 900, modified: 1, saved: false)
        model.current = capture; model.captures = [capture]; model.queue.merge([capture])
        model.image = screenshot(); model.drawing = ink()
        model.beginNote(at: CGPoint(x: 650, y: 510), selectionID: model.selection)
        var note = try XCTUnwrap(model.noteEditor?.note)
        note.text = "A− — keep the clean layout.\nMake the headline bigger."
        note.width = 480; note.fontSize = 32
        XCTAssertTrue(model.commitNote(note))
        XCTAssertNil(model.error)

        // Keep the quote cursor and any other @AppStorage changes out of app defaults.
        let suite = "TextNoteSurfaceTests." + UUID().uuidString
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let hosting = UIHostingController(rootView: WorkspaceView(model: model).defaultAppStorage(defaults))
        let host = try SurfaceTestWindow(controller: hosting)
        defer { host.close() }
        await settleUI()
        hosting.view.setNeedsLayout(); hosting.view.layoutIfNeeded()
        await settleUI()
        XCTAssertEqual(model.notes.count, 1)
        XCTAssertEqual(model.canvas?.drawing.strokes.count, 1)
        let format = UIGraphicsImageRendererFormat(); format.scale = 1
        var rendered = false
        let image = UIGraphicsImageRenderer(size: hosting.view.bounds.size, format: format).image { _ in
            rendered = hosting.view.drawHierarchy(in: hosting.view.bounds, afterScreenUpdates: true)
        }
        XCTAssertTrue(rendered, "The attachment should capture the actual synthetic workspace hierarchy")
        XCTAssertGreaterThan(image.size.width, 500)
        let attachment = XCTAttachment(data: try XCTUnwrap(image.pngData()), uniformTypeIdentifier: "public.png")
        attachment.name = "Synthetic workspace — text note and Pencil ink"
        attachment.lifetime = .keepAlways
        add(attachment)

        model.editNote(id: note.id, selectionID: model.selection)
        try? await Task.sleep(for: .milliseconds(450))
        XCTAssertNotNil(hosting.presentedViewController, "Tapping a note must present the text editor")
        XCTAssertFalse(model.canvas?.isFirstResponder ?? true, "The Pencil canvas must release keyboard focus for dictation")
        let composer = XCTAttachment(data: try XCTUnwrap(host.snapshot().pngData()), uniformTypeIdentifier: "public.png")
        composer.name = "Synthetic text and voice composer"
        composer.lifetime = .keepAlways
        add(composer)
        model.cancelNoteEditing()
    }

    @MainActor private func fixture() -> (DrawingController, TextNote) {
        let note = TextNote(text: "A− — clean layout. Make this heading bigger.", x: 650, y: 510, width: 480, fontSize: 32)
        let controller = DrawingController()
        controller.configure(image: screenshot(), size: imageSize, drawing: ink(), notes: [note], selection: UUID())
        return (controller, note)
    }
    @MainActor private func layout(_ controller: DrawingController, size: CGSize) {
        controller.view.frame = CGRect(origin: .zero, size: size)
        controller.view.setNeedsLayout(); controller.view.layoutIfNeeded()
    }
    @MainActor private func overlay(in controller: DrawingController) throws -> UIView {
        let result = try XCTUnwrap(controller.sheet.subviews.last)
        XCTAssertFalse(result === controller.canvas)
        return result
    }
    @MainActor private func noteView(in controller: DrawingController, note: TextNote) throws -> UIView {
        try XCTUnwrap(try overlay(in: controller).subviews.first { $0.accessibilityLabel == "Text note: \(note.text)" })
    }
    @MainActor private func assertAligned(_ item: UIView, sourceRect: CGRect, controller: DrawingController, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertEqual(item.frame.minX, sourceRect.minX, accuracy: 0.001, file: file, line: line)
        XCTAssertEqual(item.frame.minY, sourceRect.minY, accuracy: 0.001, file: file, line: line)
        XCTAssertEqual(item.frame.width, sourceRect.width, accuracy: 0.001, file: file, line: line)
        XCTAssertEqual(item.frame.height, sourceRect.height, accuracy: 0.001, file: file, line: line)
        XCTAssertTrue(item.superview?.superview === controller.sheet, file: file, line: line)
        let actual = item.convert(item.bounds, to: controller.view)
        let expected = controller.background.convert(sourceRect, to: controller.view)
        XCTAssertEqual(actual.minX, expected.minX, accuracy: 0.01, file: file, line: line)
        XCTAssertEqual(actual.minY, expected.minY, accuracy: 0.01, file: file, line: line)
        XCTAssertEqual(actual.width, sourceRect.width * controller.scroll.zoomScale, accuracy: 0.01, file: file, line: line)
        XCTAssertEqual(actual.height, sourceRect.height * controller.scroll.zoomScale, accuracy: 0.01, file: file, line: line)
    }
    @MainActor private func settleUI() async {
        await Task.yield()
        try? await Task.sleep(for: .milliseconds(80))
    }
    @MainActor private func screenshot() -> UIImage {
        let format = UIGraphicsImageRendererFormat(); format.scale = 1
        return UIGraphicsImageRenderer(size: imageSize, format: format).image { context in
            UIColor(red: 0.98, green: 0.97, blue: 0.94, alpha: 1).setFill(); context.fill(CGRect(origin: .zero, size: imageSize))
            ("A place for good ideas." as NSString).draw(at: CGPoint(x: 70, y: 85), withAttributes: [.font: UIFont.systemFont(ofSize: 48, weight: .semibold), .foregroundColor: UIColor.darkGray])
            ("Synthetic screenshot · no personal content" as NSString).draw(at: CGPoint(x: 72, y: 155), withAttributes: [.font: UIFont.systemFont(ofSize: 24), .foregroundColor: UIColor.gray])
            let colors: [UIColor] = [.systemGreen, .systemOrange, .systemBlue]
            for (index, color) in colors.enumerated() {
                let rect = CGRect(x: 70 + index * 360, y: 255, width: 330, height: 220)
                color.withAlphaComponent(0.16).setFill(); UIBezierPath(roundedRect: rect, cornerRadius: 22).fill()
                ("Example \(index + 1)" as NSString).draw(at: CGPoint(x: rect.minX + 25, y: rect.minY + 35), withAttributes: [.font: UIFont.systemFont(ofSize: 28, weight: .medium), .foregroundColor: color])
            }
        }
    }
    @MainActor private func ink() -> PKDrawing {
        let locations = [CGPoint(x: 65, y: 145), CGPoint(x: 230, y: 150), CGPoint(x: 425, y: 142), CGPoint(x: 610, y: 148)]
        let points = locations.enumerated().map { index, point in
            PKStrokePoint(location: point, timeOffset: Double(index) * 0.1, size: CGSize(width: 7, height: 7), opacity: 1, force: 1, azimuth: 0, altitude: .pi / 2)
        }
        return PKDrawing(strokes: [PKStroke(ink: PKInk(.pen, color: .systemRed), path: PKStrokePath(controlPoints: points, creationDate: Date(timeIntervalSince1970: 0)))])
    }
}

@MainActor private final class SurfaceTestWindow {
    private let window: UIWindow
    private weak var previousKeyWindow: UIWindow?
    init(controller: UIViewController) throws {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        guard let scene = scenes.first(where: { $0.activationState == .foregroundActive }) ?? scenes.first else {
            throw XCTSkip("This UIKit focus/snapshot test requires the simulator app's window scene")
        }
        previousKeyWindow = scene.windows.first(where: \.isKeyWindow)
        window = UIWindow(windowScene: scene)
        window.frame = CGRect(x: 0, y: 0, width: 1024, height: 1366)
        window.rootViewController = controller
        window.makeKeyAndVisible()
        window.layoutIfNeeded()
    }
    func close() {
        window.endEditing(true)
        window.isHidden = true
        window.rootViewController = nil
        previousKeyWindow?.makeKey()
    }
    func snapshot() -> UIImage {
        let format = UIGraphicsImageRendererFormat(); format.scale = 1
        return UIGraphicsImageRenderer(size: window.bounds.size, format: format).image { _ in
            window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
        }
    }
}
