import SwiftUI
import AppKit
import ImageIO
import UniformTypeIdentifiers
import CoreImage.CIFilterBuiltins
import Carbon

/// Registers just this key combination; no keyboard monitoring permission is needed.
final class ReadyFolderShortcut {
    private var hotKey: EventHotKeyRef?
    private var handler: EventHandlerRef?
    func register() throws {
        var event = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let handlerStatus = InstallEventHandler(GetApplicationEventTarget(), { _, event, _ in
            var identifier = EventHotKeyID()
            guard let event,
                  GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID), nil, MemoryLayout<EventHotKeyID>.size, nil, &identifier) == noErr,
                  identifier.signature == 0x5353544C, identifier.id == 1 else { return OSStatus(eventNotHandledErr) }
            Task { @MainActor in NSWorkspace.shared.open(Library.standard.ready) }
            return noErr
        }, 1, &event, nil, &handler)
        guard handlerStatus == noErr else { throw ToolError.message("Could not enable the finished-screenshots shortcut. Use Open finished screenshots instead.") }
        let status = RegisterEventHotKey(UInt32(kVK_ANSI_S), UInt32(controlKey | optionKey | cmdKey), EventHotKeyID(signature: 0x5353544C, id: 1), GetApplicationEventTarget(), 0, &hotKey)
        guard status == noErr else { throw ToolError.message("Control–Option–Command–S is unavailable, possibly because another app uses it. Open finished screenshots still works from this app.") }
    }
    deinit {
        if let hotKey { UnregisterEventHotKey(hotKey) }
        if let handler { RemoveEventHandler(handler) }
    }
}

enum ToolError: LocalizedError {
    case message(String)
    var errorDescription: String? { if case .message(let text) = self { return text }; return nil }
}

struct Library {
    let root: URL
    static let standard = Library(root: FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Documents/Screenshot Tool"))
    var inbox: URL { root.appendingPathComponent("Inbox") }
    var annotated: URL { root.appendingPathComponent("Annotated") }
    var ready: URL { root.appendingPathComponent("Ready") }
    func setup() throws {
        for folder in [inbox, annotated, ready] {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        }
    }
    func files(in folder: URL) throws -> [URL] {
        try FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: [.contentModificationDateKey, .isRegularFileKey], options: .skipsHiddenFiles)
            .filter { ["png", "jpg", "jpeg", "heic", "heif", "tiff", "tif"].contains($0.pathExtension.lowercased()) && (try? $0.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true }
            .sorted { date($0) > date($1) }
    }
    func date(_ url: URL) -> Date { (try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast }
    func unique(_ source: URL, in folder: URL, suffix: String) -> URL {
        let stem = String(source.deletingPathExtension().lastPathComponent.prefix(120))
        return folder.appendingPathComponent("\(stem) — \(suffix) \(UUID().uuidString.prefix(8)).png")
    }
    // Decode from disk on every export; never use a possibly stale display image.
    func png(_ url: URL) throws -> Data {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            throw ToolError.message("This image could not be read. Finish saving it, then try again.")
        }
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(data, UTType.png.identifier as CFString, 1, nil) else {
            throw ToolError.message("Could not prepare a PNG.")
        }
        // Preserve orientation when importing JPEG/HEIF images.
        let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any]
        let orientation = properties?[kCGImagePropertyOrientation] ?? 1
        CGImageDestinationAddImage(destination, image, [kCGImagePropertyOrientation: orientation] as CFDictionary)
        guard CGImageDestinationFinalize(destination) else { throw ToolError.message("Could not finish the PNG.") }
        return data as Data
    }
    func workingCopy(_ source: URL) throws -> URL {
        if source.deletingLastPathComponent().standardizedFileURL == annotated.standardizedFileURL { return source }
        let destination = unique(source, in: annotated, suffix: "markup")
        try png(source).write(to: destination, options: .atomic)
        return destination
    }
    func export(_ source: URL) throws -> URL {
        let destination = unique(source, in: ready, suffix: "ready")
        try png(source).write(to: destination, options: .atomic)
        return destination
    }
    func copy(_ url: URL, to pasteboard: NSPasteboard) throws {
        let data = try Data(contentsOf: url)
        guard let image = NSImage(data: data), let tiff = image.tiffRepresentation else { throw ToolError.message("Could not copy this image.") }
        let item = NSPasteboardItem()
        item.setData(data, forType: .png)
        item.setData(tiff, forType: .tiff)
        item.setString(url.absoluteString, forType: .fileURL)
        pasteboard.clearContents()
        guard pasteboard.writeObjects([item]) else { throw ToolError.message("Clipboard write failed. Drag the file from Finder instead.") }
    }
}

