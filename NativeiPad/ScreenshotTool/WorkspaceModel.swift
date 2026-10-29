import SwiftUI
import PencilKit

struct TextNoteEditor: Identifiable {
    let id = UUID()
    var note: TextNote
    let captureID: String
    let selectionID: UUID
    let isNew: Bool
}

@MainActor final class WorkspaceModel: ObservableObject {
    @Published var connection: Connection?
    @Published var captures: [Capture] = []
    @Published var queue = CaptureQueue()
    @Published var current: Capture?
    @Published var image: UIImage?
    @Published var drawing = PKDrawing()
    @Published private(set) var notes: [TextNote] = []
    @Published var noteMode = false
    @Published private(set) var noteEditor: TextNoteEditor?
    @Published var selection = UUID()
    @Published var busy = false
    @Published var dirty = false
    @Published var connected = false
    @Published var status = "Connect to Ludwig's Annotated Screenshots on your Mac."
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
    @Published var showSessionManager = false
    @Published var showClearQueueConfirmation = false
    @Published var showLudwigAbout = false
    @Published private(set) var completedCaptureCount = 0
    @Published private(set) var librarySession: LibrarySession?
    @Published private(set) var supportsSessions = false
    @Published private(set) var cleanupPreview: CleanupPreview?
    @Published private(set) var sessionNotice: String?
    private let configuration: URLSessionConfiguration
    private let draftRoot: URL?
    private var acknowledgement: String?
    private var acknowledgementStarted: Date?
    private var librarySessionID: String?
    private var pendingResetID: String?
    private let fallbackUndoManager = UndoManager()

    init(connection: Connection? = ConnectionVault.read(), configuration: URLSessionConfiguration = .ephemeral, draftRoot: URL? = nil) {
        self.configuration = configuration; self.draftRoot = draftRoot
        if let connection { configure(connection) }
        else { showPairing = true }
    }
    var next: Capture? { queue.pending(captures, locallySaved: locallySaved).first { $0.id != current?.id } }
    var actionTitle: String { busy ? "Working…" : next == nil ? "Done" : "Done & Next" }
    var position: String { current.map { queue.position($0.id) } ?? "No pending screenshots" }
    var pending: [Capture] { queue.pending(captures, locallySaved: locallySaved) }

    var orderedCaptures: [Capture] { captures.sorted(by: Capture.oldestFirst) }
    var previousCapture: Capture? { neighbor(-1) }
    var followingCapture: Capture? { neighbor(1) }
    var navigationPosition: String {
        let ordered = orderedCaptures
        guard let id = current?.id, let index = ordered.firstIndex(where: { $0.id == id }) else { return "\(ordered.count) screenshots" }
        return "\(index + 1) of \(ordered.count)"
    }
    private func neighbor(_ offset: Int) -> Capture? {
        let ordered = orderedCaptures
        // Done clears the canvas, but saved captures remain available for browsing.
        guard let current else { return offset < 0 ? ordered.last : ordered.first }
        guard let index = ordered.firstIndex(where: { $0.id == current.id }), ordered.indices.contains(index + offset) else { return nil }
        return ordered[index + offset]
    }
    func browse() {
        guard !busy, loadingID == nil, noteEditor == nil else { return }
        guard persist() else { return }; error = nil
        let unfinished = drafts?.unfinishedIDs() ?? []
        let missingDrafts = unfinished.subtracting(Set(captures.map(\.id))).compactMap { drafts?.draft($0)?.capture }
        browser = CaptureBrowserSnapshot(captures: (captures + missingDrafts).sorted(by: Capture.oldestFirst), selectedID: current?.id, draftIDs: unfinished)
    }
    var hasBrowsableCaptures: Bool { !captures.isEmpty || unfinishedDrawingCount > 0 }

