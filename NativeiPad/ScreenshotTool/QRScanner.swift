import SwiftUI
import VisionKit

struct QRScanner: UIViewControllerRepresentable {
    var found: (String) -> Void
    var failed: (String) -> Void
    func makeUIViewController(context: Context) -> ScannerController {
        let controller = ScannerController(); controller.found = found; controller.failed = failed; return controller
    }
    func updateUIViewController(_ controller: ScannerController, context: Context) {
        controller.found = found; controller.failed = failed
    }
    static func dismantleUIViewController(_ controller: ScannerController, coordinator: ()) { controller.stop() }
}

/// VisionKit owns the camera preview and its interruption/restart lifecycle.
final class ScannerController: UIViewController, DataScannerViewControllerDelegate {
    private var scanner: DataScannerViewController?
    private var delivered = false
    var found: ((String) -> Void)?
    var failed: ((String) -> Void)?

    override func viewDidLoad() {
        super.viewDidLoad(); view.backgroundColor = .black
        guard DataScannerViewController.isSupported else { return }
        let scanner = DataScannerViewController(recognizedDataTypes: [.barcode(symbologies: [.qr])], qualityLevel: .balanced, recognizesMultipleItems: false, isHighFrameRateTrackingEnabled: false, isPinchToZoomEnabled: true, isGuidanceEnabled: true, isHighlightingEnabled: true)
        scanner.delegate = self; self.scanner = scanner
        addChild(scanner); view.addSubview(scanner.view)
        scanner.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            scanner.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scanner.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scanner.view.topAnchor.constraint(equalTo: view.topAnchor),
            scanner.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        scanner.didMove(toParent: self)
    }
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated); delivered = false
        guard let scanner, DataScannerViewController.isAvailable else {
            report("Apple’s QR scanner is unavailable. Check Camera access for Ludwig's Annotated Screenshots in iPad Settings. You can also scan with the iPad Camera app, copy the QR link, and use Paste here."); return
        }
        do { try scanner.startScanning() }
        catch { report("The camera could not start: " + error.localizedDescription) }
    }
    override func viewWillDisappear(_ animated: Bool) { super.viewWillDisappear(animated); stop() }
    func stop() { scanner?.stopScanning() }
    private func report(_ message: String) { guard !delivered else { return }; delivered = true; stop(); failed?(message) }
    private func accept(_ items: [RecognizedItem]) {
        guard !delivered else { return }
        for item in items {
            if case .barcode(let code) = item, let value = code.payloadStringValue {
                // Ignore other QR codes in the camera view.
                guard (try? Connection.parse(value)) != nil else { continue }
                delivered = true; stop(); found?(value); return
            }
        }
    }
    func dataScanner(_ dataScanner: DataScannerViewController, didAdd addedItems: [RecognizedItem], allItems: [RecognizedItem]) { accept(allItems) }
    func dataScanner(_ dataScanner: DataScannerViewController, didTapOn item: RecognizedItem) { accept([item]) }
    func dataScanner(_ dataScanner: DataScannerViewController, becameUnavailableWithError error: DataScannerViewController.ScanningUnavailable) {
        report("Apple’s QR scanner became unavailable. Close other camera apps and check Camera access in iPad Settings, then try again.")
    }
}