@MainActor final class Model: ObservableObject {
    let library = Library.standard
    let serviceState = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support/Screenshot Tool")
    @Published var captureConfigured = false
    @Published var inbox: [URL] = []
    @Published var annotated: [URL] = []
    @Published var ready: [URL] = []
    @Published var selected: URL? { didSet { if oldValue != selected { lastExport = nil }; updatePreview() } }
    @Published var preview: NSImage?
    @Published var message = "Take a screenshot. Open Fatty Lumpkin Markup on your iPad. Draw, then tap Done."
    @Published var error: String?
    @Published var lastExport: URL?
    @Published var showPairing = false
    @Published var qrImage: NSImage?
    @Published var connection = "Starting iPad connection…"
    @Published var address = ""
    private var pairingURL: URL?
    private var token = ""
    private var port = 0
    private var stamp = ""
    private var timer: Timer?
    private var service: Process?
    private var knownInbox: Set<URL>?
    private var lastCompletion = ""
    private var checkingConnection = false
    private let readyShortcut = ReadyFolderShortcut()
    init() {
        perform { try library.setup() }
        perform { try readyShortcut.register() }
        lastCompletion = readJSON("last-completion.json")?["id"] as? String ?? ""
        refresh()
        startService()
        timer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refresh(); self?.checkService(); self?.checkCompletion() }
        }
    }
    func perform(_ action: () throws -> Void) { do { try action() } catch { self.error = error.localizedDescription } }
    func readJSON(_ filename: String) -> [String: Any]? {
        guard let data = try? Data(contentsOf: serviceState.appendingPathComponent(filename)) else { return nil }
        return (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
    }
    func refresh() {
        captureConfigured = CaptureSettings.isConfigured(for: library.inbox)
        perform {
            let newInbox = try library.files(in: library.inbox)
            let newAnnotated = try library.files(in: library.annotated)
            let newReady = try library.files(in: library.ready)
            if inbox != newInbox { inbox = newInbox }
            if annotated != newAnnotated { annotated = newAnnotated }
            if ready != newReady { ready = newReady }
            if let known = knownInbox, let latest = newInbox.first, !known.contains(latest), library.date(latest).timeIntervalSinceNow < -0.7 {
                selected = latest; message = "New screenshot ready on your iPad."
            }
            // Ignore files until the screenshot writer has finished.
            knownInbox = Set(newInbox.filter { library.date($0).timeIntervalSinceNow < -0.7 })
            if selected == nil { selected = inbox.first ?? ready.first ?? annotated.first }
            updatePreview()
        }
    }
    func updatePreview() {
        guard let url = selected else { preview = nil; stamp = ""; return }
        let values = try? url.resourceValues(forKeys: [.contentModificationDateKey, .fileSizeKey])
        let newStamp = "\(url.path)|\(values?.contentModificationDate?.timeIntervalSince1970 ?? 0)|\(values?.fileSize ?? 0)"
        guard stamp != newStamp else { return }
        stamp = newStamp
        preview = (try? Data(contentsOf: url)).flatMap { NSImage(data: $0) }
    }
    func latest() { refresh(); if let first = inbox.first { selected = first; message = "Latest capture selected." } else { message = "Take a screenshot with ⇧⌘4. It will appear on the iPad." } }
    func startService() {
        guard service?.isRunning != true else { return }
        perform {
            try FileManager.default.createDirectory(at: serviceState, withIntermediateDirectories: true)
            guard let script = Bundle.main.url(forResource: "server", withExtension: "py", subdirectory: "Companion") else {
                throw ToolError.message("The iPad companion is missing from this app. Reinstall Fatty Lumpkin Markup.")
            }
            let process = Process()
            let bundled = Bundle.main.bundleURL.appendingPathComponent("Contents/Helpers/FattyLumpkinCompanion.app/Contents/MacOS/FattyLumpkinCompanion")
            let arguments = ["--library", library.root.path, "--state", serviceState.path, "--parent", String(ProcessInfo.processInfo.processIdentifier), "--assets", script.deletingLastPathComponent().path]
            if FileManager.default.isExecutableFile(atPath: bundled.path) {
                process.executableURL = bundled
                process.arguments = arguments
            } else {
                process.executableURL = URL(fileURLWithPath: "/usr/bin/python3")
                process.arguments = [script.path] + arguments
            }
            process.standardOutput = FileHandle.nullDevice
            process.standardError = FileHandle.nullDevice
            try process.run()
            service = process
        }
    }
    func checkService() {
        guard let service, service.isRunning else { connection = "iPad connection stopped — reopen Fatty Lumpkin Markup"; return }
        if token.isEmpty, let config = readJSON("server.json"), (config["pid"] as? Int) == Int(service.processIdentifier), let value = config["token"] as? String, let serverPort = config["port"] as? Int {
            token = value; port = serverPort
            if let lan = config["lan"] as? String {
                address = "http://\(lan):\(port)"
                pairingURL = URL(string: address + "/#pair=" + value)
                let filter = CIFilter.qrCodeGenerator()
                filter.message = Data(pairingURL!.absoluteString.utf8)
                filter.correctionLevel = "M"
                if let output = filter.outputImage?.transformed(by: CGAffineTransform(scaleX: 8, y: 8)), let cg = CIContext().createCGImage(output, from: output.extent) {
                    qrImage = NSImage(cgImage: cg, size: NSSize(width: cg.width, height: cg.height))
                }
                connection = "Ready for your iPad"
            } else { connection = "Connect this Mac to your local network, then reopen Fatty Lumpkin Markup" }
        }
        guard port > 0, !checkingConnection else { return }
        checkingConnection = true
        var request = URLRequest(url: URL(string: "http://127.0.0.1:\(port)/api/status")!)
        request.setValue("Bearer " + token, forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 3
        URLSession.shared.dataTask(with: request) { [weak self] data, _, _ in
            let seen = data.flatMap { (try? JSONSerialization.jsonObject(with: $0)) as? [String: Any] }?["lastSeen"] as? Double ?? 0
            Task { @MainActor in
                guard let self else { return }
                self.checkingConnection = false
                if !self.address.isEmpty { self.connection = Date().timeIntervalSince1970 - seen < 20 ? "Companion connected" : "Ready for your iPad" }
            }
        }.resume()
    }
    func checkCompletion() {
        guard let result = readJSON("last-completion.json"), let id = result["id"] as? String, id != lastCompletion, let name = result["filename"] as? String, name == (name as NSString).lastPathComponent, name.hasSuffix(".png") else { return }
        perform {
            let url = library.ready.appendingPathComponent(name)
            try library.copy(url, to: .general)
            let ack = try JSONSerialization.data(withJSONObject: ["id": id])
            try ack.write(to: serviceState.appendingPathComponent("clipboard-ack.json"), options: .atomic)
            lastCompletion = id
            refresh(); selected = url; lastExport = url
            message = "Copied from your iPad. Paste into your agent now."
        }
    }
    func configureCaptures() {
        perform {
            try CaptureSettings.configure(inbox: library.inbox, state: serviceState)
            captureConfigured = true
            message = "Screenshots now save to Documents → Screenshot Tool → Inbox. Press ⇧⌘4 to try it."
        }
    }
    func restoreCaptures() {
        perform {
            try CaptureSettings.restore(state: serviceState)
            captureConfigured = CaptureSettings.isConfigured(for: library.inbox)
            message = "Your previous screenshot settings have been restored."
        }
    }
    func openCompanion() { if let pairingURL { NSWorkspace.shared.open(pairingURL) } }
    func copyImage() {
        guard let selected else { return }
        perform {
            let result = selected.deletingLastPathComponent() == library.ready ? selected : try library.export(selected)
            try library.copy(result, to: .general)
            lastExport = result
            message = "Image copied. Paste into your agent, or drag the preview."
            stamp = ""; updatePreview()
        }
    }
    func copyPath() {
        guard let url = lastExport ?? selected else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(url.path, forType: .string)
        message = "File path copied. Ask your agent to open this image."
    }
    func importImage() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.png, .jpeg, .heic, .tiff]
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        perform {
            let destination = library.unique(url, in: library.inbox, suffix: "import")
            try library.png(url).write(to: destination, options: .atomic)
            refresh(); selected = destination
        }
    }
}

