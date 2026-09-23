import AppKit

/// Bundled artwork and brand values (brand/yoink App Asset Palette.md).
@MainActor
enum Art {
    static let square = bundleImage("square")
    static let squareLocked = bundleImage("square-locked")
    static let dragAnimation = Bundle.main.url(forResource: "square-dragged", withExtension: "gif").flatMap(NSImage.init(contentsOf:))

    static let menuBarIcon: NSImage = {
        let image = Bundle.main.image(forResource: "menu-bar-icon") ?? NSImage(size: NSSize(width: 18, height: 18))
        image.size = NSSize(width: 22, height: 22)
        image.isTemplate = true
        image.accessibilityDescription = "yo!nk"
        return image
    }()

    /// Center of the square art's front face, as a fraction of the square (x from left, y from top).
    static let faceCenter = CGPoint(x: 0.555, y: 0.47)

    /// In the drag animation (450 × 449 px), the body is about 318 px tall and centered at (226, 182).
    static let dragScale: CGFloat = 450.0 / 318.0
    static let dragBodyCenter = CGPoint(x: 226.0 / 450.0, y: 182.0 / 449.0)

    // Palette
    static let burntOrange700 = NSColor(srgbRed: 0x8F / 255, green: 0x42 / 255, blue: 0x18 / 255, alpha: 1)
    static let burntOrange300 = NSColor(srgbRed: 0xD4 / 255, green: 0x90 / 255, blue: 0x6A / 255, alpha: 1)
    static let burntOrange900 = NSColor(srgbRed: 0x4A / 255, green: 0x20 / 255, blue: 0x10 / 255, alpha: 1)
    static let burntOrange500 = NSColor(srgbRed: 0xB8 / 255, green: 0x60 / 255, blue: 0x30 / 255, alpha: 1)
    static let periwinkle500 = NSColor(srgbRed: 0x68 / 255, green: 0x78 / 255, blue: 0xC0 / 255, alpha: 1)
    static let periwinkle700 = NSColor(srgbRed: 0x4C / 255, green: 0x62 / 255, blue: 0xA8 / 255, alpha: 1)
    static let amber500 = NSColor(srgbRed: 0xD4 / 255, green: 0xA0 / 255, blue: 0x30 / 255, alpha: 1)

    /// Label typeface: SF Pro Rounded, heavy, in Burnt Orange 700 (matches the "yk!" lettering).
    static func labelFont(size: CGFloat) -> NSFont {
        let base = NSFont.systemFont(ofSize: size, weight: .heavy)
        guard let rounded = base.fontDescriptor.withDesign(.rounded) else { return base }
        return NSFont(descriptor: rounded, size: size) ?? base
    }

    /// Label point size for a square: one character reads larger than two.
    static func labelPointSize(for label: String, squareSize: CGFloat) -> CGFloat {
        squareSize * (label.count <= 1 ? 0.42 : 0.33)
    }

    /// The Decision #33 checkmark: custom vector artwork in the app art's soft 3D style,
    /// Burnt Orange like the "yk!" lettering, with a darker extruded edge and a lit top.
    static let checkmark: NSImage = NSImage(size: NSSize(width: 100, height: 100), flipped: false) { _ in
        guard let ctx = NSGraphicsContext.current?.cgContext else { return false }
        let path = CGMutablePath()
        path.move(to: CGPoint(x: 21, y: 53))
        path.addLine(to: CGPoint(x: 42, y: 31))
        path.addLine(to: CGPoint(x: 81, y: 75))
        let width: CGFloat = 17

        func strokeShape(_ offset: CGPoint) -> CGPath {
            var t = CGAffineTransform(translationX: offset.x, y: offset.y)
            let moved = path.copy(using: &t) ?? path
            return moved.copy(strokingWithWidth: width, lineCap: .round, lineJoin: .round, miterLimit: 10)
        }

        // Soft contact shadow.
        ctx.saveGState()
        ctx.setShadow(offset: CGSize(width: 0, height: -4), blur: 6, color: burntOrange900.withAlphaComponent(0.45).cgColor)
        ctx.addPath(strokeShape(CGPoint(x: 1, y: -4)))
        ctx.setFillColor(burntOrange900.cgColor)
        ctx.fillPath()
        ctx.restoreGState()

        // Extruded side.
        ctx.addPath(strokeShape(CGPoint(x: 1, y: -4)))
        ctx.setFillColor(NSColor(srgbRed: 0x6A / 255, green: 0x2E / 255, blue: 0x12 / 255, alpha: 1).cgColor)
        ctx.fillPath()

        // Face with a top-lit gradient.
        let face = strokeShape(.zero)
        ctx.saveGState()
        ctx.addPath(face)
        ctx.clip()
        let colors = [burntOrange300.cgColor, burntOrange500.cgColor, burntOrange700.cgColor] as CFArray
        if let gradient = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB), colors: colors, locations: [0, 0.45, 1]) {
            ctx.drawLinearGradient(gradient, start: CGPoint(x: 50, y: 88), end: CGPoint(x: 50, y: 20), options: [])
        }
        // Specular highlight along the upper edge.
        var up = CGAffineTransform(translationX: -1.5, y: 4)
        if let highlight = path.copy(using: &up)?.copy(strokingWithWidth: 5, lineCap: .round, lineJoin: .round, miterLimit: 10) {
            ctx.addPath(highlight)
            ctx.setFillColor(NSColor.white.withAlphaComponent(0.38).cgColor)
            ctx.fillPath()
        }
        ctx.restoreGState()
        return true
    }

    private static func bundleImage(_ name: String) -> NSImage? {
        Bundle.main.url(forResource: name, withExtension: "png").flatMap(NSImage.init(contentsOf:))
    }
}
