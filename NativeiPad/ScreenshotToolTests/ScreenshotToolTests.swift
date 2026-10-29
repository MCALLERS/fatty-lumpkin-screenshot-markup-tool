import XCTest
import PencilKit
import Combine
@testable import ScreenshotToolNative

final class ScreenshotToolTests: XCTestCase {
    private func capture(_ id: String, time: Double, saved: Bool = false) -> Capture { Capture(id: String(repeating: id, count: 24), title: id, width: 120, height: 80, modified: time, saved: saved) }
    func testQueueOrdersPendingCapturesAndDoesNotRepeatFinishedOnes() {
        let first=capture("a",time:1), second=capture("b",time:2), third=capture("c",time:3), old=capture("d",time:0,saved:true)
        var queue=CaptureQueue();queue.merge([third,old,second,first])
        XCTAssertEqual(queue.ids,[first.id,second.id,third.id]);XCTAssertEqual(queue.position(second.id),"2 of 3")
        XCTAssertEqual(queue.pending([third,old,second,first],locallySaved:[first.id]).map(\.id),[second.id,third.id])
        let fourth=capture("e",time:4);queue.merge([fourth,third,old,second,first],locallySaved:[first.id,second.id,third.id])
        XCTAssertEqual(queue.ids,[fourth.id])
    }
    @MainActor private func navigationFixture() throws -> (WorkspaceModel, URL) {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let config = URLSessionConfiguration.ephemeral; config.protocolClasses = [NativeTestProtocol.self]
        let connection = try Connection.parse("http://127.0.0.1:8765/#pair=unit-test-navigation")
        return (WorkspaceModel(connection: connection, configuration: config, draftRoot: root), root)
    }
    @MainActor private func samplePNG() -> Data {
        let format = UIGraphicsImageRendererFormat(); format.scale = 1
        return UIGraphicsImageRenderer(size: CGSize(width: 120, height: 80), format: format).image { context in
            UIColor.white.setFill(); context.fill(CGRect(x: 0, y: 0, width: 120, height: 80))
        }.pngData()!
    }
    @MainActor func testIdenticalPollingDoesNotRepublishTheScreenshotList() async throws {
        let (model, root) = try navigationFixture()
        defer { NativeTestProtocol.reply = nil; try? FileManager.default.removeItem(at: root) }
        let list = [capture("a", time: 1, saved: true)]
        NativeTestProtocol.reply = { _ in (200, try JSONEncoder().encode(["captures": list])) }
        var publications = 0
        let subscription = model.$captures.dropFirst().sink { _ in publications += 1 }
        await model.poll(); await model.poll(); await model.poll()
        XCTAssertEqual(publications, 1, "An unchanged refresh must not rebuild the screenshot picker")
        withExtendedLifetime(subscription) {}
    }
    @MainActor func testBrowserRowsStayFixedAndIncomingCapturesDoNotTakeOverWhileBrowsing() async throws {
        let (model, root) = try navigationFixture()
        defer { NativeTestProtocol.reply = nil; try? FileManager.default.removeItem(at: root) }
        let first = capture("a", time: 1, saved: true), second = capture("b", time: 2, saved: true), new = capture("c", time: 3)
        var list = [second, first]
        let png = samplePNG(); var imageRequests = 0
        NativeTestProtocol.reply = { request in
            if request.url!.path == "/api/library" { return (200, try JSONEncoder().encode(["captures": list])) }
            imageRequests += 1; return (200, png)
        }
        await model.poll(); model.browse()
        let sessionID = try XCTUnwrap(model.browser?.id)
        XCTAssertEqual(model.browser?.captures.map(\.id), [first.id, second.id])
        list = [new, second, first]
        await model.poll(); await model.poll()
        XCTAssertEqual(model.browser?.id, sessionID)
        XCTAssertEqual(model.browser?.captures.map(\.id), [first.id, second.id])
        XCTAssertNil(model.current); XCTAssertEqual(imageRequests, 0)
        model.browser = nil
        await model.poll()
        XCTAssertEqual(model.current?.id, new.id)
        model.browse()
        XCTAssertEqual(model.browser?.captures.map(\.id), [first.id, second.id, new.id])
    }
    @MainActor func testArrowsOpenSavedScreenshotsFromAnUnselectedWorkspace() async throws {
        let (model, root) = try navigationFixture()
        defer { NativeTestProtocol.reply = nil; try? FileManager.default.removeItem(at: root) }
        let first = capture("a", time: 1, saved: true), middle = capture("b", time: 2, saved: true), last = capture("c", time: 3, saved: true)
        let png = samplePNG(); var mutations = 0
        NativeTestProtocol.reply = { request in
            if request.httpMethod != "GET" { mutations += 1 }
            return request.url!.path == "/api/library" ? (200, try self.libraryData([middle, last, first])) : (200, png)
        }
        await model.poll()
        XCTAssertNil(model.current); XCTAssertEqual(model.navigationPosition, "3 screenshots")
        let oldest = try XCTUnwrap(model.followingCapture, "Next must open the oldest screenshot when none is selected")
        let newest = try XCTUnwrap(model.previousCapture, "Previous must reopen the newest saved screenshot")
        XCTAssertEqual(oldest.id, first.id); XCTAssertEqual(newest.id, last.id)
        let openedNewest = await model.open(newest)
        XCTAssertTrue(openedNewest); XCTAssertEqual(model.navigationPosition, "3 of 3")
        XCTAssertEqual(model.previousCapture?.id, middle.id); XCTAssertNil(model.followingCapture)
        let openedOldest = await model.open(oldest)
        XCTAssertTrue(openedOldest); XCTAssertEqual(model.navigationPosition, "1 of 3")
        XCTAssertNil(model.previousCapture); XCTAssertEqual(model.followingCapture?.id, middle.id)
        XCTAssertEqual(mutations, 0, "Browsing saved images must not export, reset, or delete anything")
    }
    @MainActor func testArrowsRemainUsefulAfterFinishingTheLastScreenshot() async throws {
        let (model, root) = try navigationFixture()
        defer { NativeTestProtocol.reply = nil; try? FileManager.default.removeItem(at: root) }
        let first = capture("a", time: 1, saved: true), last = capture("b", time: 2), png = samplePNG()
        var receiptID = "", saves = 0
        NativeTestProtocol.reply = { request in
            switch request.url!.path {
            case "/api/library": return (200, try self.libraryData([last, first]))
            case "/api/save":
                saves += 1; receiptID = try XCTUnwrap(request.value(forHTTPHeaderField: "X-Submission-ID"))
                return (200, try JSONSerialization.data(withJSONObject: ["id": receiptID, "filename": "finished.png"]))
            case "/api/status": return (200, try JSONSerialization.data(withJSONObject: ["lastCopied": receiptID]))
            default: return (200, png)
            }
        }
        await model.poll(); XCTAssertEqual(model.current?.id, last.id)
        await model.finish(); await model.poll()
        XCTAssertNil(model.current); XCTAssertNotNil(model.completedMessage)
        XCTAssertEqual(model.navigationPosition, "2 screenshots")
        XCTAssertEqual(model.followingCapture?.id, first.id)
        let previous = try XCTUnwrap(model.previousCapture)
        XCTAssertEqual(previous.id, last.id)
        let reopened = await model.open(previous)
        XCTAssertTrue(reopened); XCTAssertEqual(model.current?.id, last.id)
        XCTAssertNil(model.completedMessage); XCTAssertEqual(model.navigationPosition, "2 of 2")
        await model.poll()
        XCTAssertEqual(model.current?.id, last.id); XCTAssertEqual(saves, 1)
    }
    @MainActor func testEmptyAndSingleScreenshotArrowBoundaries() async throws {
        let (model, root) = try navigationFixture()
        defer { NativeTestProtocol.reply = nil; try? FileManager.default.removeItem(at: root) }
        let only = capture("a", time: 1, saved: true), png = samplePNG()
        var list: [Capture] = []
        NativeTestProtocol.reply = { request in request.url!.path == "/api/library" ? (200, try self.libraryData(list)) : (200, png) }
        await model.poll()
        XCTAssertNil(model.previousCapture); XCTAssertNil(model.followingCapture)
        list = [only]; await model.poll()
        XCTAssertEqual(model.previousCapture?.id, only.id); XCTAssertEqual(model.followingCapture?.id, only.id)
        let opened = await model.open(only); XCTAssertTrue(opened)
        XCTAssertNil(model.previousCapture); XCTAssertNil(model.followingCapture)
    }
    @MainActor func testPreviousNextPreserveInkAndManualSelectionAcrossRefreshes() async throws {
        let (model, root) = try navigationFixture()
        defer { NativeTestProtocol.reply = nil; try? FileManager.default.removeItem(at: root) }
        let first = capture("a", time: 1, saved: true), second = capture("b", time: 2, saved: true), new = capture("c", time: 3)
        var list = [second, first]; let png = samplePNG()
        NativeTestProtocol.reply = { request in request.url!.path == "/api/library" ? (200, try JSONEncoder().encode(["captures": list])) : (200, png) }
        await model.poll()
        let opened = await model.open(first); XCTAssertTrue(opened)
        XCTAssertNil(model.previousCapture); XCTAssertEqual(model.followingCapture?.id, second.id)
        let point = PKStrokePoint(location: CGPoint(x: 30, y: 30), timeOffset: 0, size: CGSize(width: 5, height: 5), opacity: 1, force: 1, azimuth: 0, altitude: .pi / 2)
        let ink = PKDrawing(strokes: [PKStroke(ink: PKInk(.pen, color: .green), path: PKStrokePath(controlPoints: [point], creationDate: Date()))])
        model.drawingChanged(ink, selectionID: model.selection)
        await model.open(second)
        XCTAssertEqual(model.previousCapture?.id, first.id); XCTAssertNil(model.followingCapture)
        await model.open(first)
        XCTAssertTrue(model.dirty); XCTAssertEqual(model.drawing.strokes.count, 1)
        list = [new, second, first]
        await model.poll(); await model.poll()
        XCTAssertEqual(model.current?.id, first.id); XCTAssertEqual(model.navigationPosition, "1 of 3")
        model.browse(); XCTAssertTrue(model.browser?.draftIDs.contains(first.id) == true)
        model.persist()
    }
    @MainActor func testFailedBrowserSelectionKeepsTheCurrentScreenshotAndBrowser() async throws {
        let (model, root) = try navigationFixture()
        defer { NativeTestProtocol.reply = nil; try? FileManager.default.removeItem(at: root) }
        let first = capture("a", time: 1, saved: true), second = capture("b", time: 2, saved: true), png = samplePNG()
        NativeTestProtocol.reply = { request in
            if request.url!.path == "/api/library" { return (200, try JSONEncoder().encode(["captures": [second, first]])) }
            if request.url!.path.hasSuffix(second.id) { return (500, Data()) }
            return (200, png)
        }
        await model.poll(); await model.open(first); model.browse()
        let selection = model.selection
        let opened = await model.open(second)
        XCTAssertFalse(opened); XCTAssertEqual(model.current?.id, first.id); XCTAssertEqual(model.selection, selection)
        XCTAssertNotNil(model.browser); XCTAssertNotNil(model.error); XCTAssertNil(model.loadingID)
    }
    @MainActor func testNewSessionOnMacClearsOldSelectionAndStartsAtZero() async throws {
        let (model, root) = try navigationFixture()
        defer { NativeTestProtocol.reply = nil; try? FileManager.default.removeItem(at: root) }
        let old = capture("a", time: 1, saved: true), png = samplePNG()
        var sessionID = "session-one"
        var list = [old]
        NativeTestProtocol.reply = { request in
            if request.url!.path == "/api/library" {
                let encoded = try JSONSerialization.jsonObject(with: JSONEncoder().encode(list))
                return (200, try JSONSerialization.data(withJSONObject: ["captures": encoded, "supportsSessions": true, "session": ["id": sessionID, "startedAt": 1]]))
            }
            return (200, png)
        }
        await model.poll(); await model.open(old)
        XCTAssertEqual(model.current?.id, old.id)
        sessionID = "session-two"; list = []
        await model.poll()
        XCTAssertNil(model.current, "Starting a new session on the Mac must clear the previous session's clean selection")
        XCTAssertTrue(model.queue.ids.isEmpty)
        XCTAssertEqual(model.navigationPosition, "0 screenshots")
    }
    private func libraryData(_ captures: [Capture], session: String = "session-one") throws -> Data {
        let encoded = try JSONSerialization.jsonObject(with: JSONEncoder().encode(captures))
        return try JSONSerialization.data(withJSONObject: ["captures": encoded, "supportsSessions": true, "session": ["id": session, "startedAt": 1]])
    }
    @MainActor func testResetRetriesWithSameRequestIDAndKeepsOriginalDraftCache() async throws {
        let (model, root) = try navigationFixture()
        defer { NativeTestProtocol.reply = nil; try? FileManager.default.removeItem(at: root) }
        let old = capture("a", time: 1, saved: true), png = samplePNG()
        var resets: [String] = []
        NativeTestProtocol.reply = { request in
            switch request.url!.path {
            case "/api/library": return (200, try self.libraryData([old]))
            case "/api/session/reset":
                XCTAssertEqual(request.httpMethod, "POST")
                XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer unit-test-navigation")
                XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/json")
                let body = try JSONDecoder().decode([String: String].self, from: self.requestBody(request))
                resets.append(try XCTUnwrap(body["requestID"]))
                return resets.count == 1 ? (500, Data()) : (200, try self.libraryData([], session: "session-two"))
            default: return (200, png)
            }
        }
        await model.poll(); await model.open(old)
        await model.startNewSession()
        XCTAssertEqual(model.current?.id, old.id); XCTAssertNotNil(model.error)
        await model.startNewSession()
        XCTAssertEqual(resets.count, 2); XCTAssertEqual(resets[0], resets[1]); XCTAssertNotNil(UUID(uuidString: resets[0]))
        XCTAssertNil(model.current); XCTAssertTrue(model.captures.isEmpty); XCTAssertEqual(model.navigationPosition, "0 screenshots")
        let store = try DraftStore(namespace: try XCTUnwrap(model.connection).namespace, root: root)
        XCTAssertNotNil(store.image(old.id), "Reset must not delete previous images")
        XCTAssertNil(store.session().pendingResetID)
        XCTAssertEqual(store.session().librarySessionID, "session-two")
    }
    @MainActor func testClearQueueResetsToZeroAndKeepsUnfinishedInkReachableAfterRestart() async throws {
        let (model, root) = try navigationFixture()
        defer { NativeTestProtocol.reply = nil; try? FileManager.default.removeItem(at: root) }
        let old = capture("a", time: 1), fresh = capture("b", time: 2), png = samplePNG()
        var list = [old], session = "session-one", mutations: [String] = []
        NativeTestProtocol.reply = { request in
            if request.httpMethod != "GET" { mutations.append(request.url!.path) }
            switch request.url!.path {
            case "/api/library": return (200, try self.libraryData(list, session: session))
            case "/api/session/reset":
                list = []; session = "session-two"
                return (200, try self.libraryData([], session: session))
            default: return (200, png)
            }
        }
        await model.poll()
        let point = PKStrokePoint(location: CGPoint(x: 30, y: 30), timeOffset: 0, size: CGSize(width: 5, height: 5), opacity: 1, force: 1, azimuth: 0, altitude: .pi / 2)
        let ink = PKDrawing(strokes: [PKStroke(ink: PKInk(.pen, color: .red), path: PKStrokePath(controlPoints: [point], creationDate: Date()))])
        model.drawingChanged(ink, selectionID: model.selection)
        let canvas = PKCanvasView(); canvas.drawing = PKDrawing(strokes: ink.strokes + ink.strokes)
        model.canvas = canvas // A final Pencil stroke can arrive before its delegate callback.
        model.requestClearQueue()
        XCTAssertTrue(model.showClearQueueConfirmation); XCTAssertTrue(mutations.isEmpty)
        model.showClearQueueConfirmation = false // Cancelling the prompt leaves the queue untouched.
        XCTAssertEqual(model.current?.id, old.id)
        await model.clearQueue()
        XCTAssertEqual(mutations, ["/api/session/reset"], "Clearing the queue must never invoke file cleanup")
        XCTAssertNil(model.current); XCTAssertTrue(model.queue.ids.isEmpty)
        XCTAssertEqual(model.navigationPosition, "0 screenshots")
        let store = try DraftStore(namespace: try XCTUnwrap(model.connection).namespace, root: root)
        XCTAssertEqual(store.imageData(old.id), png)
        XCTAssertEqual(store.drawing(old.id).strokes.count, 2)
        XCTAssertTrue(store.draft(old.id)?.dirty == true)
        XCTAssertNil(store.session().currentID, "Restart must retain the empty queue instead of reopening its hidden draft")
        let config = URLSessionConfiguration.ephemeral; config.protocolClasses = [NativeTestProtocol.self]
        let reopened = WorkspaceModel(connection: model.connection, configuration: config, draftRoot: root)
        await reopened.poll()
        XCTAssertEqual(reopened.navigationPosition, "0 screenshots"); XCTAssertNil(reopened.current)
        reopened.browse()
        XCTAssertEqual(reopened.browser?.draftIDs, [old.id])
        let restored = await reopened.open(old)
        XCTAssertTrue(restored); XCTAssertEqual(reopened.drawing.strokes.count, 2)
        reopened.browser = nil
        await reopened.clearQueue()
        list = [fresh]
        await reopened.poll()
        XCTAssertEqual(reopened.current?.id, fresh.id)
        XCTAssertEqual(reopened.navigationPosition, "1 of 1")
    }
    @MainActor func testClearQueueRetryAfterRestartUsesTheSameResetAndKeepsItsDraft() async throws {
        let (model, root) = try navigationFixture()
        defer { NativeTestProtocol.reply = nil; try? FileManager.default.removeItem(at: root) }
        let old = capture("a", time: 1), png = samplePNG()
        var ids: [String] = []
        NativeTestProtocol.reply = { request in
            if request.url!.path == "/api/library" { return (200, try self.libraryData([old])) }
            if request.url!.path == "/api/session/reset" {
                let body = try JSONDecoder().decode([String: String].self, from: self.requestBody(request))
                ids.append(try XCTUnwrap(body["requestID"]))
                return ids.count == 1 ? (500, Data()) : (200, try self.libraryData([], session: "session-two"))
            }
            return (200, png)
        }
        await model.poll(); model.drawingChanged(PKDrawing(), selectionID: model.selection)
        model.busy = true; await model.clearQueue(); XCTAssertTrue(ids.isEmpty)
        model.busy = false; await model.clearQueue()
        XCTAssertNotNil(model.error); XCTAssertEqual(model.current?.id, old.id)
        let config = URLSessionConfiguration.ephemeral; config.protocolClasses = [NativeTestProtocol.self]
        let reopened = WorkspaceModel(connection: model.connection, configuration: config, draftRoot: root)
        await reopened.poll(); await reopened.clearQueue()
        XCTAssertEqual(ids.count, 2); XCTAssertEqual(ids.first, ids.last)
        XCTAssertNil(reopened.current); XCTAssertEqual(reopened.navigationPosition, "0 screenshots")
        reopened.browse(); XCTAssertTrue(reopened.browser?.draftIDs.contains(old.id) == true)
    }
    @MainActor func testClearQueueDoesNotHideDrawingWhenLocalDraftCannotBeSaved() async throws {
        let (model, root) = try navigationFixture()
        defer { NativeTestProtocol.reply = nil; try? FileManager.default.removeItem(at: root) }
        let old = capture("a", time: 1), png = samplePNG()
        var resets = 0
        NativeTestProtocol.reply = { request in
            if request.url!.path == "/api/library" { return (200, try self.libraryData([old])) }
            if request.url!.path == "/api/session/reset" { resets += 1; return (200, try self.libraryData([], session: "session-two")) }
            return (200, png)
        }
        await model.poll(); model.drawingChanged(PKDrawing(), selectionID: model.selection)
        let store = try DraftStore(namespace: try XCTUnwrap(model.connection).namespace, root: root)
        try FileManager.default.moveItem(at: store.folder, to: store.folder.appendingPathExtension("preserved"))
        try Data("blocked draft directory".utf8).write(to: store.folder)
        await model.clearQueue()
        XCTAssertEqual(resets, 0); XCTAssertEqual(model.current?.id, old.id); XCTAssertTrue(model.dirty)
        XCTAssertNotNil(model.error)
    }
    @MainActor func testUnfinishedDraftOnAnotherScreenshotBlocksResetAndCleanup() async throws {
        let (model, root) = try navigationFixture()
        defer { NativeTestProtocol.reply = nil; try? FileManager.default.removeItem(at: root) }
        let first = capture("a", time: 1, saved: true), second = capture("b", time: 2, saved: true), png = samplePNG()
        var requests: [String] = []
        NativeTestProtocol.reply = { request in
            requests.append(request.url!.path)
            return request.url!.path == "/api/library" ? (200, try self.libraryData([first, second])) : (200, png)
        }
        await model.poll(); await model.open(first)
        model.drawingChanged(PKDrawing(), selectionID: model.selection)
        await model.open(second)
        XCTAssertFalse(model.dirty); XCTAssertEqual(model.unfinishedDrawingCount, 1)
        await model.startNewSession(); await model.previewCleanup()
        XCTAssertFalse(requests.contains("/api/session/reset")); XCTAssertFalse(requests.contains("/api/library/cleanup"))
        XCTAssertEqual(model.current?.id, second.id); XCTAssertEqual(model.captures.count, 2)
        XCTAssertTrue(model.error?.contains("unfinished") == true)
    }
    @MainActor func testOlderMacExplainsUpdateWithoutSendingUnsupportedMutation() async throws {
        let (model, root) = try navigationFixture()
        defer { NativeTestProtocol.reply = nil; try? FileManager.default.removeItem(at: root) }
        var requests = 0
        NativeTestProtocol.reply = { request in
            requests += 1; XCTAssertEqual(request.httpMethod, "GET")
            return (200, Data("{\"captures\":[]}".utf8))
        }
        await model.poll(); await model.startNewSession(); await model.previewCleanup()
        XCTAssertEqual(requests, 1); XCTAssertFalse(model.supportsSessions)
        XCTAssertTrue(model.error?.contains("Update the Mac companion") == true)
    }
    @MainActor func testSessionChangesWaitForClipboardAcknowledgement() async throws {
        let (model, root) = try navigationFixture()
        defer { NativeTestProtocol.reply = nil; try? FileManager.default.removeItem(at: root) }
        let screenshot = capture("a", time: 1), png = samplePNG()
        var receiptID = "", resets = 0
        NativeTestProtocol.reply = { request in
            switch request.url!.path {
            case "/api/library": return (200, try self.libraryData([screenshot]))
            case "/api/save":
                receiptID = try XCTUnwrap(request.value(forHTTPHeaderField: "X-Submission-ID"))
                return (200, try JSONSerialization.data(withJSONObject: ["id": receiptID, "filename": "finished.png"]))
            case "/api/status": return (200, try JSONSerialization.data(withJSONObject: ["lastCopied": receiptID]))
            case "/api/session/reset": resets += 1; return (200, try self.libraryData([], session: "session-two"))
            default: return (200, png)
            }
        }
        await model.poll(); await model.finish()
        XCTAssertNil(model.current)
        XCTAssertTrue(model.sessionActionIssue?.contains("clipboard") == true)
        await model.startNewSession(); await model.clearQueue(); XCTAssertEqual(resets, 0)
        await model.poll()
        XCTAssertNil(model.sessionActionIssue)
        await model.startNewSession(); XCTAssertEqual(resets, 1)
    }
    @MainActor func testCleanupConflictRequiresFreshPreviewAndPreservesLocalCache() async throws {
        let (model, root) = try navigationFixture()
        defer { NativeTestProtocol.reply = nil; try? FileManager.default.removeItem(at: root) }
        let old = capture("a", time: 1, saved: true), png = samplePNG()
        let store = try DraftStore(namespace: try XCTUnwrap(model.connection).namespace, root: root)
        try store.store(old, image: png)
        try store.write(DraftMetadata(capture: old, dirty: false), drawing: PKDrawing())
        let currentButOutsideVisiblePage = capture("b", time: 2, saved: true)
        try store.store(currentButOutsideVisiblePage, image: png)
        try store.write(DraftMetadata(capture: currentButOutsideVisiblePage, dirty: false), drawing: PKDrawing())
        var cleanups = 0
        NativeTestProtocol.reply = { request in
            if request.url!.path == "/api/library" { return (200, try self.libraryData([])) }
            XCTAssertEqual(request.url!.path, "/api/library/cleanup")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer unit-test-navigation")
            if request.httpMethod == "GET" {
                return (200, Data("{\"token\":\"snapshot-1\",\"captureCount\":1,\"fileCount\":2,\"byteCount\":1234}".utf8))
            }
            XCTAssertEqual(try JSONDecoder().decode([String: String].self, from: self.requestBody(request)), ["token": "snapshot-1"])
            cleanups += 1
            return cleanups == 1 ? (409, Data("{\"error\":\"The library changed.\"}".utf8)) : (200, try JSONSerialization.data(withJSONObject: ["movedFiles": 2, "movedBytes": 1234, "movedCaptureIDs": [old.id]]))
        }
        await model.poll(); await model.previewCleanup()
        XCTAssertEqual(model.cleanupPreview?.fileCount, 2)
        await model.trashPreviousSessions()
        XCTAssertNil(model.cleanupPreview); XCTAssertNotNil(store.image(old.id)); XCTAssertNotNil(model.error)
        await model.trashPreviousSessions(); XCTAssertEqual(cleanups, 1, "A failed snapshot cannot be reused blindly")
        await model.previewCleanup(); await model.trashPreviousSessions()
        XCTAssertEqual(cleanups, 2); XCTAssertNil(store.image(old.id)); XCTAssertNil(store.draft(old.id))
        XCTAssertNotNil(store.image(currentButOutsideVisiblePage.id), "Cleanup may prune only capture IDs actually removed by the Mac, never infer deletion from the 100-item library page")
        XCTAssertTrue(model.sessionNotice?.contains("Moved 2") == true)
    }
    @MainActor func testExternalResetPreservesMissingSourceDraftAndAllowsExplicitDiscard() async throws {
        let (model, root) = try navigationFixture()
        defer { NativeTestProtocol.reply = nil; try? FileManager.default.removeItem(at: root) }
        let old = capture("a", time: 1, saved: true), next = capture("b", time: 2, saved: true), png = samplePNG()
        var changed = false
        NativeTestProtocol.reply = { request in
            if request.url!.path == "/api/library" { return (200, try self.libraryData(changed ? [next] : [old], session: changed ? "session-two" : "session-one")) }
            if changed && request.url!.path.hasSuffix(old.id) { return (404, Data()) }
            return (200, png)
        }
        await model.poll(); await model.open(old)
        model.drawingChanged(PKDrawing(), selectionID: model.selection); model.persist()
        changed = true; await model.poll()
        XCTAssertEqual(model.current?.id, old.id); XCTAssertTrue(model.dirty)
        await model.open(next); model.browse()
        XCTAssertTrue(model.browser?.captures.contains(old) == true, "An orphaned unfinished drawing must remain reachable")
        let restored = await model.open(old)
        XCTAssertTrue(restored); XCTAssertTrue(model.dirty); XCTAssertTrue(model.status.contains("Local draft restored"))
        XCTAssertTrue(model.discardDrawing(old)); XCTAssertFalse(model.dirty); XCTAssertEqual(model.unfinishedDrawingCount, 0)
        let store = try DraftStore(namespace: try XCTUnwrap(model.connection).namespace, root: root)
        XCTAssertNotNil(store.image(old.id), "Discard removes drawing only, not the cached source")
        XCTAssertNil(store.pending(old.id)); XCTAssertNil(model.sessionActionIssue)
    }
    private func requestBody(_ request: URLRequest) throws -> Data {
        if let body = request.httpBody { return body }
        guard let stream = request.httpBodyStream else { return Data() }
        stream.open(); defer { stream.close() }
        var data = Data(), buffer = [UInt8](repeating: 0, count: 4096)
        while stream.hasBytesAvailable {
            let count = stream.read(&buffer, maxLength: buffer.count)
            if count < 0 { throw stream.streamError ?? AppError.message("Unreadable request body") }
            if count == 0 { break }
            data.append(buffer, count: count)
        }
        return data
    }
    func testPairingAcceptsOnlyTheLocalMacLinkAndRemovesTokenFromBaseAddress() throws {
        let value=try Connection.parse("http://192.168.68.57:8765/#pair=unit-test-pairing-key")
        XCTAssertEqual(value.baseURL.absoluteString,"http://192.168.68.57:8765");XCTAssertNil(value.baseURL.fragment)
        for link in ["https://example.com:8765/#pair=unit-test-pairing-key", "http://8.8.8.8:8765/#pair=unit-test-pairing-key", "http://user:pass@192.168.1.2:8765/#pair=unit-test-pairing-key", "http://192.168.1.2:8765/", "http://192.168.1.2:8765/evil#pair=unit-test-pairing-key"] { XCTAssertThrowsError(try Connection.parse(link)) }
    }
    func testImageLimitRejectsUnsafeDimensions() {
        XCTAssertFalse(Capture(id:String(repeating:"a",count:24),title:"huge",width:16000,height:16000,modified:0,saved:false).valid)
        XCTAssertFalse(Capture(id:"../../outside",title:"bad",width:20,height:20,modified:0,saved:false).valid)
    }
    func testNativeUploadUsesAuthenticatedPNGAndStableRetryID() async throws {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [NativeTestProtocol.self]
        let connection = try Connection.parse("http://127.0.0.1:8765/#pair=unit-test-pairing-key")
        let client = MacClient(connection, configuration: config)
        let capture = capture("a", time: 1), submission = UUID().uuidString.lowercased()
        NativeTestProtocol.reply = { request in
            XCTAssertEqual(request.url?.path, "/api/save")
            XCTAssertNil(request.url?.fragment)
            XCTAssertEqual(request.httpMethod, "POST")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer unit-test-pairing-key")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "image/png")
            XCTAssertEqual(request.value(forHTTPHeaderField: "X-Capture-ID"), capture.id)
            XCTAssertEqual(request.value(forHTTPHeaderField: "X-Submission-ID"), submission)
            return (200, try JSONSerialization.data(withJSONObject: ["id": submission, "filename": "test.png"]))
        }
        defer { NativeTestProtocol.reply = nil }
        let result = try await client.save(Data([1, 2, 3]), capture: capture, id: submission)
        let retry = try await client.save(Data([1, 2, 3]), capture: capture, id: submission)
        XCTAssertEqual(result.id, submission); XCTAssertEqual(retry.id, submission)
    }
    func testAuthorizationFailureCannotLookLikeASuccessfulSave() async throws {
        let config = URLSessionConfiguration.ephemeral; config.protocolClasses = [NativeTestProtocol.self]
        let client = MacClient(try Connection.parse("http://127.0.0.1:8765/#pair=unit-test-pairing-key"), configuration: config)
        NativeTestProtocol.reply = { _ in (401, Data()) }; defer { NativeTestProtocol.reply = nil }
        do {
            _ = try await client.save(Data([1]), capture: capture("a", time: 1), id: "retry")
            XCTFail("Unauthorized upload was accepted")
        } catch { XCTAssertTrue(error.localizedDescription.contains("Pair again")) }
    }
    @MainActor func testPencilExportPreservesOriginalDimensionsAndIncludesInk() throws {
        let format=UIGraphicsImageRendererFormat();format.scale=1
        let image=UIGraphicsImageRenderer(size:CGSize(width:120,height:80),format:format).image { context in UIColor.white.setFill();context.fill(CGRect(x:0,y:0,width:120,height:80)) }
        let original=image.pngData()!
        let points=[CGPoint(x:15,y:30),CGPoint(x:95,y:30)].enumerated().map { index,point in PKStrokePoint(location:point,timeOffset:Double(index)*0.1,size:CGSize(width:9,height:9),opacity:1,force:1,azimuth:0,altitude:.pi/2) }
        let stroke=PKStroke(ink:PKInk(.pen,color:.red),path:PKStrokePath(controlPoints:points,creationDate:Date(timeIntervalSince1970:0)))
        let output=try ImageExporter.png(image:image,drawing:PKDrawing(strokes:[stroke]),width:120,height:80)
        let exported=try XCTUnwrap(UIImage(data:output)?.cgImage)
        XCTAssertEqual(exported.width,120);XCTAssertEqual(exported.height,80);XCTAssertNotEqual(output,original);XCTAssertEqual(image.pngData(),original)
        XCTAssertThrowsError(try ImageExporter.png(image:image,drawing:PKDrawing(),width:121,height:80))
    }
    @MainActor func testDraftAndRetryPayloadSurviveRestart() throws {
        let root=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at:root) }
        let store=try DraftStore(namespace:"tests",root:root), capture=capture("a",time:1)
        let metadata=DraftMetadata(capture:capture,dirty:true,submission:"retry-id")
        try store.write(metadata,drawing:PKDrawing());try store.pending(Data([1,2,3]),id:capture.id)
        try store.session(SessionMetadata(queue:CaptureQueue(ids:[capture.id]),currentID:capture.id))
        let reopened=try DraftStore(namespace:"tests",root:root)
        XCTAssertEqual(reopened.draft(capture.id)?.submission,"retry-id");XCTAssertEqual(reopened.draft(capture.id)?.dirty,true)
        XCTAssertEqual(reopened.pending(capture.id),Data([1,2,3]));XCTAssertEqual(reopened.session().currentID,capture.id)
    }
}

private final class NativeTestProtocol: URLProtocol {
    static var reply: ((URLRequest) throws -> (Int, Data))?
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        do {
            let (code, data) = try Self.reply!(request)
            let response = HTTPURLResponse(url: request.url!, statusCode: code, httpVersion: "HTTP/1.1", headerFields: nil)!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data); client?.urlProtocolDidFinishLoading(self)
        } catch { client?.urlProtocol(self, didFailWithError: error) }
    }
    override func stopLoading() {}
}