struct BrandArt: View {
    var body: some View {
        if let url = Bundle.main.url(forResource: "Pony", withExtension: "png"), let image = NSImage(contentsOf: url) {
            Image(nsImage: image).resizable().scaledToFit().clipShape(RoundedRectangle(cornerRadius: 12))
        } else { Image(systemName: "viewfinder").resizable().scaledToFit() }
    }
}

struct ContentView: View {
    @ObservedObject var model: Model
    var body: some View {
        HSplitView {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 10) {
                    BrandArt().frame(width: 44, height: 44)
                    VStack(alignment: .leading) {
                        Text("Fatty Lumpkin").font(.system(.headline, design: .serif))
                        Text("Screenshot Markup Tool").font(.caption).foregroundStyle(.secondary)
                    }
                }.padding(.horizontal, 12)
                Button(action: model.latest) { Label("Select latest capture", systemImage: "sparkle.viewfinder").frame(maxWidth: .infinity) }
                    .controlSize(.large).padding(.horizontal, 8)
                List(selection: $model.selected) {
                    Section("Inbox · originals") {
                        ForEach(model.inbox, id: \.self) { url in row(url, icon: "photo") }
                    }
                    Section("Ready for your agent") {
                        ForEach(model.ready, id: \.self) { url in row(url, icon: "pencil.tip.crop.circle") }
                    }
                }.listStyle(.sidebar)
                if !model.captureConfigured {
                    Button("Set up screenshot folder", action: model.configureCaptures).buttonStyle(.borderedProminent).padding(.horizontal, 12)
                    Text("Saves new screenshots as PNG in the Inbox.").font(.caption).foregroundStyle(.secondary).padding(.horizontal, 12)
                }
                Button("Import an existing image…", action: model.importImage).padding(.horizontal, 12)
                Button("Open finished screenshots") { NSWorkspace.shared.open(model.library.ready) }.padding(.horizontal, 12)
                Text("⌃⌥⌘S · from any Mac app").font(.caption).foregroundStyle(.secondary).padding(.horizontal, 12)
                Button("Open all screenshot folders") { NSWorkspace.shared.open(model.library.root) }.padding(.horizontal, 12)
                Text("Documents → Screenshot Tool").font(.caption).foregroundStyle(.secondary).padding(.horizontal, 12)
            }.padding(.vertical, 16).frame(minWidth: 235, idealWidth: 280, maxWidth: 350)
            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Your iPad is the drawing surface.").font(.title2.weight(.semibold))
                        Text(model.connection).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button { model.refresh() } label: { Image(systemName: "arrow.clockwise") }.help("Refresh")
                }
                ZStack {
                    RoundedRectangle(cornerRadius: 16).fill(Color(nsColor: .underPageBackgroundColor))
                    if let image = model.preview {
                        Image(nsImage: image).resizable().scaledToFit().padding(16)
                            .onDrag { model.selected.flatMap { NSItemProvider(contentsOf: $0) } ?? NSItemProvider() }
                            .help("Drag the saved image into your agent")
                    } else {
                        VStack(spacing: 12) {
                            BrandArt().frame(width: 190, height: 190)
                            Text("Your next screenshot starts here").font(.headline)
                            Text("Press ⇧⌘4 and select an area on your screen.").foregroundStyle(.secondary)
                        }
                    }
                }.frame(maxWidth: .infinity, maxHeight: .infinity)
                if let selected = model.selected {
                    Text(selected.lastPathComponent).font(.caption).foregroundStyle(.secondary).lineLimit(2).textSelection(.enabled)
                }
                HStack(spacing: 12) {
                    Button { model.showPairing = true } label: { Label("Connect iPad", systemImage: "ipad.and.iphone") }.controlSize(.large)
                    Button(action: model.copyImage) { Label("Copy Image", systemImage: "doc.on.doc") }.buttonStyle(.borderedProminent).controlSize(.large).disabled(model.selected == nil)
                    Button("Show in Finder") { if let url = model.selected { NSWorkspace.shared.activateFileViewerSelecting([url]) } }
                }
                VStack(alignment: .leading, spacing: 6) {
                    Text("1  Take a screenshot with ⇧⌘4. It appears on the iPad.")
                    Text("2  Draw with Pencil. Tap Done on the iPad.")
                    Text("3  Paste into your agent. The Mac copies it automatically.")
                }.font(.callout).foregroundStyle(.secondary)
                Divider()
                Text(model.message).font(.callout).foregroundStyle(.primary).fixedSize(horizontal: false, vertical: true)
                HStack {
                    Text("Keep Fatty Lumpkin Markup open while using the iPad.").font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    Button("Copy file path", action: model.copyPath).disabled(model.selected == nil)
                    Button("Show ready PNG") { if let url = model.lastExport { NSWorkspace.shared.activateFileViewerSelecting([url]) } }.disabled(model.lastExport == nil)
                }
            }.padding(24).frame(minWidth: 650, minHeight: 620)
        }
        .sheet(isPresented: $model.showPairing) { PairingView(model: model) }
        .alert("Fatty Lumpkin Markup", isPresented: Binding(get: { model.error != nil }, set: { if !$0 { model.error = nil } })) { Button("OK") { model.error = nil } } message: { Text(model.error ?? "") }
    }
    func row(_ url: URL, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Label(url.deletingPathExtension().lastPathComponent, systemImage: icon).lineLimit(2)
            Text(model.library.date(url), style: .relative).font(.caption2).foregroundStyle(.secondary)
        }.padding(.vertical, 5).tag(url)
    }
}

