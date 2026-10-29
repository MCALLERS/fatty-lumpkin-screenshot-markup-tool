import SwiftUI

struct TextNoteComposer: View {
    @ObservedObject var model: WorkspaceModel
    let editor: TextNoteEditor
    @State private var note: TextNote
    @FocusState private var textFocused: Bool
    @State private var confirmDelete = false

    init(model: WorkspaceModel, editor: TextNoteEditor) {
        self.model = model; self.editor = editor
        _note = State(initialValue: editor.note)
    }
    private var imageSize: CGSize { CGSize(width: model.current?.width ?? 1, height: model.current?.height ?? 1) }
    private var baseFontSize: Double { TextNote.new(at: .zero, imageSize: imageSize).fontSize }
    private var trimmedText: String { note.text.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var tooLong: Bool { trimmedText.count > 1000 }
    private enum NoteSize: String, CaseIterable {
        case small = "Small", medium = "Medium", large = "Large"
        var scale: Double { switch self { case .small: 0.75; case .medium: 1; case .large: 1.4 } }
    }
    private func fontSize(for size: NoteSize) -> Double {
        var candidate = note; candidate.fontSize = baseFontSize * size.scale
        return TextNoteRenderer.normalized(candidate, imageSize: imageSize).fontSize
    }
    private var selectedSize: Binding<NoteSize> {
        Binding(get: {
            NoteSize.allCases.min { abs(fontSize(for: $0) - note.fontSize) < abs(fontSize(for: $1) - note.fontSize) } ?? .medium
        }, set: { note.fontSize = fontSize(for: $0) })
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Label("Say what you see.", systemImage: "mic")
                        .font(.title2.weight(.semibold)).foregroundStyle(AppPalette.ink)
                    Text("Tap the microphone on the iPad keyboard and speak. You can also type. Review the words before placing your note.")
                        .foregroundStyle(AppPalette.secondary)
                    TextEditor(text: $note.text)
                        .focused($textFocused)
                        .font(.body).scrollContentBackground(.hidden)
                        .frame(minHeight: 150, maxHeight: 240)
                        .padding(12).background(.white, in: RoundedRectangle(cornerRadius: 12))
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(AppPalette.secondary.opacity(0.3)))
                        .accessibilityLabel("Note text").accessibilityIdentifier("noteText")
                    HStack {
                        Text("Text size").fontWeight(.medium)
                        Spacer()
                        Picker("Text size", selection: selectedSize) {
                            ForEach(NoteSize.allCases, id: \.self) { size in Text(size.rawValue).tag(size) }
                        }.pickerStyle(.segmented).frame(maxWidth: 280)
                    }
                    Text("\(trimmedText.count) / 1,000 characters")
                        .font(.caption).foregroundStyle(tooLong ? Color.red : AppPalette.secondary)
                    if let error = model.error {
                        Label(error, systemImage: "exclamationmark.circle").foregroundStyle(.red).accessibilityIdentifier("noteError")
                    }
                    Text("Your note can be moved or edited on the picture. Tap Draw when you’re ready to use Pencil again.")
                        .font(.footnote).foregroundStyle(AppPalette.secondary)
                    Text("Microphone missing? Check Settings → General → Keyboard → Enable Dictation on your iPad.")
                        .font(.footnote).foregroundStyle(AppPalette.secondary)
                    if !editor.isNew {
                        Button(role: .destructive) { textFocused = false; confirmDelete = true } label: {
                            Label("Delete note", systemImage: "trash")
                        }.accessibilityIdentifier("deleteTextNote")
                    }
                }.padding(24)
            }.background(AppPalette.paper)
                .navigationTitle(editor.isNew ? "Text / voice note" : "Edit note")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { textFocused = false; model.cancelNoteEditing() }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button(editor.isNew ? "Add note" : "Save note") {
                            textFocused = false
                            _ = model.commitNote(note)
                        }.fontWeight(.semibold).disabled(trimmedText.isEmpty || tooLong)
                            .accessibilityIdentifier("saveTextNote")
                    }
                }
                .confirmationDialog("Delete this note?", isPresented: $confirmDelete, titleVisibility: .visible) {
                    Button("Delete note", role: .destructive) { _ = model.deleteEditingNote() }
                    Button("Keep note", role: .cancel) {}
                } message: { Text("Your Pencil marks stay in place. Undo can restore the note.") }
                .task { await Task.yield(); textFocused = true }
        }.tint(AppPalette.accent).preferredColorScheme(.light)
            .interactiveDismissDisabled().presentationDetents([.large])
    }
}
