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
    @Published var status = "Connect to Screenshot Tool on your Mac."
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
    private var loadingID: String?
    private var acknowledgement: String?
    private var acknowledgementStarted: Date?

    init() {
        if let connection = ConnectionVault.read() { configure(connection) }
        else { showPairing = true }
    }
    var next: Capture? { queue.pending(captures, locallySaved: locallySaved).first { $0.id != current?.id } }
    var actionTitle: String { busy ? "Saving…" : next == nil ? "Done" : "Done & Next" }
    var position: String { current.map { queue.position($0.id) } ?? "No pending screenshots" }
    var pending: [Capture] { queue.pending(captures, locallySaved: locallySaved) }

    private func configure(_ value: Connection) {
        revision += 1; connection = value; client = MacClient(value); locallySaved = []
        current = nil; image = nil; drawing = PKDrawing(); dirty = false; acknowledgement = nil
        do {
            drafts = try DraftStore(namespace: value.namespace)
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
            guard !busy, revision == requestRevision else { return }
            captures = list.map { capture in var c = capture; if locallySaved.contains(c.id) { c.saved = true }; return c }
            queue.merge(captures, locallySaved: locallySaved); connected = true
            if current == nil, let first = pending.first { await open(first, manual: false) }
            else if current == nil, completedMessage == nil { status = "Ready for your next screenshot." }
            else if let current, !dirty, !manualSelection, current.saved, let first = pending.first { await open(first, manual: false) }
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
            status = current == nil ? "Mac unavailable. Keep Screenshot Tool open on the same network." : "Connection interrupted. Your drawing is kept on this iPad."
        }
    }
    func open(_ capture: Capture, manual: Bool = true) async {
        guard !busy, loadingID == nil else { return }
        await load(capture, manual: manual)
    }
    private func load(_ capture: Capture, manual: Bool) async {
        guard let client, let drafts else { return }
        persist(); loadingID = capture.id; defer { loadingID = nil }
        let requestRevision = revision
        do {
            let bytes = try await client.image(capture)
            guard requestRevision == revision else { return }
            guard let image = UIImage(data: bytes), image.cgImage?.width == capture.width, image.cgImage?.height == capture.height else { throw AppError.message("The screenshot could not be opened.") }
            try drafts.store(capture, image: bytes)
            self.current = capture; self.image = image; drawing = drafts.drawing(capture.id)
            let prior = drafts.draft(capture.id); dirty = prior?.dirty ?? false; submission = prior?.submission
            manualSelection = manual; completedMessage = nil; acknowledgement = nil; selection = UUID()
            canUndo = false; canRedo = false; status = dirty ? "Your unfinished drawing is restored." : "Draw with Pencil. Use two fingers to move and zoom."
            persistSession()
        } catch { self.error = friendly(error) }
    }
    func drawingChanged(_ value: PKDrawing, selectionID: UUID) {
        guard selection == selectionID, current != nil, !busy else { return }
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
            case .timedOut: return "The Mac took too long to respond. Keep Screenshot Tool open and try again. Your drawing is kept here."
            case .notConnectedToInternet, .cannotConnectToHost, .cannotFindHost, .networkConnectionLost:
                return "Could not reach your Mac. Keep both devices on the same local network and allow Local Network access for this app in Settings."
            default: return "Connection failed. Check the Mac app and your local network, then try again."
            }
        }
        return error.localizedDescription
    }
}