    var unfinishedDrawingCount: Int {
        var ids = drafts?.unfinishedIDs() ?? []
        if let current, dirty || submission != nil { ids.insert(current.id) }
        return ids.count
    }
    var clearQueueIssue: String? {
        if !connected { return "Connect to your Mac to manage sessions." }
        if !supportsSessions { return "Update the Mac companion to version 0.5.0 or later to manage sessions. Your screenshots and drawings are kept." }
        if acknowledgement != nil { return "Wait for the Mac’s clipboard confirmation before changing sessions." }
        return nil
    }
    var sessionActionIssue: String? {
        if let issue = clearQueueIssue { return issue }
        if unfinishedDrawingCount > 0 { return "Finish your unfinished drawings with Done before changing sessions. Find them under Browse → To do. If a source was removed from your Mac, you can explicitly discard that drawing there." }
        return nil
    }
    func manageSession() {
        guard !busy, loadingID == nil, noteEditor == nil else { return }
        guard persist() else { return }; error = nil; cleanupPreview = nil; sessionNotice = nil; showSessionManager = true
    }
    func requestClearQueue() {
        guard !busy, loadingID == nil, noteEditor == nil, !captures.isEmpty || current != nil else { return }
        if let issue = clearQueueIssue { error = issue; return }
        error = nil; showClearQueueConfirmation = true
    }
    func clearQueue() async {
        guard !busy, loadingID == nil, noteEditor == nil else { return }
        if let issue = clearQueueIssue { error = issue; return }
        guard let client, let drafts else { error = "Could not open local drafts. Your queue has not changed."; return }
        busy = true; revision += 1; error = nil; cleanupPreview = nil
        draftTask?.cancel(); draftTask = nil
        defer { busy = false }
        do {
            // Snapshot the final Pencil stroke and require durable local storage before resetting the Mac.
            if let canvas, canvas.drawing.dataRepresentation() != drawing.dataRepresentation() {
                drawing = canvas.drawing; dirty = true; submission = nil
            }
            if let current {
                try drafts.write(DraftMetadata(capture: current, dirty: dirty, submission: submission, notes: notes), drawing: drawing)
            }
            if pendingResetID == nil { pendingResetID = UUID().uuidString.lowercased() }
            try drafts.session(SessionMetadata(queue: queue, currentID: current?.id, librarySessionID: librarySessionID, pendingResetID: pendingResetID))
            let result = try await client.newSession(requestID: pendingResetID!)
            guard result.supportsSessions == true, result.session != nil else {
                throw AppError.message("The Mac did not confirm the cleared queue. Try again; the same request will be reused.")
            }
            clearSelection(); queue = CaptureQueue(); locallySaved = []; browser = nil
            applyLibrary(result); pendingResetID = nil; persistSession()
            status = "Queue cleared. Ready for your next screenshot."
            sessionNotice = "The count is 0. Files stay on your Mac; unfinished drawings stay under Browse → To do."
        } catch {
            self.error = "The queue could not be cleared. Your drawing is kept here. " + friendly(error)
        }
    }
    func startNewSession() async {
        guard let client, !busy, loadingID == nil, noteEditor == nil else { return }
        if let issue = sessionActionIssue { error = issue; return }
        guard persist() else { return }; busy = true; revision += 1; error = nil; cleanupPreview = nil
        if pendingResetID == nil { pendingResetID = UUID().uuidString.lowercased() }
        persistSession()
        defer { busy = false }
        do {
            let result = try await client.newSession(requestID: pendingResetID!)
            guard result.supportsSessions == true, result.session != nil else { throw AppError.message("The Mac did not confirm the new session. Try again; the same request will be reused.") }
            clearSelection(); queue = CaptureQueue(); locallySaved = []; browser = nil
            applyLibrary(result); pendingResetID = nil; persistSession()
            status = "New session. Ready for your next screenshot."
            sessionNotice = "The count is reset to 0. Previous screenshots and finished PNGs are still on your Mac."
        } catch { self.error = friendly(error) }
    }
    func previewCleanup() async {
        guard let client, !busy, loadingID == nil, noteEditor == nil else { return }
        if let issue = sessionActionIssue { error = issue; return }
        busy = true; error = nil; cleanupPreview = nil; sessionNotice = nil
        defer { busy = false }
        do { cleanupPreview = try await client.cleanupPreview() }
        catch { self.error = friendly(error) }
    }
    func trashPreviousSessions() async {
        guard let client, let preview = cleanupPreview, preview.fileCount > 0, !busy, loadingID == nil, noteEditor == nil else { return }
        if let issue = sessionActionIssue { error = issue; return }
        busy = true; revision += 1; error = nil
        defer { busy = false; cleanupPreview = nil }
        do {
            let receipt = try await client.cleanup(preview)
            sessionNotice = "Moved \(receipt.movedFiles) older files to the Trash on your Mac. This session is kept. You can restore files from the Mac’s Trash."
            if let removed = receipt.movedCaptureIDs {
                try drafts?.removeCleanDrafts(ids: Set(removed))
                if let current, removed.contains(current.id) { clearSelection(); persistSession() }
            }
        } catch { self.error = friendly(error) + " Review older files again before retrying." }
    }
    @discardableResult func discardDrawing(_ capture: Capture) -> Bool {
        guard !busy, loadingID == nil, noteEditor == nil, let drafts else { return false }
        do {
            try drafts.discardDrawing(capture)
            if current?.id == capture.id {
                dirty = false; submission = nil; drawing = PKDrawing(); notes = []; selection = UUID()
                fallbackUndoManager.removeAllActions()
                canUndo = false; canRedo = false; status = "Unfinished drawing discarded. The original screenshot is kept."
            }
            error = nil; persistSession()
            return true
        } catch { self.error = friendly(error); return false }
    }
    private func clearSelection() {
        current = nil; image = nil; drawing = PKDrawing(); notes = []; noteEditor = nil; noteMode = false; dirty = false; submission = nil
        fallbackUndoManager.removeAllActions()
        canvas = nil; fitCanvas = nil; selection = UUID(); manualSelection = false
        canUndo = false; canRedo = false; completedMessage = nil; acknowledgement = nil
    }
    private func applyLibrary(_ result: LibraryResponse) {
        let changedSession = librarySessionID != nil && result.session?.id != nil && librarySessionID != result.session?.id
        supportsSessions = result.supportsSessions == true
        librarySession = result.session; librarySessionID = result.session?.id
        if changedSession {
            queue = CaptureQueue(); locallySaved = []; cleanupPreview = nil
            if dirty || submission != nil {
                status = "A new session started on your Mac. Tap Done to save this unfinished drawing."
            } else { clearSelection() }
        }
        let updated = result.captures.map { capture in var c = capture; if locallySaved.contains(c.id) { c.saved = true }; return c }
        if captures != updated { captures = updated }
        queue.merge(captures, locallySaved: locallySaved)
    }

