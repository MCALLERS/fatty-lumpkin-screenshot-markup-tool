import SwiftUI
import PencilKit

struct PencilSurface: UIViewControllerRepresentable {
    @ObservedObject var model: WorkspaceModel
    func makeUIViewController(context: Context) -> DrawingController { DrawingController() }
    func updateUIViewController(_ controller: DrawingController, context: Context) {
        guard let image = model.image, let capture = model.current else { return }
        let selection = model.selection
        controller.changed = { [weak model] drawing in
            model?.drawingChanged(drawing, selectionID: selection)
            model?.refreshUndoState()
        }
        controller.newNote = { [weak model] point in model?.beginNote(at: point, selectionID: selection) }
        controller.editNote = { [weak model] id in model?.editNote(id: id, selectionID: selection) }
        controller.moveNote = { [weak model] id, point in model?.moveNote(id: id, to: point, selectionID: selection) }
        controller.configure(image: image, size: CGSize(width: capture.width, height: capture.height), drawing: model.drawing, notes: model.notes, selection: selection)
        controller.canvas.drawingPolicy = model.fingerDrawing ? .anyInput : .pencilOnly
        controller.setInteraction(active: !model.busy && model.loadingID == nil && model.browser == nil && !model.showPairing && !model.showSessionManager && !model.showClearQueueConfirmation && !model.showLudwigAbout && model.noteEditor == nil, noteMode: model.noteMode)
        model.canvas = controller.canvas
        model.fitCanvas = { [weak controller] in controller?.fit() }
    }
}
final class DrawingController: UIViewController, UIScrollViewDelegate, PKCanvasViewDelegate {
    let scroll = UIScrollView()
    let sheet = UIView()
    let background = UIImageView()
    let canvas = PKCanvasView()
    let picker = PKToolPicker()
    var changed: ((PKDrawing) -> Void)?
    var newNote: ((CGPoint) -> Void)?
    var editNote: ((UUID) -> Void)?
    var moveNote: ((UUID, CGPoint) -> Void)?
    private let notesOverlay = TextNotesOverlay()
    private var selection: UUID?
    private var needsFit = true
    private var settingDrawing = false
    private var lastSize = CGSize.zero
    private var surfaceActive = true
    private var noteMode = false

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor(red: 0.94, green: 0.94, blue: 0.91, alpha: 1)
        scroll.delegate = self; scroll.alwaysBounceVertical = true; scroll.alwaysBounceHorizontal = true
        scroll.panGestureRecognizer.minimumNumberOfTouches = 2
        scroll.panGestureRecognizer.allowedTouchTypes = [NSNumber(value: UITouch.TouchType.direct.rawValue)]
        view.addSubview(scroll); scroll.addSubview(sheet)
        sheet.backgroundColor = .white; sheet.layer.shadowOpacity = 0.12; sheet.layer.shadowRadius = 16
        background.contentMode = .scaleToFill; sheet.addSubview(background)
        canvas.isOpaque = false; canvas.backgroundColor = .clear; canvas.isScrollEnabled = false
        canvas.drawingPolicy = .pencilOnly; canvas.delegate = self
        canvas.tool = PKInkingTool(.pen, color: .systemRed, width: 5)
        sheet.addSubview(canvas); picker.addObserver(canvas)
        canvas.accessibilityLabel = "Pencil drawing surface"
        sheet.addSubview(notesOverlay)
        notesOverlay.newNote = { [weak self] point in self?.newNote?(point) }
        notesOverlay.editNote = { [weak self] id in self?.editNote?(id) }
        notesOverlay.moveNote = { [weak self] id, point in self?.moveNote?(id, point) }
        notesOverlay.scroll = scroll
    }
    override func viewDidAppear(_ animated: Bool) { super.viewDidAppear(animated); updateDrawingFocus() }
    func setInteraction(active: Bool, noteMode: Bool) {
        loadViewIfNeeded()
        view.isUserInteractionEnabled = active
        let changed = surfaceActive != active || self.noteMode != noteMode
        surfaceActive = active; self.noteMode = noteMode
        notesOverlay.setEditing(active && noteMode)
        canvas.isUserInteractionEnabled = active && !noteMode
        canvas.accessibilityElementsHidden = noteMode
        guard changed else { return }
        if view.window != nil { updateDrawingFocus() }
    }
    private func updateDrawingFocus() {
        let drawingActive = surfaceActive && !noteMode
        picker.setVisible(drawingActive, forFirstResponder: canvas)
        if drawingActive {
            if !canvas.isFirstResponder { canvas.becomeFirstResponder() }
        } else if canvas.isFirstResponder { canvas.resignFirstResponder() }
    }
    override func viewWillDisappear(_ animated: Bool) { super.viewWillDisappear(animated); picker.setVisible(false, forFirstResponder: canvas); canvas.resignFirstResponder() }
    func configure(image: UIImage, size: CGSize, drawing: PKDrawing, notes: [TextNote], selection: UUID) {
        loadViewIfNeeded()
        if self.selection != selection {
            notesOverlay.reset()
            self.selection = selection; scroll.zoomScale = 1
            sheet.frame = CGRect(origin: .zero, size: size); background.frame = sheet.bounds; canvas.frame = sheet.bounds
            notesOverlay.frame = sheet.bounds
            canvas.contentSize = size; background.image = image; scroll.contentSize = size
            settingDrawing = true; canvas.drawing = drawing; canvas.undoManager?.removeAllActions(); settingDrawing = false
            needsFit = true; view.setNeedsLayout()
        }
        notesOverlay.configure(notes: notes, imageSize: size)
    }
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews(); scroll.frame = view.bounds
        if needsFit || lastSize != view.bounds.size { lastSize = view.bounds.size; fit(); needsFit = false }
        centerSheet()
    }
    func fit() {
        guard sheet.bounds.width > 0, scroll.bounds.width > 0 else { return }
        let scale = min(1, max(0.03, min((scroll.bounds.width - 48) / sheet.bounds.width, (scroll.bounds.height - 100) / sheet.bounds.height)))
        scroll.minimumZoomScale = scale * 0.5; scroll.maximumZoomScale = max(4, scale * 4); scroll.setZoomScale(scale, animated: false); centerSheet()
    }
    func viewForZooming(in scrollView: UIScrollView) -> UIView? { sheet }
    func scrollViewDidZoom(_ scrollView: UIScrollView) {
        centerSheet()
        notesOverlay.setDisplayScale((view.window?.screen.scale ?? 2) * min(4, scrollView.zoomScale))
    }
    private func centerSheet() {
        let x = max(24, (scroll.bounds.width - scroll.contentSize.width) / 2)
        let y = max(24, (scroll.bounds.height - scroll.contentSize.height) / 2)
        scroll.contentInset = UIEdgeInsets(top: y, left: x, bottom: max(80, y), right: x)
    }
    func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) { if !settingDrawing { changed?(canvasView.drawing) } }
}

