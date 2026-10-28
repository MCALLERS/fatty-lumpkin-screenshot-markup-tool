import SwiftUI

struct TractatusThought {
    let text: String
    let proposition: String
    static let all = [
        TractatusThought(text: "We make to ourselves pictures of facts.", proposition: "2.1"),
        TractatusThought(text: "The picture is a model of reality.", proposition: "2.12"),
        TractatusThought(text: "What can be shown cannot be said.", proposition: "4.1212")
    ]
}

struct LudwigThoughtView: View {
    let thought: TractatusThought
    let showAbout: () -> Void
    var body: some View {
        Button(action: showAbout) {
            HStack(spacing: 14) {
                Image("LudwigPortrait").resizable().scaledToFit().frame(width: 78, height: 58).accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 5) {
                    Text("“\(thought.text)”").font(.system(.subheadline, design: .serif)).italic().fixedSize(horizontal: false, vertical: true)
                    Text("Ludwig Wittgenstein · Tractatus \(thought.proposition)").font(.caption2).foregroundStyle(AppPalette.secondary)
                }
                Spacer(minLength: 8)
                Image(systemName: "info.circle").font(.body).foregroundStyle(AppPalette.secondary).frame(width: 44, height: 44)
            }.frame(minHeight: 64).contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(thought.text) Ludwig Wittgenstein, Tractatus, proposition \(thought.proposition).")
        .accessibilityHint("Opens the story behind Ludwig and the source of these quotations.")
        .accessibilityIdentifier("ludwigThought")
    }
}

struct AboutLudwigView: View {
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    Image("LudwigPortrait").resizable().scaledToFit().frame(maxWidth: .infinity).frame(height: 240).accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Early Ludwig, still making his point.").font(.system(.title2, design: .serif, weight: .semibold))
                        Text("An early Wittgenstein allusion, with a practical purpose: give your AI an example, then mark what you mean.").foregroundStyle(AppPalette.secondary)
                    }
                    Divider()
                    ForEach(TractatusThought.all, id: \.proposition) { thought in
                        VStack(alignment: .leading, spacing: 6) {
                            Text("“\(thought.text)”").font(.system(.body, design: .serif)).italic()
                            Text("Tractatus Logico-Philosophicus · \(thought.proposition)").font(.caption).foregroundStyle(AppPalette.secondary)
                        }
                    }
                    Text("The quotations change when you open the workspace or finish an image. There is no timer while you draw.").font(.callout).foregroundStyle(AppPalette.secondary)
                    Link(destination: URL(string: "https://www.wittgensteinproject.org/w/index.php/Tractatus_Logico-Philosophicus_(English)")!) {
                        Label("Read the Tractatus · 1922 translation", systemImage: "arrow.up.right.square")
                    }.font(.callout)
                    Text("English translation by C. K. Ogden, with assistance from F. P. Ramsey. The Ludwig illustration is the app’s original brand artwork.").font(.caption).foregroundStyle(AppPalette.secondary)
                }.padding(28).frame(maxWidth: 560).frame(maxWidth: .infinity)
            }
            .background(AppPalette.paper)
            .foregroundStyle(AppPalette.ink)
            .navigationTitle("A thought from Ludwig")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Close") { dismiss() } } }
        }.tint(AppPalette.accent).presentationSizing(.page)
    }
}
