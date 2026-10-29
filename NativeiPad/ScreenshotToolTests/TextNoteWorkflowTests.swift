import XCTest
import UIKit
import PencilKit
@testable import ScreenshotToolNative

final class TextNoteWorkflowTests: XCTestCase {
    @MainActor func testTextOnlyDraftSurvivesNavigationRestartAndPNGExport() async throws {
        let (model, root) = try fixture()
        defer { TextNoteTestProtocol.reply = nil; try? FileManager.default.removeItem(at: root) }
        let first = capture("a", time: 1), second = capture("b", time: 2, saved: true)
        let source = samplePNG()
        var uploaded: Data?
        TextNoteTestProtocol.reply = { request in
            switch request.url!.path {
            case "/api/library": return (200, try self.libraryData([first, second]))
            case "/api/save":
                uploaded = try self.requestBody(request)
                return try self.receipt(request)
            default: return (200, source)
            }
        }
        await model.poll()
        let note = try addNote("Move this button", to: model)
        XCTAssertTrue(model.drawing.strokes.isEmpty, "This regression must exercise a text-only draft")
        XCTAssertTrue(model.dirty)
        XCTAssertEqual(model.unfinishedDrawingCount, 1)
        let openedSecond = await model.open(second)
        XCTAssertTrue(openedSecond)
        XCTAssertTrue(model.notes.isEmpty, "Notes must belong to their screenshot")
        let reopenedFirst = await model.open(first)
        XCTAssertTrue(reopenedFirst)
        XCTAssertEqual(model.notes.map(\.id), [note.id])
        XCTAssertEqual(model.notes.first?.text, note.text)
        XCTAssertTrue(model.dirty)
        model.persist()

        let restored = try fixture(root: root).0
        XCTAssertEqual(restored.current?.id, first.id)
        XCTAssertTrue(restored.dirty)
        XCTAssertTrue(restored.drawing.strokes.isEmpty)
        XCTAssertEqual(restored.notes.map(\.id), [note.id])
        XCTAssertEqual(restored.notes.first?.text, note.text)
        await restored.finish()
        let output = try XCTUnwrap(uploaded)
        let result = try XCTUnwrap(UIImage(data: output)?.cgImage)
        XCTAssertEqual(result.width, first.width)
        XCTAssertEqual(result.height, first.height)
        XCTAssertNotEqual(try pixels(output), try pixels(source), "A text-only note must be visible in the exported PNG, not merely stored as metadata")
        XCTAssertEqual(restored.completedCaptureCount, 1)
        XCTAssertNil(restored.current)
        XCTAssertTrue(restored.notes.isEmpty)
        XCTAssertFalse(restored.dirty)
        XCTAssertEqual(restored.unfinishedDrawingCount, 0)
    }

    @MainActor func testCancelNewOrExistingNoteLeavesContentAndDirtyStateUnchanged() async throws {
        let (model, root) = try fixture()
        defer { TextNoteTestProtocol.reply = nil; try? FileManager.default.removeItem(at: root) }
        let item = capture("a", time: 1), source = samplePNG()
        TextNoteTestProtocol.reply = { request in
            request.url!.path == "/api/library" ? (200, try self.libraryData([item])) : (200, source)
        }
        await model.poll()
        model.noteMode = true
        model.beginNote(at: CGPoint(x: 4, y: 4), selectionID: model.selection)
        XCTAssertNotNil(model.noteEditor)
        XCTAssertTrue(model.notes.isEmpty)
        XCTAssertFalse(model.dirty, "Opening the composer must not create a draft")
        model.cancelNoteEditing()
        model.persist()
        XCTAssertNil(model.noteEditor)
        XCTAssertTrue(model.notes.isEmpty)
        XCTAssertFalse(model.dirty)
        XCTAssertEqual(model.unfinishedDrawingCount, 0)

        let original = try addNote("Keep this wording", to: model)
        model.editNote(id: original.id, selectionID: model.selection)
        var abandoned = try XCTUnwrap(model.noteEditor).note
        abandoned.text = "Do not save this"
        model.cancelNoteEditing()
        XCTAssertFalse(model.commitNote(abandoned), "A late composer callback after Cancel must be rejected")
        XCTAssertEqual(model.notes.first?.text, original.text)
        XCTAssertEqual(model.notes.map(\.id), [original.id])
        XCTAssertTrue(model.dirty)
        model.persist()
    }

