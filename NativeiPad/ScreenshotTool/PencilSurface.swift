import SwiftUI
import PencilKit

struct PencilSurface: UIViewControllerRepresentable {
    @ObservedObject var model: WorkspaceModel
    func makeUIViewController(context: Context) -> DrawingController { DrawingController() }
    func updateUIViewController(_ controller: DrawingController, context: Context) {
        guard let image = model.image, let capture = model.current else { return }
        let selection = model.selection
        controller.changed = { [weak model] drawing in model?.drawingChanged(drawing, selectionID: selection) }
        controller.configure(image: image, size: CGSize(width: capture.width, height: capture.height), drawing: model.drawing, selection: selection)
        controller.canvas.drawingPolicy = model.fingerDrawing ? .anyInput : .pencilOnly
        controller.setDrawingActive(!model.busy && model.loadingID == nil && model.browser == nil && !model.showPairing)
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
    private var selection: UUID?
    private var needsFit = true
    private var settingDrawing = false
    private var lastSize = CGSize.zero
    private var drawingActive = true

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor(red: 0.91, green: 0.94, blue: 0.93, alpha: 1)
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
    }
    override func viewDidAppear(_ animated: Bool) { super.viewDidAppear(animated); updateDrawingFocus() }
    func setDrawingActive(_ active: Bool) {
        loadViewIfNeeded()
        view.isUserInteractionEnabled = active
        guard drawingActive != active else { return }
        drawingActive = active
        if view.window != nil { updateDrawingFocus() }
    }
    private func updateDrawingFocus() {
        picker.setVisible(drawingActive, forFirstResponder: canvas)
        if drawingActive { canvas.becomeFirstResponder() } else { canvas.resignFirstResponder() }
    }
    override func viewWillDisappear(_ animated: Bool) { super.viewWillDisappear(animated); picker.setVisible(false, forFirstResponder: canvas); canvas.resignFirstResponder() }
    func configure(image: UIImage, size: CGSize, drawing: PKDrawing, selection: UUID) {
        loadViewIfNeeded()
        guard self.selection != selection else { return }
        self.selection = selection; scroll.zoomScale = 1
        sheet.frame = CGRect(origin: .zero, size: size); background.frame = sheet.bounds; canvas.frame = sheet.bounds
        canvas.contentSize = size; background.image = image; scroll.contentSize = size
        settingDrawing = true; canvas.drawing = drawing; canvas.undoManager?.removeAllActions(); settingDrawing = false
        needsFit = true; view.setNeedsLayout()
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
    func scrollViewDidZoom(_ scrollView: UIScrollView) { centerSheet() }
    private func centerSheet() {
        let x = max(24, (scroll.bounds.width - scroll.contentSize.width) / 2)
        let y = max(24, (scroll.bounds.height - scroll.contentSize.height) / 2)
        scroll.contentInset = UIEdgeInsets(top: y, left: x, bottom: max(80, y), right: x)
    }
    func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) { if !settingDrawing { changed?(canvasView.drawing) } }
}