struct PairingView: View {
    @ObservedObject var model: Model
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        VStack(spacing: 18) {
            HStack { Text("Connect your iPad").font(.title2.weight(.semibold)); Spacer(); Button("Close") { dismiss() } }
            Text("In Fatty Lumpkin Markup on your iPad, tap Scan Mac QR code.").foregroundStyle(.secondary)
            if let qr = model.qrImage {
                Image(nsImage: qr).interpolation(.none).resizable().scaledToFit().frame(width: 260, height: 260).padding(16).background(.white).clipShape(RoundedRectangle(cornerRadius: 16))
            } else { ProgressView().frame(width: 260, height: 200); Text(model.connection) }
            Text("Prefer Safari? Scan with the iPad Camera app instead.\nUse Share → Add to Home Screen to keep it handy.").multilineTextAlignment(.center)
            Text("Both devices need to be on the same local network.\nKeep this Mac app open. No cloud upload is used.").font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.center)
            Text(model.address).font(.caption.monospaced()).foregroundStyle(.secondary)
            Button("Open iPad view on this Mac", action: model.openCompanion).disabled(model.qrImage == nil)
        }.padding(28).frame(width: 480)
    }
}

@main struct ScreenshotToolApp: App {
    @StateObject private var model = Model()
    @Environment(\.openWindow) private var openWindow
    init() {
        if CommandLine.arguments.contains("--self-test") {
            do { try selfTest(); print("PASS: original preservation, fresh export, PNG dimensions, clipboard image/file representations, invalid-image handling, stable working copy."); exit(0) }
            catch { fputs("FAIL: \(error)\n", stderr); exit(1) }
        }
    }
    var body: some Scene {
        Window("Fatty Lumpkin Screenshot Markup Tool", id: "main") { ContentView(model: model) }.defaultSize(width: 1080, height: 740)
        MenuBarExtra("Fatty Lumpkin Markup", systemImage: "viewfinder") {
            Button("Open Fatty Lumpkin Markup") { openWindow(id: "main"); NSApp.activate(ignoringOtherApps: true) }
            Button("Select latest capture") { model.latest(); openWindow(id: "main"); NSApp.activate(ignoringOtherApps: true) }
            Button("Connect iPad") { model.showPairing = true; openWindow(id: "main"); NSApp.activate(ignoringOtherApps: true) }
            Button("Copy selected image", action: model.copyImage).disabled(model.selected == nil)
            Button("Open finished screenshots   ⌃⌥⌘S") { NSWorkspace.shared.open(model.library.ready) }
            Button("Open all screenshot folders") { NSWorkspace.shared.open(model.library.root) }
            Divider()
            Button("Restore previous screenshot settings", action: model.restoreCaptures)
            Divider()
            Button("Quit Fatty Lumpkin Markup") { NSApp.terminate(nil) }
        }
    }
}