    @MainActor func testAddEditMoveAndDeleteUseCanvasUndoAndRedoHistory() async throws {
        let (model, root) = try fixture()
        defer { TextNoteTestProtocol.reply = nil; try? FileManager.default.removeItem(at: root) }
        let item = capture("a", time: 1), source = samplePNG()
        TextNoteTestProtocol.reply = { request in
            request.url!.path == "/api/library" ? (200, try self.libraryData([item])) : (200, source)
        }
        await model.poll()
        // A dedicated canvas manager keeps event-loop undo grouping deterministic.
        let canvas = TextNoteTestCanvas()
        model.canvas = canvas
        let history = try XCTUnwrap(canvas.undoManager)
        history.groupsByEvent = false
        history.beginUndoGrouping()
        let original = try addNote("Original note", to: model)
        history.endUndoGrouping()
        XCTAssertTrue(history.canUndo)
        model.undo()
        XCTAssertTrue(model.notes.isEmpty)
        XCTAssertTrue(history.canRedo)
        model.redo()
        XCTAssertEqual(model.notes.map(\.id), [original.id])

        model.editNote(id: original.id, selectionID: model.selection)
        var revised = try XCTUnwrap(model.noteEditor).note
        revised.text = "Revised note"
        history.beginUndoGrouping()
        XCTAssertTrue(model.commitNote(revised))
        history.endUndoGrouping()
        model.undo()
        XCTAssertEqual(model.notes.first?.text, original.text)
        model.redo()
        XCTAssertEqual(model.notes.first?.text, revised.text)

        let beforeMove = try XCTUnwrap(model.notes.first)
        history.beginUndoGrouping()
        model.moveNote(id: original.id, to: CGPoint(x: 16, y: 30), selectionID: model.selection)
        history.endUndoGrouping()
        let moved = try XCTUnwrap(model.notes.first)
        XCTAssertNotEqual(CGPoint(x: moved.x, y: moved.y), CGPoint(x: beforeMove.x, y: beforeMove.y))
        model.undo()
        XCTAssertEqual(model.notes.first?.x, beforeMove.x)
        XCTAssertEqual(model.notes.first?.y, beforeMove.y)
        model.redo()
        XCTAssertEqual(model.notes.first?.x, moved.x)
        XCTAssertEqual(model.notes.first?.y, moved.y)

        model.editNote(id: original.id, selectionID: model.selection)
        history.beginUndoGrouping()
        XCTAssertTrue(model.deleteEditingNote())
        history.endUndoGrouping()
        XCTAssertNil(model.noteEditor)
        XCTAssertTrue(model.notes.isEmpty)
        model.undo()
        XCTAssertEqual(model.notes.map(\.id), [original.id])
        XCTAssertEqual(model.notes.first?.text, revised.text)
        XCTAssertEqual(model.notes.first?.x, moved.x)
        model.redo()
        XCTAssertTrue(model.notes.isEmpty)
        model.persist()
    }

