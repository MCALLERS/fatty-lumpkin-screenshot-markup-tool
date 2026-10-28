import SwiftUI
import AVFoundation

enum AppPalette {
    static let ink = Color(red: 0.14, green: 0.20, blue: 0.18)
    static let secondary = Color(red: 0.35, green: 0.40, blue: 0.37)
    static let accent = Color(red: 0.19, green: 0.35, blue: 0.28)
    static let paper = Color(red: 0.99, green: 0.98, blue: 0.96)
    static let canvas = Color(red: 0.94, green: 0.94, blue: 0.91)
    static let wash = Color(red: 0.89, green: 0.93, blue: 0.88)
}
private let ink = AppPalette.ink

@main struct ScreenshotToolNativeApp: App {
    @StateObject private var model = WorkspaceModel()
    @Environment(\.scenePhase) private var phase
    var body: some Scene {
        WindowGroup {
            WorkspaceView(model: model)
                .task(id: phase) {
                    guard phase == .active else { model.persist(); return }
                    while !Task.isCancelled {
                        await model.poll()
                        try? await Task.sleep(for: .seconds(2))
                    }
                }
                .onChange(of: phase) { _, value in if value != .active { model.persist() } }
        }
    }
}
struct WorkspaceView: View {
    @ObservedObject var model: WorkspaceModel
    @AppStorage("LudwigQuoteCursor") private var quoteCursor = 0
    @State private var quoteIndex = 0
    @State private var startedQuotes = false
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 16) {
                Image("BrandMark").resizable().scaledToFit().frame(width: 46, height: 46).clipShape(RoundedRectangle(cornerRadius: 9)).accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Ludwig's Annotated Screenshots")
                        .font(.system(.title3, design: .serif, weight: .semibold)).lineLimit(3).fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("appTitle")
                    HStack(spacing: 5) {
                        Circle().fill(model.connected ? AppPalette.accent : Color.secondary).frame(width: 5, height: 5).accessibilityHidden(true)
                        Text(model.connection == nil ? "Capture. Mark up. Make it clear." : model.connected ? "Connected to your Mac" : "Waiting for your Mac")
                    }.font(.caption).foregroundStyle(AppPalette.secondary)
                }
                Spacer()
                Button { model.showPairing = true } label: { Image(systemName: "link").font(.title3) }.accessibilityLabel("Connect Mac").disabled(model.busy)
                Button { Task { await model.finish() } } label: {
                    HStack { if model.busy { ProgressView().tint(.white) }; Text(model.actionTitle).fontWeight(.semibold); Image(systemName: "arrow.up.right") }.padding(.horizontal, 12).padding(.vertical, 8)
                }.buttonStyle(.borderedProminent).tint(AppPalette.accent).foregroundStyle(.white).disabled(model.current == nil || model.busy).accessibilityIdentifier("finish")
            }.padding(20).background(AppPalette.paper)
            Divider().overlay(ink.opacity(0.08))
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 16) { queueActions; Spacer(); queueNavigation }
                VStack(alignment: .leading, spacing: 4) {
                    HStack { queueActions; Spacer() }
                    HStack { Spacer(); queueNavigation }
                }
            }.font(.subheadline).padding(.horizontal, 20).padding(.vertical, 4).background(AppPalette.paper)
            HStack(spacing: 16) {
                if model.loadingID != nil { ProgressView("Opening…") }
                else { Text(model.current?.title ?? "Choose a screenshot or capture a new one on your Mac.").lineLimit(1).truncationMode(.middle) }
                Spacer()
                if model.current != nil {
                    Button { model.undo() } label: { Image(systemName: "arrow.uturn.backward") }.disabled(!model.canUndo || model.busy).accessibilityLabel("Undo")
                    Button { model.redo() } label: { Image(systemName: "arrow.uturn.forward") }.disabled(!model.canRedo || model.busy).accessibilityLabel("Redo")
                    Button("Fit") { model.fitCanvas?() }
                    Toggle("Finger drawing", isOn: $model.fingerDrawing).fixedSize().disabled(model.busy)
                }
            }.font(.subheadline).padding(.horizontal, 20).padding(.vertical, 10).background(AppPalette.paper)
            ZStack {
                AppPalette.canvas
                if model.current != nil, model.image != nil { PencilSurface(model: model) }
                else {
                    ScrollView {
                    VStack(spacing: 16) {
                        Image("LudwigPortrait").resizable().scaledToFit().frame(maxWidth: 380).frame(height: 220).accessibilityHidden(true)
                        Text(model.connection == nil ? "Your iPad is the drawing surface." : "Ready for your next screenshot.").font(.system(size: 30, weight: .semibold)).multilineTextAlignment(.center)
                        Text(model.connection == nil ? "Connect to Ludwig's Annotated Screenshots on your Mac to start." : "On your Mac, press ⇧⌘4.\nYour captures appear here, ready for Pencil.").foregroundStyle(AppPalette.secondary).multilineTextAlignment(.center)
                        if model.connection == nil { Button("Connect your Mac") { model.showPairing = true }.buttonStyle(.borderedProminent).tint(ink).foregroundStyle(.white) }
                        if let complete = model.completedMessage {
                            Label(complete, systemImage: "checkmark.circle.fill").font(.callout).foregroundStyle(AppPalette.accent).padding(24).background(AppPalette.wash, in: RoundedRectangle(cornerRadius: 18)).frame(maxWidth: 540)
                        }
                    }.padding(24).frame(maxWidth: .infinity)
                    }
                }
            }.frame(maxWidth: .infinity, maxHeight: .infinity)
            VStack(alignment: .leading, spacing: 8) {
                LudwigThoughtView(thought: TractatusThought.all[quoteIndex]) { model.showLudwigAbout = true }
                    .disabled(model.busy || model.loadingID != nil)
                Divider().overlay(ink.opacity(0.06))
                HStack { Text(model.status).accessibilityIdentifier("status"); Spacer(); if let current = model.current { Text("\(current.width) × \(current.height)").monospacedDigit() }; Text("Beta 0.5.1 (15)") }
                Text("On your Mac: ⌃⌥⌘S opens finished screenshots · Keep Ludwig's Annotated Screenshots running.")
                    .accessibilityLabel("On your Mac: Control Option Command S opens finished screenshots. Keep Ludwig's Annotated Screenshots running.")
            }.font(.caption).foregroundStyle(AppPalette.secondary).padding(14).frame(maxWidth: .infinity, alignment: .leading).background(AppPalette.paper)
        }.foregroundStyle(ink).tint(AppPalette.accent).preferredColorScheme(.light)
            .onAppear { if !startedQuotes { nextThought(); startedQuotes = true } }
            .onChange(of: model.completedCaptureCount) { _, _ in nextThought() }
            .sheet(isPresented: $model.showLudwigAbout) { AboutLudwigView() }
            .confirmationDialog("Clear the screenshot queue?", isPresented: $model.showClearQueueConfirmation, titleVisibility: .visible) {
                Button("Clear queue · Reset to 0") { Task { await model.clearQueue() } }
                Button("Keep queue", role: .cancel) {}
            } message: {
                Text("This hides all \(model.captures.count) screenshots from the current session and resets its count to 0. Original screenshots and finished PNGs stay on your Mac. Unfinished drawings stay on this iPad under Browse → To do. New captures start at 1. No files are deleted.")
            }
            .sheet(isPresented: $model.showPairing) { PairingView(model: model) }
            .sheet(item: $model.browser) { snapshot in CaptureBrowserView(model: model, snapshot: snapshot) }
            .sheet(isPresented: $model.showSessionManager) { SessionManagementView(model: model) }
            .alert("Ludwig's Annotated Screenshots", isPresented: Binding(get: { model.error != nil && !model.showPairing && model.browser == nil && !model.showSessionManager }, set: { if !$0 { model.error = nil } })) { Button("OK") { model.error = nil } } message: { Text(model.error ?? "") }
    }
    private func nextThought() {
        quoteIndex = max(0, quoteCursor) % TractatusThought.all.count
        quoteCursor = (quoteIndex + 1) % TractatusThought.all.count
    }
    private var queueActions: some View {
        HStack(spacing: 12) {
            Button { model.browse() } label: { Label("Browse", systemImage: "square.grid.2x2") }
                .disabled(!model.hasBrowsableCaptures || model.busy || model.loadingID != nil)
                .accessibilityLabel("Browse screenshots").accessibilityIdentifier("browseScreenshots")
            Button(action: model.requestClearQueue) { Label("Clear queue", systemImage: "arrow.counterclockwise").padding(.vertical, 4) }
                .buttonStyle(.bordered).tint(AppPalette.accent)
                .disabled(model.busy || model.loadingID != nil || (model.captures.isEmpty && model.current == nil))
                .accessibilityLabel("Clear screenshot queue and reset count to zero")
                .accessibilityHint("Asks for confirmation. Files on your Mac and unfinished iPad drawings are kept.")
                .accessibilityIdentifier("clearQueue")
            Button { model.manageSession() } label: { Image(systemName: "rectangle.stack").frame(minWidth: 44, minHeight: 44) }
                .disabled(model.connection == nil || model.busy || model.loadingID != nil)
                .accessibilityLabel("Manage screenshot sessions").accessibilityIdentifier("manageSessions")
        }.fixedSize(horizontal: true, vertical: false)
    }
    private var queueNavigation: some View {
        HStack(spacing: 4) {
            Button { if let capture = model.previousCapture { Task { await model.open(capture) } } } label: { Image(systemName: "chevron.left").frame(minWidth: 44, minHeight: 44) }
                .disabled(model.previousCapture == nil || model.busy || model.loadingID != nil)
                .accessibilityLabel("Previous screenshot").accessibilityIdentifier("previousScreenshot")
            Text(model.navigationPosition).monospacedDigit().font(.subheadline.weight(.medium)).padding(.horizontal, 10).padding(.vertical, 6).background(AppPalette.wash, in: Capsule()).accessibilityIdentifier("queuePosition")
            Button { if let capture = model.followingCapture { Task { await model.open(capture) } } } label: { Image(systemName: "chevron.right").frame(minWidth: 44, minHeight: 44) }
                .disabled(model.followingCapture == nil || model.busy || model.loadingID != nil)
                .accessibilityLabel("Next screenshot").accessibilityIdentifier("nextScreenshot")
        }.fixedSize(horizontal: true, vertical: false)
    }
}
struct PairingView: View {
    @ObservedObject var model: WorkspaceModel
    @Environment(\.dismiss) var dismiss
    @State private var scanning = false
    @State private var cameraMessage: String?
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Image(systemName: "ipad.and.arrow.forward").font(.system(size: 56, weight: .light)).foregroundStyle(ink)
                Text("Connect your Mac.").font(.largeTitle.bold())
                Text("On your Mac, open Ludwig's Annotated Screenshots and click Connect iPad. Scan that QR code here.").multilineTextAlignment(.center).foregroundStyle(AppPalette.secondary).frame(maxWidth: 420)
                Button { Task { await camera() } } label: { Label("Scan Mac QR code", systemImage: "qrcode.viewfinder").frame(maxWidth: 320).padding(10) }.buttonStyle(.borderedProminent).tint(ink).foregroundStyle(.white).disabled(model.busy)
                HStack { Text("Or").foregroundStyle(AppPalette.secondary); PasteButton(payloadType: String.self) { strings in if let first = strings.first { Task { await model.pair(first) } } }.labelStyle(.titleOnly) }.disabled(model.busy)
                Text("Paste accepts the complete pairing link from the Mac QR code. Your Safari bookmark alone does not contain the pairing key.").font(.caption).foregroundStyle(AppPalette.secondary).multilineTextAlignment(.center).frame(maxWidth: 420)
                if model.busy { ProgressView("Connecting…") }
                if let address = model.pairingAddress {
                    Button("Retry connection to \(address)") { Task { await model.retryPairing() } }.buttonStyle(.bordered).disabled(model.busy)
                }
                if let error = model.error { Text(error).foregroundStyle(.red).font(.callout).multilineTextAlignment(.center).frame(maxWidth: 420) }
                if let cameraMessage { Text(cameraMessage).foregroundStyle(.red).font(.callout).multilineTextAlignment(.center) }
                Text("Same local network · Keep the Mac app open\nThe connection is local HTTP, as in the Safari companion.").font(.caption).foregroundStyle(AppPalette.secondary).multilineTextAlignment(.center)
            }.padding(32).frame(maxWidth: .infinity, maxHeight: .infinity).background(AppPalette.paper)
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() }.disabled(model.busy) } }
                .fullScreenCover(isPresented: $scanning) {
                    NavigationStack {
                        QRScanner(found: { value in scanning = false; Task { await model.pair(value) } }, failed: { message in scanning = false; cameraMessage = message })
                            .overlay(alignment: .bottom) { Text("Point at the QR code on your Mac.").padding().background(.regularMaterial, in: Capsule()).padding(24) }
                            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { scanning = false } } }
                    }
                }
        }
    }
    private func camera() async {
        let granted = await AVCaptureDevice.requestAccess(for: .video)
        if granted { scanning = true }
        else { cameraMessage = "Allow camera access in Settings to scan, or use Paste with your Mac’s pairing link." }
    }
}