func selfTest() throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent("ScreenshotTool-Test-\(UUID())")
    let lib = Library(root: root)
    try lib.setup()
    defer { try? FileManager.default.removeItem(at: root) }
    func expect(_ condition: Bool, _ description: String) throws { if !condition { throw ToolError.message(description) } }
    func fixture(_ red: Bool) -> Data {
        let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 8, pixelsHigh: 6, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
        for x in 0..<8 { for y in 0..<6 {
            let offset = y * rep.bytesPerRow + x * 4
            rep.bitmapData![offset] = red ? 255 : 0
            rep.bitmapData![offset + 1] = 0
            rep.bitmapData![offset + 2] = red ? 0 : 255
            rep.bitmapData![offset + 3] = 255
        } }
        return rep.representation(using: .png, properties: [:])!
    }
    let source = lib.inbox.appendingPathComponent("Test.png")
    let original = fixture(true)
    try original.write(to: source)
    let working = try lib.workingCopy(source)
    try expect(source != working, "Must preserve the original")
    try expect(try lib.workingCopy(working) == working, "Repeated preparation should reuse working copy")
    let first = try lib.export(working)
    try fixture(false).write(to: working, options: .atomic)
    let second = try lib.export(working)
    try expect(try Data(contentsOf: source) == original, "Original changed")
    try expect(first != second, "Exports must not overwrite")
    try expect(try Data(contentsOf: first) != Data(contentsOf: second), "Export used stale image")
    let bitmap = NSBitmapImageRep(data: try Data(contentsOf: second))!
    try expect(bitmap.pixelsWide == 8 && bitmap.pixelsHigh == 6, "Pixel dimensions changed")
    let board = NSPasteboard.withUniqueName()
    defer { board.releaseGlobally() }
    try lib.copy(second, to: board)
    try expect(board.data(forType: .png) != nil && board.data(forType: .tiff) != nil, "Missing image pasteboard types")
    try expect(board.string(forType: .fileURL) == second.absoluteString, "Missing file pasteboard type")
    let bad = lib.inbox.appendingPathComponent("Invalid.png")
    try Data("not an image".utf8).write(to: bad)
    do { _ = try lib.export(bad); throw ToolError.message("Invalid image accepted") }
    catch let error as ToolError { if error.localizedDescription == "Invalid image accepted" { throw error } }
}
