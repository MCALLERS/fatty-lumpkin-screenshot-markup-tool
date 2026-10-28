import CoreGraphics
import ImageIO
import UniformTypeIdentifiers
import Foundation

// Deterministic vector rendering of Branding/app-mark.svg, approved for the website.
// iPad icons are opaque; macOS retains the mark's rounded outer edge.
let root = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
let size = 1024
func color(_ hex: UInt32) -> CGColor {
    CGColor(colorSpace: CGColorSpace(name: CGColorSpace.sRGB)!,
            components: [CGFloat((hex >> 16) & 255) / 255, CGFloat((hex >> 8) & 255) / 255,
                         CGFloat(hex & 255) / 255, 1])!
}
func render(_ filename: String, opaque: Bool) throws {
    let alpha = opaque ? CGImageAlphaInfo.noneSkipLast : CGImageAlphaInfo.premultipliedLast
    guard let context = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8,
                                  bytesPerRow: size * 4, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                  bitmapInfo: alpha.rawValue) else { fatalError("Cannot create icon context") }
    context.setAllowsAntialiasing(true)
    context.translateBy(x: 0, y: CGFloat(size)); context.scaleBy(x: 16, y: -16)
    let ink = color(0x202824), paper = color(0xf6f2e9), pencil = color(0xdf725b)
    context.setFillColor(ink)
    if opaque { context.fill(CGRect(x: 0, y: 0, width: 64, height: 64)) }
    else { context.addPath(CGPath(roundedRect: CGRect(x: 1, y: 1, width: 62, height: 62), cornerWidth: 14, cornerHeight: 14, transform: nil)); context.fillPath() }
    context.setLineCap(.round); context.setLineJoin(.round)
    context.setStrokeColor(paper); context.setLineWidth(3.3)
    for points: [CGPoint] in [
        [.init(x:15,y:25), .init(x:15,y:15), .init(x:27,y:15)],
        [.init(x:37,y:15), .init(x:49,y:15), .init(x:49,y:25)],
        [.init(x:15,y:39), .init(x:15,y:49), .init(x:27,y:49)],
        [.init(x:37,y:49), .init(x:49,y:49), .init(x:49,y:39)]
    ] { context.addLines(between: points); context.strokePath() }
    context.setStrokeColor(pencil); context.setLineWidth(2.7)
    context.move(to: .init(x:21,y:34))
    context.addCurve(to: .init(x:43,y:26), control1: .init(x:18,y:24), control2: .init(x:38,y:18))
    context.addCurve(to: .init(x:28,y:41), control1: .init(x:48,y:34), control2: .init(x:39,y:43))
    context.addCurve(to: .init(x:21,y:33), control1: .init(x:21,y:40), control2: .init(x:19,y:36))
    context.strokePath()
    context.addLines(between: [.init(x:33,y:35), .init(x:46,y:18), .init(x:51,y:22), .init(x:38,y:39), .init(x:30,y:43)])
    context.closePath(); context.setFillColor(pencil); context.setStrokeColor(ink); context.setLineWidth(1.6); context.drawPath(using: .fillStroke)
    context.addLines(between: [.init(x:30,y:43), .init(x:33,y:35), .init(x:38,y:39)])
    context.closePath(); context.setFillColor(paper); context.fillPath()
    guard let image = context.makeImage(),
          let destination = CGImageDestinationCreateWithURL(root.appendingPathComponent(filename) as CFURL, UTType.png.identifier as CFString, 1, nil)
    else { fatalError("Cannot write icon") }
    CGImageDestinationAddImage(destination, image, nil)
    guard CGImageDestinationFinalize(destination) else { fatalError("Cannot finish icon") }
}
try render("AppIcon-1024.png", opaque: true)
try render("AppIcon-mac-1024.png", opaque: false)
