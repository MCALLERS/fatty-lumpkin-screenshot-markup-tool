import SwiftUI
import AVFoundation

private let ink = Color(red: 0.16, green: 0.23, blue: 0.17)
private let lime = Color(red: 0.91, green: 0.82, blue: 0.61)

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
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 16) {
                Image("Pony").resizable().scaledToFit().frame(width: 46, height: 46).clipShape(RoundedRectangle(cornerRadius: 9)).accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Fatty Lumpkin").font(.system(.title3, design: .serif, weight: .semibold))
                    Text(model.connection == nil ? "Screenshot Markup Tool" : model.connected ? "Connected to your Mac" : "Waiting for your Mac").font(.caption).foregroundStyle(.white.opacity(0.7))
                }
                Spacer()
                Button { model.showPairing = true } label: { Image(systemName: "link").font(.title3) }.accessibilityLabel("Connect Mac").disabled(model.busy)
                Button { Task { await model.finish() } } label: {
                    HStack { if model.busy { ProgressView().tint(ink) }; Text(model.actionTitle).fontWeight(.semibold); Image(systemName: "arrow.up.right") }.padding(.horizontal, 12).padding(.vertical, 8)
                }.buttonStyle(.borderedProminent).tint(lime).foregroundStyle(ink).disabled(model.current == nil || model.busy).accessibilityIdentifier("finish")
            }.padding(20).foregroundStyle(.white).background(ink)
            HStack(spacing: 16) {
                Text(model.position).font(.subheadline.weight(.semibold)).padding(.horizontal, 12).padding(.vertical, 8).background(lime.opacity(0.3), in: RoundedRectangle(cornerRadius: 8)).accessibilityIdentifier("queuePosition")
                Menu {
                    ForEach(model.captures) { capture in Button((capture.saved ? "✓ " : "") + capture.title) { Task { await model.open(capture) } } }
                } label: { Label(model.current?.title ?? "Previous screenshots", systemImage: "chevron.down").lineLimit(1) }.disabled(model.captures.isEmpty || model.busy)
                Spacer()
                if model.current != nil {
                    Button { model.undo() } label: { Image(systemName: "arrow.uturn.backward") }.disabled(!model.canUndo || model.busy).accessibilityLabel("Undo")
                    Button { model.redo() } label: { Image(systemName: "arrow.uturn.forward") }.disabled(!model.canRedo || model.busy).accessibilityLabel("Redo")
                    Button("Fit") { model.fitCanvas?() }
                    Toggle("Finger drawing", isOn: $model.fingerDrawing).fixedSize().disabled(model.busy)
                }
            }.font(.subheadline).padding(.horizontal, 20).padding(.vertical, 10).background(.white)
            ZStack {
                Color(red: 0.96, green: 0.94, blue: 0.89)
                if model.current != nil, model.image != nil { PencilSurface(model: model) }
                else {
                    VStack(spacing: 20) {
                        Image("Pony").resizable().scaledToFit().frame(maxWidth: 220, maxHeight: 220).clipShape(RoundedRectangle(cornerRadius: 24)).accessibilityHidden(true)
                        Text(model.connection == nil ? "Your iPad is the drawing surface." : "Ready for your next screenshot.").font(.system(size: 30, weight: .semibold)).multilineTextAlignment(.center)
                        Text(model.connection == nil ? "Connect to Fatty Lumpkin on your Mac to start." : "On your Mac, press ⇧⌘4.\nYour captures appear here, ready for Pencil.").foregroundStyle(.secondary).multilineTextAlignment(.center)
                        if model.connection == nil { Button("Connect your Mac") { model.showPairing = true }.buttonStyle(.borderedProminent).tint(ink).foregroundStyle(.white) }
                        if let complete = model.completedMessage {
                            Label(complete, systemImage: "checkmark.circle.fill").font(.callout).foregroundStyle(Color(red: 0.15, green: 0.32, blue: 0.17)).padding(24).background(lime.opacity(0.25), in: RoundedRectangle(cornerRadius: 18)).frame(maxWidth: 540)
                        }
                    }.padding(32)
                }
            }.frame(maxWidth: .infinity, maxHeight: .infinity)
            VStack(alignment: .leading, spacing: 8) {
                HStack { Text(model.status).accessibilityIdentifier("status"); Spacer(); if let current = model.current { Text("\(current.width) × \(current.height)").monospacedDigit() }; Text("Beta 0.4.0") }
                Text("On your Mac: ⌃⌥⌘S opens finished screenshots · Keep Fatty Lumpkin running.")
                    .accessibilityLabel("On your Mac: Control Option Command S opens finished screenshots. Keep Fatty Lumpkin running.")
            }.font(.caption).foregroundStyle(.secondary).padding(14).frame(maxWidth: .infinity, alignment: .leading).background(.white)
        }.foregroundStyle(ink).preferredColorScheme(.light)
            .sheet(isPresented: $model.showPairing) { PairingView(model: model) }
            .alert("Fatty Lumpkin", isPresented: Binding(get: { model.error != nil && !model.showPairing }, set: { if !$0 { model.error = nil } })) { Button("OK") { model.error = nil } } message: { Text(model.error ?? "") }
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
                Text("On your Mac, open Fatty Lumpkin and click Connect iPad. Scan that QR code here.").multilineTextAlignment(.center).foregroundStyle(.secondary).frame(maxWidth: 420)
                Button { Task { await camera() } } label: { Label("Scan Mac QR code", systemImage: "qrcode.viewfinder").frame(maxWidth: 320).padding(10) }.buttonStyle(.borderedProminent).tint(ink).foregroundStyle(.white).disabled(model.busy)
                HStack { Text("Or").foregroundStyle(.secondary); PasteButton(payloadType: String.self) { strings in if let first = strings.first { Task { await model.pair(first) } } }.labelStyle(.titleOnly) }.disabled(model.busy)
                Text("Paste accepts the complete pairing link from the Mac QR code. Your Safari bookmark alone does not contain the pairing key.").font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.center).frame(maxWidth: 420)
                if model.busy { ProgressView("Connecting…") }
                if let address = model.pairingAddress {
                    Button("Retry connection to \(address)") { Task { await model.retryPairing() } }.buttonStyle(.bordered).disabled(model.busy)
                }
                if let error = model.error { Text(error).foregroundStyle(.red).font(.callout).multilineTextAlignment(.center).frame(maxWidth: 420) }
                if let cameraMessage { Text(cameraMessage).foregroundStyle(.red).font(.callout).multilineTextAlignment(.center) }
                Text("Same local network · Keep the Mac app open\nThe connection is local HTTP, as in the Safari companion.").font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.center)
            }.padding(32).frame(maxWidth: .infinity, maxHeight: .infinity).background(Color(red: 0.96, green: 0.94, blue: 0.89))
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
