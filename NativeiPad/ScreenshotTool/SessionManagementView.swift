import SwiftUI

struct SessionManagementView: View {
    @ObservedObject var model: WorkspaceModel
    @Environment(\.dismiss) private var dismiss
    @State private var confirmReset = false
    @State private var confirmCleanup = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("A fresh start, whenever you need one.").font(.system(.title2, design: .serif, weight: .semibold))
                        Text("Keep a session for a task, a conversation, or a day.").foregroundStyle(AppPalette.secondary)
                    }
                    VStack(alignment: .leading, spacing: 16) {
                        Label("\(model.captures.count) screenshots in this session", systemImage: "rectangle.stack").font(.headline)
                        Text("Start a new session to reset the count to 0. Your previous originals and finished PNGs stay in the Screenshot Tool folders on your Mac.")
                            .foregroundStyle(AppPalette.secondary)
                        Button { confirmReset = true } label: {
                            Label("New session · Reset count", systemImage: "arrow.counterclockwise").frame(maxWidth: .infinity).padding(.vertical, 8)
                        }.buttonStyle(.borderedProminent).tint(AppPalette.accent).foregroundStyle(.white)
                            .disabled(model.sessionActionIssue != nil || model.busy).accessibilityIdentifier("resetSession")
                    }.padding(22).background(.white, in: RoundedRectangle(cornerRadius: 18))
                    VStack(alignment: .leading, spacing: 16) {
                        Label("Clear older screenshots", systemImage: "archivebox").font(.headline)
                        Text("When you no longer need previous sessions, move their originals and finished PNGs to the Trash on your Mac. This session stays here.")
                            .foregroundStyle(AppPalette.secondary)
                        if let preview = model.cleanupPreview {
                            if preview.fileCount == 0 {
                                Label("No previous-session files to clear.", systemImage: "checkmark.circle").foregroundStyle(AppPalette.accent)
                            } else {
                                Text("\(preview.captureCount) older screenshots · \(preview.fileCount) files · \(preview.sizeDescription)").font(.subheadline.weight(.medium))
                                Button(role: .destructive) { confirmCleanup = true } label: {
                                    Label("Move \(preview.fileCount) files to Mac Trash…", systemImage: "trash").frame(maxWidth: .infinity).padding(.vertical, 8)
                                }.buttonStyle(.bordered).disabled(model.busy || model.sessionActionIssue != nil).accessibilityIdentifier("trashPreviousSessions")
                            }
                        } else {
                            Button { Task { await model.previewCleanup() } } label: {
                                Text("Review older files…").frame(maxWidth: .infinity).padding(.vertical, 8)
                            }.buttonStyle(.bordered).disabled(model.busy || model.sessionActionIssue != nil).accessibilityIdentifier("reviewOlderFiles")
                        }
                    }.padding(22).background(.white, in: RoundedRectangle(cornerRadius: 18))
                    if let issue = model.sessionActionIssue {
                        Label(issue, systemImage: "info.circle").font(.callout).foregroundStyle(AppPalette.secondary)
                    }
                    if model.busy { ProgressView("Updating your Mac…").frame(maxWidth: .infinity) }
                    if let notice = model.sessionNotice {
                        Label(notice, systemImage: "checkmark.circle.fill").foregroundStyle(AppPalette.accent).accessibilityIdentifier("sessionNotice")
                    }
                    if let error = model.error { Text(error).foregroundStyle(.red).accessibilityIdentifier("sessionError") }
                }.padding(28)
            }
            .background(AppPalette.paper)
            .foregroundStyle(AppPalette.ink)
            .navigationTitle("Screenshot sessions")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Close") { dismiss() }.disabled(model.busy) } }
            .confirmationDialog("Start a new session?", isPresented: $confirmReset, titleVisibility: .visible) {
                Button("Reset count to 0") { Task { await model.startNewSession() } }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("All \(model.captures.count) screenshots from this session will stay on your Mac, including \(model.pending.count) not yet marked as done. New screenshots will start at 1.")
            }
            .confirmationDialog("Move previous sessions to Mac Trash?", isPresented: $confirmCleanup, titleVisibility: .visible) {
                Button("Move \(model.cleanupPreview?.fileCount ?? 0) files to Trash", role: .destructive) { Task { await model.trashPreviousSessions() } }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This moves \(model.cleanupPreview?.fileCount ?? 0) files (\(model.cleanupPreview?.sizeDescription ?? "0 bytes")) from older sessions, including original screenshots and finished PNGs. This session is kept. Restore files from Trash on your Mac if needed.")
            }
        }
        .tint(AppPalette.accent)
        .presentationSizing(.page)
        .presentationDetents([.large])
        .interactiveDismissDisabled(model.busy)
    }
}
