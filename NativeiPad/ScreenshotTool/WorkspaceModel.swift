import SwiftUI
import PencilKit

@MainActor final class WorkspaceModel: ObservableObject {
    @Published var connection: Connection?
    @Published var captures: [Capture] = []
    @Published var queue = CaptureQueue()
    @Published var current: Capture?
    @Published var image: UIImage?
    @Published var drawing = PKDrawing()
    @Published var selection = UUID()
    @Published var busy = false
    @Published var dirty = false
    @Published var connected = false
    @Published var status = "Connect to Fatty Lumpkin on your Mac."
    @Published var error: String?
    @Published var fingerDrawing = false
    @Published var showPairing = false
    @Published var canUndo = false
    @Published var canRedo = false
    @Published var completedMessage: String?
    @Published private(set) var pairingAddress: String?
    private var pendingPairingLink: String?
    weak var canvas: PKCanvasView?
    var fitCanvas: (() -> Void)?
    private var client: MacClient?
    private var drafts: DraftStore?
    private var locallySaved: Set<String> = []
    private var submission: String?
    private var polling = false
    private var manualSelection = false
    private var revision = 0
    private var draftTask: Task<Void, Never>?
    @Published private(set) var loadingID: String?
    @Published var browser: CaptureBrowserSnapshot?
    private let configuration: URLSessionConfiguration
    private let draftRoot: URL?
    private var acknowledgement: String?
    private var acknowledgementStarted: Date?

    init(connection: Connection? = ConnectionVault.read(), configuration: URLSessionConfiguration = .ephemeral, draftRoot: URL? = nil) {
        self.configuration = configuration; self.draftRoot = draftRoot
        if let connection { configure(connection) }
        else { showPairing = true }
    }
    var next: Capture? { queue.pending(captures, locallySaved: locallySaved).first { $0.id != current?.id } }
    var actionTitle: String { busy ? "Saving…" : next == nil ? "Done" : "Done & Next" }
    var position: String { current.map { queue.position($0.id) } ?? "No pending screenshots" }
    var pending: [Capture] { queue.pending(captures, locallySaved: locallySaved) }

    var orderedCaptures: [Capture] { captures.sorted(by: Capture.oldestFirst) }
    var previousCapture: Capture? { neighbor(-1) }
    var followingCapture: Capture? { neighbor(1) }
    var navigationPosition: String {
        let ordered = orderedCaptures
        guard let id = current?.id, let index = ordered.firstIndex(where: { $0.id == id }) else { return "Screenshots (\(ordered.count))" }
        return "\(index + 1) of \(ordered.count)"
    }
    private func neighbor(_ offset: Int) -> Capture? {
        let ordered = orderedCaptures
        guard let id = current?.id, let index = ordered.firstIndex(where: { $0.id == id }), ordered.indices.contains(index + offset) else { return nil }
        return ordered[index + offset]
    }
    func browse() {
        guard !busy, loadingID == nil else { return }
        persist(); error = nil
        browser = CaptureBrowserSnapshot(captures: orderedCaptures, selectedID: current?.id,
            draftIDs: Set(captures.filter { drafts?.draft($0.id)?.dirty == true }.map(\.id)))
    }