    @MainActor func testComposerBlocksPollTakeoverFinishNavigationAndSessionReset() async throws {
        let (model, root) = try fixture()
        defer { TextNoteTestProtocol.reply = nil; try? FileManager.default.removeItem(at: root) }
        let first = capture("a", time: 1, saved: true), incoming = capture("b", time: 2)
        let source = samplePNG()
        var hasIncoming = false, mutations: [String] = []
        TextNoteTestProtocol.reply = { request in
            if request.httpMethod != "GET" { mutations.append(request.url!.path) }
            switch request.url!.path {
            case "/api/library": return (200, try self.libraryData(hasIncoming ? [first, incoming] : [first]))
            case "/api/save": return try self.receipt(request)
            case "/api/session/reset": return (200, try self.libraryData([], session: "session-two"))
            default: return (200, source)
            }
        }
        await model.poll()
        let opened = await model.open(first, manual: false)
        XCTAssertTrue(opened)
        model.noteMode = true
        model.beginNote(at: CGPoint(x: 4, y: 4), selectionID: model.selection)
        let editor = try XCTUnwrap(model.noteEditor)
        let selected = model.selection
        hasIncoming = true
        await model.poll()
        await model.finish()
        let navigated = await model.open(incoming)
        XCTAssertFalse(navigated)
        await model.clearQueue()
        await model.startNewSession()
        XCTAssertTrue(mutations.isEmpty, "The modal composer must prevent save/reset requests as well as changing the canvas")
        XCTAssertEqual(model.current?.id, first.id)
        XCTAssertEqual(model.selection, selected)
        XCTAssertEqual(model.noteEditor?.note.id, editor.note.id)
        XCTAssertTrue(model.notes.isEmpty)
        XCTAssertFalse(model.dirty)

        model.cancelNoteEditing()
        await model.poll()
        XCTAssertTrue(model.captures.contains(where: { $0.id == incoming.id }), "Polling must resume when the composer is dismissed")
        let openedAfterCancel = await model.open(incoming)
        XCTAssertTrue(openedAfterCancel, "Navigation must resume when the composer is dismissed")
        XCTAssertEqual(model.current?.id, incoming.id)
    }

    @MainActor func testExternalSessionChangeCannotDismissAnOpenComposer() async throws {
        let (model, root) = try fixture()
        defer { TextNoteTestProtocol.reply = nil; try? FileManager.default.removeItem(at: root) }
        let first = capture("a", time: 1), incoming = capture("b", time: 2), source = samplePNG()
        var reset = false
        TextNoteTestProtocol.reply = { request in
            if request.url!.path == "/api/library" {
                return (200, try self.libraryData(reset ? [incoming] : [first], session: reset ? "session-two" : "session-one"))
            }
            return (200, source)
        }
        await model.poll()
        model.noteMode = true
        model.beginNote(at: CGPoint(x: 4, y: 4), selectionID: model.selection)
        var note = try XCTUnwrap(model.noteEditor).note
        note.text = "Still composing"
        let selection = model.selection
        reset = true
        await model.poll()
        XCTAssertEqual(model.current?.id, first.id)
        XCTAssertEqual(model.selection, selection)
        XCTAssertEqual(model.noteEditor?.note.id, note.id)
        XCTAssertTrue(model.commitNote(note))
        await model.poll()
        XCTAssertEqual(model.current?.id, first.id, "Once committed, the note must be protected as a dirty draft across the external reset")
        XCTAssertEqual(model.notes.first?.text, note.text)
        XCTAssertTrue(model.dirty)
        model.persist()
    }