    private func configure(_ value: Connection) {
        revision += 1; connection = value; client = MacClient(value, configuration: configuration); locallySaved = []; browser = nil
        librarySession = nil; librarySessionID = nil; supportsSessions = false; cleanupPreview = nil; pendingResetID = nil
        current = nil; image = nil; drawing = PKDrawing(); notes = []; noteEditor = nil; noteMode = false; dirty = false; acknowledgement = nil
        fallbackUndoManager.removeAllActions()
        do {
            drafts = try DraftStore(namespace: value.namespace, root: draftRoot)
            let session = drafts!.session(); queue = session.queue
            librarySessionID = session.librarySessionID; pendingResetID = session.pendingResetID
            if let id = session.currentID, let draft = drafts?.draft(id), draft.dirty, let image = drafts?.image(id) {
                current = draft.capture; self.image = image; drawing = drafts!.drawing(id); notes = draft.notes; dirty = true; submission = draft.submission; selection = UUID()
                status = "Your unfinished drawing is restored. Connecting to your Mac…"
            } else { status = "Connecting to your Mac…" }
        } catch { self.error = "Could not open local drafts: " + error.localizedDescription }
    }
    func pair(_ text: String) async {
        guard !busy, noteEditor == nil else { return }
        busy = true; error = nil; defer { busy = false }
        do {
            let candidate = try Connection.parse(text)
            pendingPairingLink = text; pairingAddress = candidate.displayName
            _ = try await MacClient(candidate).library()
            guard persist() else { return }
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
        guard let client, !polling, !busy, noteEditor == nil else { return }
        polling = true; defer { polling = false }
        let requestRevision = revision
        do {
            let result = try await client.libraryState()
            guard !busy, loadingID == nil, noteEditor == nil, revision == requestRevision else { return }
            applyLibrary(result); connected = true
            if browser == nil, !showSessionManager, !showClearQueueConfirmation, !showLudwigAbout, current == nil, let first = pending.first { await open(first, manual: false) }
            else if current == nil, completedMessage == nil { status = "Ready for your next screenshot." }
            else if browser == nil, !showSessionManager, !showClearQueueConfirmation, !showLudwigAbout, let current, !dirty, !manualSelection, current.saved, let first = pending.first { await open(first, manual: false) }
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
            status = current == nil ? "Mac unavailable. Keep Ludwig's Annotated Screenshots open on the same network." : "Connection interrupted. Your drawing is kept on this iPad."
        }
    }
    @discardableResult func open(_ capture: Capture, manual: Bool = true) async -> Bool {
        guard !busy, loadingID == nil, noteEditor == nil else { return false }
        if capture.id == current?.id { manualSelection = manual; return true }
        revision += 1 // An older library request must not take over a manual selection.
        return await load(capture, manual: manual)
    }
    @discardableResult private func load(_ capture: Capture, manual: Bool) async -> Bool {
        guard let client, let drafts else { return false }
        if let canvas, dirty { drawing = canvas.drawing }
        guard persist() else { return false }
        loadingID = capture.id; error = nil; defer { loadingID = nil }
        let requestRevision = revision
        do {
            let bytes: Data
            var restoredLocal = false
            do { bytes = try await client.image(capture) }
            catch {
                guard capture.valid, drafts.draft(capture.id)?.dirty == true, let cached = drafts.imageData(capture.id) else { throw error }
                bytes = cached; restoredLocal = true
            }
            guard requestRevision == revision else { return false }
            guard let image = UIImage(data: bytes), image.cgImage?.width == capture.width, image.cgImage?.height == capture.height else { throw AppError.message("The screenshot could not be opened.") }
            try drafts.store(capture, image: bytes)
            canvas = nil; fitCanvas = nil
            self.current = capture; self.image = image; drawing = drafts.drawing(capture.id)
            let prior = drafts.draft(capture.id); dirty = prior?.dirty ?? false; submission = prior?.submission; notes = prior?.notes ?? []
            noteEditor = nil; noteMode = false; fallbackUndoManager.removeAllActions()
            manualSelection = manual; completedMessage = nil; acknowledgement = nil; selection = UUID()
            canUndo = false; canRedo = false; status = dirty ? "Your unfinished drawing is restored." : "Draw with Pencil. Use two fingers to move and zoom."
            if restoredLocal { status = "Local draft restored. The Mac source is unavailable; retry Done, or discard this drawing in Browse." }
            persistSession()
            return true
        } catch { self.error = friendly(error); return false }
    }
    func drawingChanged(_ value: PKDrawing, selectionID: UUID) {
        guard selection == selectionID, current != nil, !busy, loadingID == nil else { return }
        drawing = value; dirty = true; submission = nil
        refreshUndoState()
        draftTask?.cancel()
        draftTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(250))
            guard !Task.isCancelled else { return }; self?.persist()
        }
    }
    @discardableResult func persist() -> Bool {
        draftTask?.cancel(); draftTask = nil
        guard let current, let drafts else { return persistSession() }
        do { try drafts.write(DraftMetadata(capture: current, dirty: dirty, submission: submission, notes: notes), drawing: drawing); return persistSession() }
        catch { self.error = "Your annotations are in memory, but could not be saved on this iPad. Keep the app open and tap Done. " + error.localizedDescription; return false }
    }
    @discardableResult private func persistSession() -> Bool {
        do { try drafts?.session(SessionMetadata(queue: queue, currentID: current?.id, librarySessionID: librarySessionID, pendingResetID: pendingResetID)); return true }
        catch { self.error = "Could not remember the current queue. " + error.localizedDescription; return false }
    }
    private var activeUndoManager: UndoManager { canvas?.undoManager ?? fallbackUndoManager }
    func refreshUndoState() { canUndo = activeUndoManager.canUndo; canRedo = activeUndoManager.canRedo }
    func undo() {
        guard !busy, loadingID == nil, noteEditor == nil else { return }
        activeUndoManager.undo(); refreshUndoState()
    }
    func redo() {
        guard !busy, loadingID == nil, noteEditor == nil else { return }
        activeUndoManager.redo(); refreshUndoState()
    }

    func toggleNoteMode() {
        guard current != nil, !busy, loadingID == nil, noteEditor == nil else { return }
        snapshotCanvas(); guard persist() else { return }; manualSelection = true; revision += 1
        noteMode.toggle()
        status = noteMode ? "Tap to add a note. Tap a note to edit; drag to move." : "Draw with Pencil. Use two fingers to move and zoom."
    }
    private func snapshotCanvas() {
        if let canvas, canvas.drawing.dataRepresentation() != drawing.dataRepresentation() {
            drawing = canvas.drawing; dirty = true; submission = nil
        }
    }
    func beginNote(at point: CGPoint, selectionID: UUID) {
        guard selectionID == selection, let current, image != nil, !busy, loadingID == nil, noteEditor == nil,
              point.x.isFinite, point.y.isFinite else { return }
        snapshotCanvas(); guard persist() else { return }; manualSelection = true; revision += 1; error = nil; noteMode = true
        let note = TextNote.new(at: point, imageSize: CGSize(width: current.width, height: current.height))
        noteEditor = TextNoteEditor(note: note, captureID: current.id, selectionID: selection, isNew: true)
    }
    func editNote(id: UUID, selectionID: UUID) {
        guard selectionID == selection, let current, !busy, loadingID == nil, noteEditor == nil,
              let note = notes.first(where: { $0.id == id }) else { return }
        snapshotCanvas(); guard persist() else { return }; manualSelection = true; revision += 1; error = nil; noteMode = true
        noteEditor = TextNoteEditor(note: note, captureID: current.id, selectionID: selection, isNew: false)
    }
    func cancelNoteEditing() { noteEditor = nil; error = nil }
    @discardableResult func commitNote(_ proposed: TextNote) -> Bool {
        guard let editor = noteEditor, let current, editor.captureID == current.id, editor.selectionID == selection,
              proposed.id == editor.note.id, !busy, loadingID == nil else { return false }
        var note = proposed; note.text = note.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !note.text.isEmpty else { error = "Speak or type a note first."; return false }
        guard note.text.count <= 1000 else { error = "Keep each note to 1,000 characters or fewer. You can add another note."; return false }
        let size = CGSize(width: current.width, height: current.height)
        note = TextNoteRenderer.normalized(note, imageSize: size)
        guard TextNoteRenderer.fits(note, imageSize: size) else {
            error = "This note is too tall for the screenshot. Choose smaller text or shorten the note."; return false
        }
        var changed = notes
        if editor.isNew { changed.append(note) }
        else {
            guard let index = changed.firstIndex(where: { $0.id == note.id }) else { return false }
            changed[index] = note
        }
        noteEditor = nil; error = nil
        replaceNotes(changed, action: editor.isNew ? "Add note" : "Edit note")
        status = "Note placed. Drag to move, tap to edit, or choose Draw."
        return true
    }
    @discardableResult func deleteEditingNote() -> Bool {
        guard let editor = noteEditor, !editor.isNew, editor.captureID == current?.id, editor.selectionID == selection,
              !busy, loadingID == nil else { return false }
        noteEditor = nil; error = nil
        replaceNotes(notes.filter { $0.id != editor.note.id }, action: "Delete note")
        status = "Note removed. Undo brings it back."
        return true
    }
    func moveNote(id: UUID, to point: CGPoint, selectionID: UUID) {
        guard selectionID == selection, let current, !busy, loadingID == nil, noteEditor == nil,
              point.x.isFinite, point.y.isFinite, let index = notes.firstIndex(where: { $0.id == id }) else { return }
        var changed = notes; changed[index].x = point.x; changed[index].y = point.y
        changed[index] = TextNoteRenderer.normalized(changed[index], imageSize: CGSize(width: current.width, height: current.height))
        replaceNotes(changed, action: "Move note")
    }
    private func replaceNotes(_ value: [TextNote], action: String) {
        guard value != notes else { return }
        let previous = notes, selectionID = selection, manager = activeUndoManager
        let group = !manager.isUndoing && !manager.isRedoing
        if group { manager.beginUndoGrouping() }
        manager.registerUndo(withTarget: self) { target in
            guard target.selection == selectionID else { return }
            target.replaceNotes(previous, action: action)
        }
        manager.setActionName(action)
        if group { manager.endUndoGrouping() }
        snapshotCanvas(); notes = value; dirty = true; submission = nil; revision += 1; manualSelection = true
        persist(); refreshUndoState()
    }
    func finish() async {
        guard let capture = current, let image, let client, let drafts, !busy, loadingID == nil, noteEditor == nil else { return }
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
                bytes = try ImageExporter.png(image: image, drawing: drawing, width: capture.width, height: capture.height, notes: notes)
                try drafts.pending(bytes, id: capture.id)
                submission = id
                try drafts.write(DraftMetadata(capture: capture, dirty: true, submission: id, notes: notes), drawing: drawing)
            }
            status = "Sending to your Mac…"
            let receipt = try await client.save(bytes, capture: capture, id: id)
            guard receipt.id == id else { throw AppError.message("The Mac returned an unexpected save confirmation. Your draft is kept here.") }
            completedCaptureCount += 1
            locallySaved.insert(capture.id)
            if let index = captures.firstIndex(where: { $0.id == capture.id }) { captures[index].saved = true }
            current?.saved = true; dirty = false; submission = nil; persist()
            if let next = pending.first {
                await load(next, manual: false)
            } else {
                let count = max(1, queue.ids.count)
                current = nil; self.image = nil; drawing = PKDrawing(); notes = []; noteEditor = nil; noteMode = false; canvas = nil; selection = UUID()
                fallbackUndoManager.removeAllActions()
                queue = CaptureQueue(); manualSelection = false; canUndo = false; canRedo = false
                completedMessage = count > 1 ? "All \(count) screenshots saved. Drag the PNGs together from Documents → Screenshot Tool → Ready on your Mac. The clipboard holds only the last image." : "Your annotated PNG is saved in Documents → Screenshot Tool → Ready on your Mac."
                acknowledgement = receipt.id; acknowledgementStarted = Date(); status = "Saved on your Mac. Checking the clipboard…"; persistSession()
            }
        } catch { self.error = friendly(error); status = "Save did not finish. Your drawing is kept here; tap Done to retry." }
    }
    func friendly(_ error: Error) -> String {
        if let url = error as? URLError {
            switch url.code {
            case .timedOut: return "The Mac took too long to respond. Keep Ludwig's Annotated Screenshots open and try again. Your drawing is kept here."
            case .notConnectedToInternet, .cannotConnectToHost, .cannotFindHost, .networkConnectionLost:
                return "Could not reach your Mac. Keep both devices on the same local network and allow Local Network access for this app in Settings."
            default: return "Connection failed. Check the Mac app and your local network, then try again."
            }
        }
        return error.localizedDescription
    }
}
