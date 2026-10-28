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