    @MainActor func testStaleSelectionCannotCreateEditMoveOrCommitOnAnotherCapture() async throws {
        let (model, root) = try fixture()
        defer { TextNoteTestProtocol.reply = nil; try? FileManager.default.removeItem(at: root) }
        let first = capture("a", time: 1), second = capture("b", time: 2, saved: true), source = samplePNG()
        TextNoteTestProtocol.reply = { request in
            request.url!.path == "/api/library" ? (200, try self.libraryData([first, second])) : (200, source)
        }
        await model.poll()
        model.noteMode = true
        let oldSelection = model.selection
        model.beginNote(at: CGPoint(x: 4, y: 4), selectionID: oldSelection)
        var stale = try XCTUnwrap(model.noteEditor).note
        stale.text = "Belongs to the old capture"
        model.cancelNoteEditing()
        let opened = await model.open(second)
        XCTAssertTrue(opened)
        XCTAssertFalse(model.commitNote(stale))
        model.beginNote(at: CGPoint(x: 4, y: 4), selectionID: oldSelection)
        XCTAssertNil(model.noteEditor)
        XCTAssertTrue(model.notes.isEmpty)
        XCTAssertFalse(model.dirty)

        let currentNote = try addNote("Current capture", to: model)
        model.editNote(id: currentNote.id, selectionID: oldSelection)
        XCTAssertNil(model.noteEditor)
        model.moveNote(id: currentNote.id, to: CGPoint(x: 40, y: 40), selectionID: oldSelection)
        XCTAssertEqual(model.notes.first?.x, currentNote.x)
        XCTAssertEqual(model.notes.first?.y, currentNote.y)
        // Even if a new editor is open, a late save from the old editor is not its note.
        model.editNote(id: currentNote.id, selectionID: model.selection)
        XCTAssertFalse(model.commitNote(stale))
        XCTAssertEqual(model.notes.map(\.id), [currentNote.id])
        XCTAssertEqual(model.notes.first?.text, currentNote.text)
        model.cancelNoteEditing()
        model.persist()
    }

    @MainActor func testNoteEditInvalidatesUploadButUnchangedRetryReusesIDAndPNG() async throws {
        let (model, root) = try fixture()
        defer { TextNoteTestProtocol.reply = nil; try? FileManager.default.removeItem(at: root) }
        let item = capture("a", time: 1), source = samplePNG()
        var uploads: [(id: String, bytes: Data)] = []
        TextNoteTestProtocol.reply = { request in
            switch request.url!.path {
            case "/api/library": return (200, try self.libraryData([item]))
            case "/api/save":
                uploads.append((try XCTUnwrap(request.value(forHTTPHeaderField: "X-Submission-ID")), try self.requestBody(request)))
                if uploads.count < 4 { throw URLError(.networkConnectionLost) }
                return try self.receipt(request)
            default: return (200, source)
            }
        }
        await model.poll()
        let note = try addNote("Before", to: model)
        await model.finish()
        await model.finish()
        XCTAssertEqual(uploads.count, 2)
        guard uploads.count == 2 else { return }
        XCTAssertEqual(uploads[0].id, uploads[1].id)
        XCTAssertEqual(uploads[0].bytes, uploads[1].bytes)
        XCTAssertTrue(model.dirty)
        let store = try DraftStore(namespace: try XCTUnwrap(model.connection).namespace, root: root)
        XCTAssertNotNil(store.pending(item.id))

        model.editNote(id: note.id, selectionID: model.selection)
        var changed = try XCTUnwrap(model.noteEditor).note
        changed.text = "After editing"
        XCTAssertTrue(model.commitNote(changed))
        model.persist()
        XCTAssertNil(store.draft(item.id)?.submission, "The edited note must not retain the failed submission identity")
        await model.finish()
        XCTAssertEqual(uploads.count, 3)
        guard uploads.count == 3 else { return }
        XCTAssertNotEqual(uploads[2].id, uploads[1].id, "An edited note must use a fresh submission identity")
        XCTAssertNotEqual(try pixels(uploads[2].bytes), try pixels(uploads[1].bytes), "An edited note must never send the old cached PNG")
        await model.finish()
        XCTAssertEqual(uploads.count, 4)
        guard uploads.count == 4 else { return }
        XCTAssertEqual(uploads[3].id, uploads[2].id)
        XCTAssertEqual(uploads[3].bytes, uploads[2].bytes)
        XCTAssertEqual(model.completedCaptureCount, 1)
        XCTAssertNil(model.current)
    }

