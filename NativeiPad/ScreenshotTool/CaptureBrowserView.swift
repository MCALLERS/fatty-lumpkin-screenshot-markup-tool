import SwiftUI

struct CaptureBrowserView: View {
    @ObservedObject var model: WorkspaceModel
    let snapshot: CaptureBrowserSnapshot
    @Environment(\.dismiss) private var dismiss
    @State private var search = ""
    @State private var filter = Filter.all

    private enum Filter: String, CaseIterable { case all = "All", pending = "To do", saved = "Saved" }
    private var visibleCaptures: [Capture] {
        snapshot.captures.filter { capture in
            let needsWork = !capture.saved || snapshot.draftIDs.contains(capture.id)
            let matchesFilter = filter == .all || (filter == .pending ? needsWork : capture.saved)
            return matchesFilter && (search.isEmpty || capture.title.localizedStandardContains(search))
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("Show screenshots", selection: $filter) {
                    ForEach(Filter.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                }.pickerStyle(.segmented).padding(.horizontal).padding(.top, 12)
                ScrollViewReader { proxy in
                    VStack(spacing: 0) {
                        HStack(spacing: 16) {
                            Text("\(visibleCaptures.count) screenshots · Oldest first").font(.subheadline).foregroundStyle(.secondary)
                            Spacer()
                            Button("Oldest") { if let id = visibleCaptures.first?.id { withAnimation { proxy.scrollTo(id, anchor: .top) } } }
                                .frame(minHeight: 44).accessibilityIdentifier("jumpOldest")
                            Button("Newest") { if let id = visibleCaptures.last?.id { withAnimation { proxy.scrollTo(id, anchor: .bottom) } } }
                                .frame(minHeight: 44).accessibilityIdentifier("jumpNewest")
                        }.padding().disabled(visibleCaptures.isEmpty)
                        if visibleCaptures.isEmpty {
                            ContentUnavailableView("No matching screenshots", systemImage: "photo.on.rectangle", description: Text("Try another search or choose All."))
                        } else {
                            List(visibleCaptures) { capture in
                                Button {
                                    Task {
                                        if await model.open(capture) { dismiss() }
                                    }
                                } label: {
                                    HStack(spacing: 14) {
                                        Image(systemName: capture.id == snapshot.selectedID ? "photo.fill" : "photo")
                                            .font(.title2).frame(width: 40).foregroundStyle(.secondary)
                                        VStack(alignment: .leading, spacing: 6) {
                                            Text(capture.title).font(.headline).foregroundStyle(.primary).lineLimit(2)
                                            HStack(spacing: 8) {
                                                if capture.id == snapshot.selectedID { Text("Current").fontWeight(.semibold) }
                                                if snapshot.draftIDs.contains(capture.id) { Label("Unfinished drawing", systemImage: "pencil") }
                                                else if capture.saved { Label("Saved on Mac", systemImage: "checkmark.circle") }
                                                else { Text("To do") }
                                            }.font(.subheadline).foregroundStyle(.secondary)
                                        }
                                        Spacer()
                                        if model.loadingID == capture.id { ProgressView() }
                                        else { Image(systemName: "chevron.right").foregroundStyle(.secondary) }
                                    }.padding(.vertical, 10).contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                                .listRowBackground(capture.id == snapshot.selectedID ? Color.green.opacity(0.08) : Color(.secondarySystemGroupedBackground))
                                .id(capture.id).accessibilityIdentifier("capture-" + capture.id)
                            }.listStyle(.insetGrouped).accessibilityIdentifier("screenshotBrowserList")
                        }
                    }
                }.disabled(model.loadingID != nil)
                if let error = model.error {
                    Text(error).font(.callout).foregroundStyle(.red).padding().accessibilityIdentifier("browserError")
                }
                Text("Unfinished drawings stay with each screenshot. New captures appear when you reopen this browser.")
                    .font(.footnote).foregroundStyle(.secondary).padding().frame(maxWidth: .infinity, alignment: .leading)
            }
            .navigationTitle("Screenshots")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $search, prompt: "Search screenshot names")
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Close") { dismiss() }.disabled(model.loadingID != nil) } }
        }
        .presentationSizing(.page)
        .presentationDetents([.large])
        .interactiveDismissDisabled(model.loadingID != nil)
    }
}
