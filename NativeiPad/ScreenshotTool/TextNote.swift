import UIKit

/// Editable annotation geometry is stored in the original screenshot's pixels.
struct TextNote: Codable, Identifiable, Equatable {
    var id: UUID = UUID()
    var text: String
    var x: Double
    var y: Double
    var width: Double
    var fontSize: Double

    static let maximumCharacterCount = 1000

    static func new(at point: CGPoint, imageSize: CGSize) -> TextNote {
        let shortEdge = min(imageSize.width, imageSize.height)
        return TextNoteRenderer.normalized(
            TextNote(text: "", x: Double(point.x), y: Double(point.y), width: Double(imageSize.width * 0.42), fontSize: Double(max(12, shortEdge * 0.035))),
            imageSize: imageSize
        )
    }
}

/// The UIKit overlay and PNG export both use this source-coordinate renderer.
enum TextNoteRenderer {
    private struct Layout {
        let font: UIFont
        let padding: CGFloat
        let textHeight: CGFloat
        let height: CGFloat
        let attributes: [NSAttributedString.Key: Any]
    }

    private static func valid(_ size: CGSize) -> Bool {
        size.width.isFinite && size.height.isFinite && size.width >= 1 && size.height >= 1
    }

    private static func safeSize(_ size: CGSize) -> CGSize {
        CGSize(width: size.width.isFinite ? max(1, size.width) : 1,
               height: size.height.isFinite ? max(1, size.height) : 1)
    }

    private static func layout(for note: TextNote) -> Layout {
        let font = UIFont.systemFont(ofSize: CGFloat(note.fontSize), weight: .medium)
        let padding = CGFloat(note.fontSize) * 0.65
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineBreakMode = .byWordWrapping
        paragraph.lineSpacing = CGFloat(note.fontSize) * 0.12
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: UIColor(red: 0.125, green: 0.157, blue: 0.141, alpha: 1),
            .paragraphStyle: paragraph
        ]
        // Measure exactly the same attributed text and width used by draw(_:in:).
        // An empty draft still needs a line-sized hit target while it is edited.
        let measured = (note.text.isEmpty ? " " : note.text) as NSString
        let height = ceil(measured.boundingRect(
            with: CGSize(width: max(1, CGFloat(note.width) - padding * 2), height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading], attributes: attributes, context: nil
        ).height)
        let textHeight = max(ceil(font.lineHeight), height)
        return Layout(font: font, padding: padding, textHeight: textHeight,
                      height: textHeight + padding * 2, attributes: attributes)
    }

    /// Repairs geometry for an intentional edit. Text is never shortened here.
    static func normalized(_ note: TextNote, imageSize: CGSize) -> TextNote {
        let size = safeSize(imageSize), shortEdge = min(size.width, size.height)
        let minimumFont = max(1, max(min(8, shortEdge * 0.1), shortEdge * 0.018))
        let maximumFont = max(minimumFont, max(min(96, shortEdge * 0.2), shortEdge * 0.09))
        let defaultFont = min(maximumFont, max(12, shortEdge * 0.035))
        var result = note
        result.fontSize = Double(min(maximumFont, max(minimumFont, note.fontSize.isFinite ? CGFloat(note.fontSize) : defaultFont)))
        let minimumWidth = min(size.width, max(shortEdge * 0.24, CGFloat(result.fontSize) * 5.3))
        result.width = Double(min(size.width, max(minimumWidth, note.width.isFinite && note.width > 0 ? CGFloat(note.width) : size.width * 0.42)))
        result.x = Double(min(size.width - CGFloat(result.width), max(0, note.x.isFinite ? CGFloat(note.x) : 0)))
        let height = layout(for: result).height
        result.y = Double(min(max(0, size.height - height), max(0, note.y.isFinite ? CGFloat(note.y) : 0)))
        return result
    }

    /// Returns the full card height, even when the text is too tall for the image.
    static func rect(for note: TextNote, imageSize: CGSize) -> CGRect {
        let safe = normalized(note, imageSize: imageSize)
        return CGRect(x: safe.x, y: safe.y, width: safe.width, height: layout(for: safe).height)
    }

    /// Invalid stored geometry must be repaired explicitly, never silently on export.
    static func fits(_ note: TextNote, imageSize: CGSize) -> Bool {
        guard valid(imageSize), note.text.count <= TextNote.maximumCharacterCount,
              [note.x, note.y, note.width, note.fontSize].allSatisfy(\.isFinite),
              note == normalized(note, imageSize: imageSize) else { return false }
        let bounds = rect(for: note, imageSize: imageSize)
        return bounds.minX >= 0 && bounds.minY >= 0 && bounds.maxX <= imageSize.width && bounds.maxY <= imageSize.height
    }

    /// Draws in the current UIKit graphics context without changing its transform.
    /// A note-local view should translate by negative rect.origin before calling.
    static func draw(_ note: TextNote, in imageSize: CGSize) {
        guard valid(imageSize), let context = UIGraphicsGetCurrentContext() else { return }
        let safe = normalized(note, imageSize: imageSize), layout = layout(for: safe)
        let card = CGRect(x: safe.x, y: safe.y, width: safe.width, height: layout.height)
        context.saveGState()
        defer { context.restoreGState() }
        context.setBlendMode(.normal)
        let outline = UIBezierPath(roundedRect: card, cornerRadius: CGFloat(safe.fontSize) * 0.35)
        UIColor(red: 0.98, green: 0.96, blue: 0.90, alpha: 1).setFill()
        outline.fill()
        // Keep the slim border inside the measured card bounds.
        let lineWidth = max(0.5, CGFloat(safe.fontSize) * 0.025)
        let border = UIBezierPath(roundedRect: card.insetBy(dx: lineWidth / 2, dy: lineWidth / 2), cornerRadius: CGFloat(safe.fontSize) * 0.35)
        UIColor(red: 0.125, green: 0.157, blue: 0.141, alpha: 0.17).setStroke()
        border.lineWidth = lineWidth; border.stroke()
        let accent = CGRect(x: card.minX + layout.padding * 0.28, y: card.minY + layout.padding,
                            width: max(1, CGFloat(safe.fontSize) * 0.1), height: layout.textHeight)
        UIColor(red: 0.827, green: 0.298, blue: 0.216, alpha: 1).setFill()
        UIBezierPath(roundedRect: accent, cornerRadius: accent.width / 2).fill()
        let textRect = CGRect(x: card.minX + layout.padding, y: card.minY + layout.padding,
                              width: max(1, card.width - layout.padding * 2), height: layout.textHeight)
        (safe.text as NSString).draw(with: textRect, options: [.usesLineFragmentOrigin, .usesFontLeading],
                                    attributes: layout.attributes, context: nil)
    }
}