    private func configure(_ value: Connection) {
        revision += 1; connection = value; client = MacClient(value, configuration: configuration); locallySaved = []; browser = nil
        current = nil; image = nil; drawing = PKDrawing(); dirty = false; acknowledgement = nil
        do {
            drafts = try DraftStore(namespace: value.namespace, root: draftRoot)
            let session = drafts!.session(); queue = session.queue
            if let id = session.currentID, let draft = drafts?.draft(id), draft.dirty, let image = drafts?.image(id) {
                current = draft.capture; self.image = image; drawing = drafts!.drawing(id); dirty = true; submission = draft.submission; selection = UUID()
                status = "Your unfinished drawing is restored. Connecting to your Mac…"
            } else { status = "Connecting to your Mac…" }
        } catch { self.error = "Could not open local drafts: " + error.localizedDescription }
    }
    func pair(_ text: String) async {
        guard !busy else { return }
        busy = true; error = nil; defer { busy = false }
        do {
            let candidate = try Connection.parse(text)
            pendingPairingLink = text; pairingAddress = candidate.displayName
            _ = try await MacClient(candidate).library()
            persist()
            try ConnectionVault.write(candidate)
            configure(candidate); connected = true; showPairing = false; error = nil; pendingPairingLink = nil; pairingAddress = nil
        } catch {
            if (error as? URLError)?.code == .timedOut {
                self.error = "Could not reach the Mac at \(pairingAddress ?? "its local address"). Check that both devices are on the same local network, then tap Retry connection."
            } else { self.error = friendly(error) }
        }
    }
    func retryPairing() async { if let link = pendingPairingLink { await pair(link) } }
    func poll() async {
        guard let client, !polling, !busy else { return }
        polling = true; defer { polling = false }
        let requestRevision = revision
        do {
            let list = try await client.library()
            guard !busy, loadingID == nil, revision == requestRevision else { return }
            let updated = list.map { capture in var c = capture; if locallySaved.contains(c.id) { c.saved = true }; return c }
            // Do not rebuild controls for a library response that has not changed.
            if captures != updated { captures = updated }
            queue.merge(captures, locallySaved: locallySaved); connected = true
            if browser == nil, current == nil, let first = pending.first { await open(first, manual: false) }
            else if current == nil, completedMessage == nil { status = "Ready for your next screenshot." }
            else if browser == nil, let current, !dirty, !manualSelection, current.saved, let first = pending.first { await open(first, manual: false) }
            persistSession()
            if let expected = acknowledgement {
                let result = try await client.status()
                guard acknowledgement == expected else { return }
                if result.lastCopied == expected {
                    status = "Copied on your Mac. Paste into your agent."
                    acknowledgement = nil
                } else if Date().timeIntervalSince(acknowledgementStarted ?? Date()) > 12 {
                    status = "Saved in the Mac’s Ready folder. Use Copy Image in the Mac app if you need the clipboard."
                    acknowledgement = nil
                }
            }
        } catch {
            connected = false
            status = current == nil ? "Mac unavailable. Keep Fatty Lumpkin open on the same network." : "Connection interrupted. Your drawing is kept on this iPad."
        }
    }
    @discardableResult func open(_ capture: Capture, manual: Bool = true) async -> Bool {
        guard !busy, loadingID == nil else { return false }
        if capture.id == current?.id { manualSelection = manual; return true }
        revision += 1 // An older library request must not take over a manual selection.
        return await load(capture, manual: manual)
    }
    @discardableResult private func load(_ capture: Capture, manual: Bool) async -> Bool {
        guard let client, let drafts else { return false }
        if let canvas, dirty { drawing = canvas.drawing }
        persist(); loadingID = capture.id; error = nil; defer { loadingID = nil }
        let requestRevision = revision
        do {
            let bytes = try await client.image(capture)
            guard requestRevision == revision else { return false }
            guard let image = UIImage(data: bytes), image.cgImage?.width == capture.width, image.cgImage?.height == capture.height else { throw AppError.message("The screenshot could not be opened.") }
            try drafts.store(capture, image: bytes)
            canvas = nil; fitCanvas = nil
            self.current = capture; self.image = image; drawing = drafts.drawing(capture.id)
            let prior = drafts.draft(capture.id); dirty = prior?.dirty ?? false; submission = prior?.submission
            manualSelection = manual; completedMessage = nil; acknowledgement = nil; selection = UUID()
            canUndo = false; canRedo = false; status = dirty ? "Your unfinished drawing is restored." : "Draw with Pencil. Use two fingers to move and zoom."
            persistSession()
            return true
        } catch { self.error = friendly(error); return false }
    }
    func drawingChanged(_ value: PKDrawing, selectionID: UUID) {
        guard selection == selectionID, current != nil, !busy, loadingID == nil else { return }
        drawing = value; dirty = true; submission = nil
        canUndo = canvas?.undoManager?.canUndo ?? false; canRedo = canvas?.undoManager?.canRedo ?? false
        draftTask?.cancel()
        draftTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(250))
            guard !Task.isCancelled else { return }; self?.persist()
        }
    }
    func persist() {
        draftTask?.cancel(); draftTask = nil
        guard let current, let drafts else { persistSession(); return }
        do { try drafts.write(DraftMetadata(capture: current, dirty: dirty, submission: submission), drawing: drawing); persistSession() }
        catch { self.error = "Your drawing is in memory, but could not be saved on this iPad. Keep the app open and tap Done. " + error.localizedDescription }
    }
    private func persistSession() {
        do { try drafts?.session(SessionMetadata(queue: queue, currentID: current?.id)) }
        catch { self.error = "Could not remember the current queue. " + error.localizedDescription }
    }
    func undo() { canvas?.undoManager?.undo() }
    func redo() { canvas?.undoManager?.redo() }
    func finish() async {
        guard let capture = current, let image, let client, let drafts, !busy, loadingID == nil else { return }
        // Capture any final stroke before disabling interaction.
        if let canvas { drawing = canvas.drawing }
        busy = true; revision += 1; error = nil; persist()
        defer { busy = false }
        do {
            status = "Creating your finished image…"
            await Task.yield()
            let id: String, bytes: Data
            if let previous = submission, let cached = drafts.pending(capture.id) { id = previous; bytes = cached }
            else {
                id = UUID().uuidString.lowercased()
                bytes = try ImageExporter.png(image: image, drawing: drawing, width: capture.width, height: capture.height)
                try drafts.pending(bytes, id: capture.id)
                submission = id
                try drafts.write(DraftMetadata(capture: capture, dirty: true, submission: id), drawing: drawing)
            }
            status = "Sending to your Mac…"
            let receipt = try await client.save(bytes, capture: capture, id: id)
            guard receipt.id == id else { throw AppError.message("The Mac returned an unexpected save confirmation. Your draft is kept here.") }
            locallySaved.insert(capture.id)
            if let index = captures.firstIndex(where: { $0.id == capture.id }) { captures[index].saved = true }
            current?.saved = true; dirty = false; submission = nil; persist()
            if let next = pending.first {
                await load(next, manual: false)
            } else {
                let count = max(1, queue.ids.count)
                current = nil; self.image = nil; drawing = PKDrawing(); canvas = nil; selection = UUID()
                queue = CaptureQueue(); manualSelection = false; canUndo = false; canRedo = false
                completedMessage = count > 1 ? "All \(count) screenshots saved. Drag the PNGs together from Documents → Screenshot Tool → Ready on your Mac. The clipboard holds only the last image." : "Your annotated PNG is saved in Documents → Screenshot Tool → Ready on your Mac."
                acknowledgement = receipt.id; acknowledgementStarted = Date(); status = "Saved on your Mac. Checking the clipboard…"; persistSession()
            }
        } catch { self.error = friendly(error); status = "Save did not finish. Your drawing is kept here; tap Done to retry." }
    }
    func friendly(_ error: Error) -> String {
        if let url = error as? URLError {
            switch url.code {
            case .timedOut: return "The Mac took too long to respond. Keep Fatty Lumpkin open and try again. Your drawing is kept here."
            case .notConnectedToInternet, .cannotConnectToHost, .cannotFindHost, .networkConnectionLost:
                return "Could not reach your Mac. Keep both devices on the same local network and allow Local Network access for this app in Settings."
            default: return "Connection failed. Check the Mac app and your local network, then try again."
            }
        }
        return error.localizedDescription
    }
}