    @MainActor func testNavigationKeepsUnsavedNotesAndInkWhenDraftPersistenceFails() async throws {
        let (model, root) = try fixture()
        defer { TextNoteTestProtocol.reply = nil; try? FileManager.default.removeItem(at: root) }
        let first = capture("a", time: 1), second = capture("b", time: 2, saved: true), source = samplePNG()
        var secondImageRequests = 0
        TextNoteTestProtocol.reply = { request in
            if request.url!.path == "/api/library" { return (200, try self.libraryData([first, second])) }
            if request.url!.path.hasSuffix(second.id) { secondImageRequests += 1 }
            return (200, source)
        }
        await model.poll()
        let note = try addNote("Original wording", to: model)
        let canvas = TextNoteTestCanvas()
        let points = [CGPoint(x: 10, y: 65), CGPoint(x: 100, y: 65)].enumerated().map { index, point in
            PKStrokePoint(location: point, timeOffset: Double(index) * 0.1, size: CGSize(width: 5, height: 5), opacity: 1, force: 1, azimuth: 0, altitude: .pi / 2)
        }
        let stroke = PKStroke(ink: PKInk(.pen, color: .red), path: PKStrokePath(controlPoints: points, creationDate: Date(timeIntervalSince1970: 0)))
        canvas.drawing = PKDrawing(strokes: [stroke])
        model.canvas = canvas
        model.drawingChanged(canvas.drawing, selectionID: model.selection)
        XCTAssertTrue(model.persist())
        model.editNote(id: note.id, selectionID: model.selection)
        var changed = try XCTUnwrap(model.noteEditor).note
        changed.text = "Changed but not yet durable"

        // Only this synthetic temporary DraftStore is made unwritable. Keep its
        // original directory intact so recovery can also be exercised below.
        let store = try DraftStore(namespace: try XCTUnwrap(model.connection).namespace, root: root)
        let preserved = root.appendingPathComponent("preserved-drafts", isDirectory: true)
        try FileManager.default.moveItem(at: store.folder, to: preserved)
        try Data("Synthetic write-failure fixture".utf8).write(to: store.folder)
        XCTAssertTrue(model.commitNote(changed), "The edited note should remain available in memory when its local write fails")
        let selected = model.selection, notes = model.notes, ink = model.drawing.dataRepresentation()
        let expectedDrawing = model.drawing
        let originalImage = try XCTUnwrap(model.image).pngData()
        XCTAssertEqual(notes.first?.text, changed.text)
        XCTAssertFalse(model.drawing.strokes.isEmpty)

        let opened = await model.open(second)
        XCTAssertFalse(opened, "Navigation must stop before discarding a draft that could not be persisted")
        XCTAssertEqual(secondImageRequests, 0, "Do not begin loading another screenshot after the local save failed")
        XCTAssertEqual(model.current?.id, first.id)
        XCTAssertEqual(model.selection, selected)
        XCTAssertEqual(model.notes, notes)
        XCTAssertEqual(model.drawing.dataRepresentation(), ink)
        XCTAssertEqual(canvas.drawing.dataRepresentation(), ink)
        XCTAssertEqual(model.image?.pngData(), originalImage)
        XCTAssertTrue(model.dirty)
        XCTAssertTrue(model.error?.contains("could not be saved") == true)
        XCTAssertNil(model.loadingID)

        try FileManager.default.removeItem(at: store.folder)
        try FileManager.default.moveItem(at: preserved, to: store.folder)
        XCTAssertTrue(model.persist(), "The in-memory draft must remain recoverable after storage becomes available")
        let openedAfterRecovery = await model.open(second)
        XCTAssertTrue(openedAfterRecovery)
        let reopened = await model.open(first)
        XCTAssertTrue(reopened)
        XCTAssertEqual(model.notes, notes)
        // PencilKit may rewrite serialization metadata on decode. Compare the
        // rendered result and editable stroke semantics after a disk roundtrip.
        let bounds = CGRect(x: 0, y: 0, width: first.width, height: first.height)
        let expectedPNG = try XCTUnwrap(expectedDrawing.image(from: bounds, scale: 1).pngData())
        let reopenedPNG = try XCTUnwrap(model.drawing.image(from: bounds, scale: 1).pngData())
        XCTAssertEqual(try pixels(reopenedPNG), try pixels(expectedPNG))
        XCTAssertEqual(model.drawing.strokes.count, expectedDrawing.strokes.count)
        for (actual, expected) in zip(model.drawing.strokes, expectedDrawing.strokes) {
            XCTAssertEqual(actual.ink.inkType, expected.ink.inkType)
            XCTAssertEqual(actual.transform, expected.transform)
            XCTAssertEqual(actual.path.count, expected.path.count)
            var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
            var expectedRed: CGFloat = 0, expectedGreen: CGFloat = 0, expectedBlue: CGFloat = 0, expectedAlpha: CGFloat = 0
            XCTAssertTrue(actual.ink.color.getRed(&red, green: &green, blue: &blue, alpha: &alpha))
            XCTAssertTrue(expected.ink.color.getRed(&expectedRed, green: &expectedGreen, blue: &expectedBlue, alpha: &expectedAlpha))
            XCTAssertEqual(red, expectedRed, accuracy: 0.000001)
            XCTAssertEqual(green, expectedGreen, accuracy: 0.000001)
            XCTAssertEqual(blue, expectedBlue, accuracy: 0.000001)
            XCTAssertEqual(alpha, expectedAlpha, accuracy: 0.000001)
            for (point, expectedPoint) in zip(actual.path, expected.path) {
                XCTAssertEqual(point.location, expectedPoint.location)
                XCTAssertEqual(point.size, expectedPoint.size)
                XCTAssertEqual(point.opacity, expectedPoint.opacity, accuracy: 0.000001)
                XCTAssertEqual(point.force, expectedPoint.force, accuracy: 0.000001)
                XCTAssertEqual(point.azimuth, expectedPoint.azimuth, accuracy: 0.000001)
                XCTAssertEqual(point.altitude, expectedPoint.altitude, accuracy: 0.000001)
            }
        }
        XCTAssertTrue(model.dirty)
    }