// This layer shares the screenshot's coordinate space and never modifies PKDrawing.
private final class TextNotesOverlay: UIView, UIGestureRecognizerDelegate {
    weak var scroll: UIScrollView?
    var newNote: ((CGPoint) -> Void)?
    var editNote: ((UUID) -> Void)?
    var moveNote: ((UUID, CGPoint) -> Void)?
    private var noteViews: [UUID: TextNoteView] = [:]
    private var noteOrder: [UUID] = []
    private var editing = false
    private var displayScale: CGFloat = 2
    private lazy var emptyTap = UITapGestureRecognizer(target: self, action: #selector(tappedEmpty(_:)))
    private lazy var addNoteElement = TextNotePlacementElement(accessibilityContainer: self)

    override init(frame: CGRect) {
        super.init(frame: frame)
        isOpaque = false
        isUserInteractionEnabled = false
        emptyTap.delegate = self
        addGestureRecognizer(emptyTap)
        addNoteElement.accessibilityLabel = "Add text note at center"
        addNoteElement.accessibilityHint = "Opens a text editor. You can move the note after adding it."
        addNoteElement.accessibilityTraits = .button
        addNoteElement.activate = { [weak self] in
            guard let self, self.editing else { return false }
            self.newNote?(CGPoint(x: self.bounds.midX, y: self.bounds.midY))
            return true
        }
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func reset() {
        for item in noteViews.values { item.cancelDrag(); item.removeFromSuperview() }
        noteViews.removeAll(); noteOrder.removeAll()
        updateAccessibilityElements()
    }
    func configure(notes: [TextNote], imageSize: CGSize) {
        noteOrder = notes.map(\.id)
        let ids = Set(notes.map(\.id))
        for id in Array(noteViews.keys) where !ids.contains(id) {
            noteViews[id]?.cancelDrag(); noteViews.removeValue(forKey: id)?.removeFromSuperview()
        }
        for note in notes {
            let item: TextNoteView
            if let existing = noteViews[note.id] { item = existing }
            else {
                item = TextNoteView(note: note, imageSize: imageSize)
                item.edit = { [weak self] id in self?.editNote?(id) }
                item.move = { [weak self] id, point in self?.moveNote?(id, point) }
                item.scroll = scroll
                noteViews[note.id] = item; addSubview(item)
            }
            item.configure(note: note, imageSize: imageSize)
            item.setEditing(editing)
            item.setDisplayScale(displayScale)
            bringSubviewToFront(item)
        }
        updateAccessibilityElements()
    }
    func setEditing(_ enabled: Bool) {
        guard editing != enabled else { return }
        editing = enabled
        isUserInteractionEnabled = enabled
        for item in noteViews.values { item.setEditing(enabled) }
        updateAccessibilityElements()
    }
    func setDisplayScale(_ scale: CGFloat) {
        displayScale = max(1, scale)
        for item in noteViews.values { item.setDisplayScale(displayScale) }
    }
    override func layoutSubviews() {
        super.layoutSubviews()
        addNoteElement.accessibilityFrameInContainerSpace = bounds
    }
    private func updateAccessibilityElements() {
        // Existing notes precede the canvas-wide placement target so they remain reachable.
        var elements: [Any] = noteOrder.compactMap { noteViews[$0] }
        if editing { elements.append(addNoteElement) }
        accessibilityElements = elements
        addNoteElement.accessibilityFrameInContainerSpace = bounds
    }
    @objc private func tappedEmpty(_ recognizer: UITapGestureRecognizer) {
        guard editing, recognizer.state == .ended else { return }
        let point = recognizer.location(in: self)
        guard bounds.contains(point) else { return }
        newNote?(point)
    }
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        var target = touch.view
        while let view = target, view !== self {
            if view is TextNoteView { return false }
            target = view.superview
        }
        return editing
    }
}

private final class TextNotePlacementElement: UIAccessibilityElement {
    var activate: (() -> Bool)?
    override func accessibilityActivate() -> Bool { activate?() ?? false }
}

private final class TextNoteView: UIView, UIGestureRecognizerDelegate {
    weak var scroll: UIScrollView?
    var edit: ((UUID) -> Void)?
    var move: ((UUID, CGPoint) -> Void)?
    private var note: TextNote
    private var imageSize: CGSize
    private var editing = false
    private var dragStart: TextNote?
    private var preview: TextNote?
    private lazy var tap = UITapGestureRecognizer(target: self, action: #selector(tapped))
    private lazy var pan = UIPanGestureRecognizer(target: self, action: #selector(dragged(_:)))

    init(note: TextNote, imageSize: CGSize) {
        self.note = note; self.imageSize = imageSize
        super.init(frame: TextNoteRenderer.rect(for: note, imageSize: imageSize))
        isOpaque = false
        isAccessibilityElement = true
        contentMode = .redraw
        pan.maximumNumberOfTouches = 1
        pan.delegate = self
        tap.require(toFail: pan)
        addGestureRecognizer(pan); addGestureRecognizer(tap)
        accessibilityLabel = "Text note: \(note.text)"
        updateAccessibility()
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func configure(note: TextNote, imageSize: CGSize) {
        guard self.note != note || self.imageSize != imageSize else { return }
        self.note = note; self.imageSize = imageSize
        if dragStart == nil { updateFrame() }
        accessibilityLabel = "Text note: \(note.text)"
        updateAccessibility()
        setNeedsDisplay()
    }
    func setEditing(_ enabled: Bool) {
        guard editing != enabled else { return }
        editing = enabled
        if !enabled { cancelDrag() }
        pan.isEnabled = enabled; tap.isEnabled = enabled
        updateAccessibility()
    }
    func setDisplayScale(_ scale: CGFloat) {
        guard contentScaleFactor != scale else { return }
        contentScaleFactor = scale; setNeedsDisplay()
    }
    private func updateFrame() {
        frame = TextNoteRenderer.rect(for: preview ?? note, imageSize: imageSize)
        setNeedsDisplay()
    }
    override func draw(_ rect: CGRect) {
        guard let context = UIGraphicsGetCurrentContext() else { return }
        let shown = preview ?? note
        let sourceRect = TextNoteRenderer.rect(for: shown, imageSize: imageSize)
        context.saveGState()
        context.translateBy(x: -sourceRect.minX, y: -sourceRect.minY)
        TextNoteRenderer.draw(shown, in: imageSize)
        context.restoreGState()
    }
    @objc private func tapped() { if editing { edit?(note.id) } }
    @objc private func dragged(_ recognizer: UIPanGestureRecognizer) {
        guard editing, let parent = superview else { return }
        switch recognizer.state {
        case .began:
            dragStart = note; preview = note
        case .changed:
            guard var proposed = dragStart else { return }
            let delta = recognizer.translation(in: parent)
            proposed.x += Double(delta.x); proposed.y += Double(delta.y)
            preview = TextNoteRenderer.normalized(proposed, imageSize: imageSize)
            updateFrame()
        case .ended:
            guard let start = dragStart else { return }
            var final = start
            let delta = recognizer.translation(in: parent)
            final.x += Double(delta.x); final.y += Double(delta.y)
            let proposed = TextNoteRenderer.normalized(final, imageSize: imageSize)
            dragStart = nil; preview = nil
            if proposed.x != start.x || proposed.y != start.y {
                // Keep the final preview until SwiftUI applies the model's committed value.
                note = proposed; updateFrame()
                move?(proposed.id, CGPoint(x: proposed.x, y: proposed.y))
            } else { updateFrame() }
        case .cancelled, .failed:
            dragStart = nil; preview = nil; updateFrame()
        default: break
        }
    }
    func cancelDrag() {
        dragStart = nil; preview = nil
        // Cancelling a recognizer never commits an annotation move.
        pan.isEnabled = false; pan.isEnabled = editing
        updateFrame()
    }
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool {
        other === scroll?.panGestureRecognizer || other === scroll?.pinchGestureRecognizer
    }
    private func updateAccessibility() {
        accessibilityTraits = editing ? [.button] : [.staticText]
        accessibilityHint = editing ? "Double tap to edit. Drag to move, or use the move actions." : "Select the Text note tool to edit or move this note."
        accessibilityCustomActions = editing ? [
            UIAccessibilityCustomAction(name: "Move left") { [weak self] _ in self?.moveAccessibly(dx: -1, dy: 0) ?? false },
            UIAccessibilityCustomAction(name: "Move right") { [weak self] _ in self?.moveAccessibly(dx: 1, dy: 0) ?? false },
            UIAccessibilityCustomAction(name: "Move up") { [weak self] _ in self?.moveAccessibly(dx: 0, dy: -1) ?? false },
            UIAccessibilityCustomAction(name: "Move down") { [weak self] _ in self?.moveAccessibly(dx: 0, dy: 1) ?? false }
        ] : nil
    }
    override func accessibilityActivate() -> Bool {
        guard editing else { return false }
        edit?(note.id); return true
    }
    private func moveAccessibly(dx: Double, dy: Double) -> Bool {
        guard editing else { return false }
        var proposed = note
        let step = max(12, note.fontSize)
        proposed.x += dx * step; proposed.y += dy * step
        proposed = TextNoteRenderer.normalized(proposed, imageSize: imageSize)
        guard proposed.x != note.x || proposed.y != note.y else { return false }
        note = proposed; updateFrame()
        move?(note.id, CGPoint(x: proposed.x, y: proposed.y))
        return true
    }
}