    @MainActor func testClearQueueRetainsTextOnlyDraftAndCachedSourceAfterRestart() async throws {
        let (model, root) = try fixture()
        defer { TextNoteTestProtocol.reply = nil; try? FileManager.default.removeItem(at: root) }
        let item = capture("a", time: 1), source = samplePNG()
        var cleared = false, resets = 0
        TextNoteTestProtocol.reply = { request in
            switch request.url!.path {
            case "/api/library": return (200, try self.libraryData(cleared ? [] : [item], session: cleared ? "session-two" : "session-one"))
            case "/api/session/reset":
                resets += 1; cleared = true
                return (200, try self.libraryData([], session: "session-two"))
            default: return cleared ? (404, Data()) : (200, source)
            }
        }
        await model.poll()
        let note = try addNote("Do not lose this note", to: model)
        XCTAssertTrue(model.drawing.strokes.isEmpty)
        await model.clearQueue()
        XCTAssertEqual(resets, 1)
        XCTAssertNil(model.current)
        XCTAssertTrue(model.notes.isEmpty)
        XCTAssertTrue(model.captures.isEmpty)
        XCTAssertEqual(model.unfinishedDrawingCount, 1)

        let restored = try fixture(root: root).0
        await restored.poll()
        restored.browse()
        XCTAssertTrue(restored.browser?.captures.contains(where: { $0.id == item.id }) == true)
        let opened = await restored.open(item)
        XCTAssertTrue(opened, "A queue reset must leave a text-only draft reachable even when the Mac no longer serves its source")
        XCTAssertEqual(restored.notes.map(\.id), [note.id])
        XCTAssertEqual(restored.notes.first?.text, note.text)
        XCTAssertTrue(restored.dirty)
        XCTAssertTrue(restored.drawing.strokes.isEmpty)
        XCTAssertNotNil(restored.image)
        restored.persist()
    }

    @MainActor private func fixture(root: URL? = nil) throws -> (WorkspaceModel, URL) {
        let location = root ?? FileManager.default.temporaryDirectory.appendingPathComponent("TextNoteWorkflow-" + UUID().uuidString)
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [TextNoteTestProtocol.self]
        let connection = try Connection.parse("http://127.0.0.1:8765/#pair=unit-test-text-notes")
        return (WorkspaceModel(connection: connection, configuration: configuration, draftRoot: location), location)
    }
    private func capture(_ letter: String, time: Double, saved: Bool = false) -> Capture {
        Capture(id: String(repeating: letter, count: 24), title: "Synthetic " + letter, width: 120, height: 80, modified: time, saved: saved)
    }
    @MainActor private func addNote(_ text: String, to model: WorkspaceModel) throws -> TextNote {
        model.noteMode = true
        model.beginNote(at: CGPoint(x: 4, y: 4), selectionID: model.selection)
        var note = try XCTUnwrap(model.noteEditor).note
        note.text = text; note.width = 100; note.fontSize = 12
        XCTAssertTrue(model.commitNote(note))
        XCTAssertNil(model.noteEditor)
        return try XCTUnwrap(model.notes.first(where: { $0.id == note.id }))
    }
    @MainActor private func samplePNG() -> Data {
        let format = UIGraphicsImageRendererFormat(); format.scale = 1
        return UIGraphicsImageRenderer(size: CGSize(width: 120, height: 80), format: format).image { context in
            UIColor.white.setFill(); context.fill(CGRect(x: 0, y: 0, width: 120, height: 80))
        }.pngData()!
    }
    private func libraryData(_ captures: [Capture], session: String = "session-one") throws -> Data {
        let items = try JSONSerialization.jsonObject(with: JSONEncoder().encode(captures))
        return try JSONSerialization.data(withJSONObject: ["captures": items, "supportsSessions": true, "session": ["id": session, "startedAt": 1]])
    }
    private func receipt(_ request: URLRequest) throws -> (Int, Data) {
        let id = try XCTUnwrap(request.value(forHTTPHeaderField: "X-Submission-ID"))
        return (200, try JSONSerialization.data(withJSONObject: ["id": id, "filename": "synthetic-note.png"]))
    }
    private func requestBody(_ request: URLRequest) throws -> Data {
        if let body = request.httpBody { return body }
        guard let stream = request.httpBodyStream else { return Data() }
        stream.open(); defer { stream.close() }
        var data = Data(), buffer = [UInt8](repeating: 0, count: 4096)
        while stream.hasBytesAvailable {
            let count = stream.read(&buffer, maxLength: buffer.count)
            if count < 0 { throw stream.streamError ?? URLError(.cannotDecodeRawData) }
            if count == 0 { break }
            data.append(buffer, count: count)
        }
        return data
    }
    private func pixels(_ data: Data) throws -> Data {
        let image = try XCTUnwrap(UIImage(data: data)?.cgImage)
        let context = try XCTUnwrap(CGContext(data: nil, width: image.width, height: image.height, bitsPerComponent: 8, bytesPerRow: image.width * 4, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        return Data(bytes: try XCTUnwrap(context.data), count: image.width * image.height * 4)
    }
}

private final class TextNoteTestCanvas: PKCanvasView {
    private let history = UndoManager()
    override var undoManager: UndoManager? { history }
}

private final class TextNoteTestProtocol: URLProtocol {
    static var reply: ((URLRequest) throws -> (Int, Data))?
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        do {
            guard let reply = Self.reply else { throw URLError(.unsupportedURL) }
            let (code, data) = try reply(request)
            let response = HTTPURLResponse(url: request.url!, statusCode: code, httpVersion: "HTTP/1.1", headerFields: nil)!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch { client?.urlProtocol(self, didFailWithError: error) }
    }
    override func stopLoading() {}
}
