import AppKit
import QuartzCore
import YoinkCore

/// Borderless, non-activating, click-through overlay used by the hover preview, the burst,
/// and the drag animation. It never becomes key or main and ignores every mouse event.
final class OverlayPanel: NSPanel {
    init(level: NSWindow.Level) {
        super.init(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: true)
        isFloatingPanel = true // sets the floating level, so the requested level goes after it
        self.level = level
        hidesOnDeactivate = false
        ignoresMouseEvents = true
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        isRestorable = false
        isReleasedWhenClosed = false
        animationBehavior = .none
        collectionBehavior = [.ignoresCycle, .transient]
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

/// Hover preview (Decisions #8, #31): complete text, line breaks kept, beside the square,
/// wrapped at about 480 pt, never taller than the display, ending with "… N more lines".
@MainActor
final class PreviewController {
    static let maxWidth: CGFloat = 480
    private let padding: CGFloat = 10
    private let gap: CGFloat = 8
    private let panel = OverlayPanel(level: NSWindow.Level(rawValue: NSWindow.Level.floating.rawValue + 1))
    private let background = NSView()
    private let textField = NSTextField(labelWithString: "")
    private let font = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)

    init() {
        background.wantsLayer = true
        background.layer?.cornerRadius = 8
        background.layer?.borderWidth = 1
        textField.font = font
        textField.maximumNumberOfLines = 0
        textField.lineBreakMode = .byClipping
        textField.isSelectable = false
        background.addSubview(textField)
        panel.contentView = background
    }

    func show(text: String, beside squareFrame: NSRect, on screen: NSScreen) {
        let dark = NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        // Brand tokens: Surface Elevated / Text Primary / Border Strong for each mode.
        background.layer?.backgroundColor = (dark ? NSColor(srgbRed: 0x30 / 255, green: 0x34 / 255, blue: 0x38 / 255, alpha: 0.97)
                                                  : NSColor(srgbRed: 0xFA / 255, green: 0xF7 / 255, blue: 0xF2 / 255, alpha: 0.97)).cgColor
        background.layer?.borderColor = (dark ? NSColor(srgbRed: 0x72 / 255, green: 0x79 / 255, blue: 0x82 / 255, alpha: 1)
                                              : NSColor(srgbRed: 0x8F / 255, green: 0x88 / 255, blue: 0x7F / 255, alpha: 1)).cgColor
        textField.textColor = dark ? NSColor(srgbRed: 0xF2 / 255, green: 0xEE / 255, blue: 0xE9 / 255, alpha: 1)
                                   : NSColor(srgbRed: 0x1A / 255, green: 0x1E / 255, blue: 0x22 / 255, alpha: 1)

        let visible = screen.visibleFrame
        let lineHeight = ceil(font.ascender - font.descender + font.leading)
        let maxLines = max(1, Int((visible.height - 2 * padding - 4) / lineHeight))
        let attributes: [NSAttributedString.Key: Any] = [.font: font]
        var widths: [Character: Double] = [:]
        let layout = PreviewLayout.make(text: text, maxWidth: Double(Self.maxWidth - 2 * padding - 2), maxLines: maxLines) { ch in
            if let w = widths[ch] { return w }
            let w = Double((String(ch) as NSString).size(withAttributes: attributes).width)
            widths[ch] = w
            return w
        }
        // An empty snippet still gets a visible (empty) preview line.
        textField.stringValue = layout.displayText
        let textSize = textField.intrinsicContentSize
        let size = NSSize(width: ceil(min(Self.maxWidth, max(textSize.width, 16)) + 2 * padding),
                          height: min(visible.height, ceil(max(textSize.height, lineHeight)) + 2 * padding))
        textField.frame = NSRect(x: padding, y: padding, width: size.width - 2 * padding, height: size.height - 2 * padding)

        var x = squareFrame.maxX + gap
        if x + size.width > visible.maxX { x = squareFrame.minX - gap - size.width }
        x = min(max(x, visible.minX), visible.maxX - size.width)
        var y = squareFrame.maxY - size.height
        y = min(max(y, visible.minY), visible.maxY - size.height)
        panel.setFrame(NSRect(origin: NSPoint(x: x, y: y), size: size), display: true)
        panel.orderFrontRegardless()
    }

    func hide() {
        panel.orderOut(nil)
    }
}

/// Burst feedback (Decision #11): short rays radiating from the square, drawn in a
/// click-through overlay so the square's hit area never grows. Under Reduce Motion the rays
/// fade in place without moving.
@MainActor
enum BurstEffect {
    static func play(around square: NSRect, reduceMotion: Bool) {
        let size = square.width * 2.4
        let frame = NSRect(x: square.midX - size / 2, y: square.midY - size / 2, width: size, height: size)
        let panel = OverlayPanel(level: NSWindow.Level(rawValue: NSWindow.Level.floating.rawValue + 1))
        let view = NSView(frame: NSRect(origin: .zero, size: frame.size))
        view.wantsLayer = true
        panel.contentView = view
        panel.setFrame(frame, display: false)
        panel.orderFrontRegardless()

        let colors = [Art.periwinkle500, Art.burntOrange500, Art.amber500]
        let rays = 10
        let duration = reduceMotion ? 0.35 : 0.45
        let center = CGPoint(x: size / 2, y: size / 2)
        let startRadius = square.width * 0.52
        let travel = square.width * 0.42
        for i in 0..<rays {
            let angle = CGFloat(i) / CGFloat(rays) * 2 * .pi + .pi / 20
            let ray = CAShapeLayer()
            let length = square.width * 0.14
            let path = CGMutablePath()
            path.move(to: .zero)
            path.addLine(to: CGPoint(x: length, y: 0))
            ray.path = path
            ray.lineWidth = max(3, square.width * 0.05)
            ray.lineCap = .round
            ray.strokeColor = colors[i % colors.count].cgColor
            ray.position = CGPoint(x: center.x + cos(angle) * startRadius, y: center.y + sin(angle) * startRadius)
            ray.setAffineTransform(CGAffineTransform(rotationAngle: angle))
            ray.opacity = 0
            view.layer?.addSublayer(ray)

            let fade = CAKeyframeAnimation(keyPath: "opacity")
            fade.values = [0, 1, 0]
            fade.keyTimes = [0, 0.25, 1]
            var animations: [CAAnimation] = [fade]
            if !reduceMotion {
                let move = CABasicAnimation(keyPath: "position")
                move.toValue = NSValue(point: NSPoint(x: center.x + cos(angle) * (startRadius + travel), y: center.y + sin(angle) * (startRadius + travel)))
                move.timingFunction = CAMediaTimingFunction(name: .easeOut)
                animations.append(move)
            }
            let group = CAAnimationGroup()
            group.animations = animations
            group.duration = duration
            ray.add(group, forKey: "burst")
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + duration + 0.05) {
            panel.orderOut(nil)
            panel.close()
        }
    }
}

/// While a square is dragged it shows the walking mascot art. The animation extends beyond
/// the square, so it lives in a click-through child window that moves with the square.
@MainActor
final class DragAnimation {
    private let panel = OverlayPanel(level: .floating)
    private let imageView = NSImageView()
    private let label = NSTextField(labelWithString: "")

    init() {
        imageView.imageScaling = .scaleProportionallyUpOrDown
        imageView.animates = true
        imageView.image = Art.dragAnimation
        label.alignment = .center
        label.textColor = Art.burntOrange700
        let root = NSView()
        root.addSubview(imageView)
        root.addSubview(label)
        panel.contentView = root
    }

    func start(on square: NSWindow, label text: String, opacity: CGFloat, reduceMotion: Bool) {
        let s = square.frame.width
        let size = NSSize(width: s * Art.dragScale, height: s * Art.dragScale * 449 / 450)
        // Place the GIF so its body lines up with the square.
        let origin = NSPoint(x: square.frame.midX - size.width * Art.dragBodyCenter.x,
                             y: square.frame.midY - size.height * (1 - Art.dragBodyCenter.y))
        panel.setFrame(NSRect(origin: origin, size: size), display: false)
        imageView.frame = NSRect(origin: .zero, size: size)
        imageView.animates = !reduceMotion
        imageView.alphaValue = opacity
        let pointSize = Art.labelPointSize(for: text, squareSize: s)
        label.font = Art.labelFont(size: pointSize)
        label.stringValue = text
        label.alphaValue = 0.5 + 0.5 * opacity
        label.sizeToFit()
        let bodyCenter = NSPoint(x: size.width * Art.dragBodyCenter.x, y: size.height * (1 - Art.dragBodyCenter.y))
        label.frame = NSRect(x: bodyCenter.x - s / 2, y: bodyCenter.y - label.frame.height / 2, width: s, height: label.frame.height)
        square.addChildWindow(panel, ordered: .above)
        panel.orderFrontRegardless()
    }

    func stop() {
        panel.parent?.removeChildWindow(panel)
        panel.orderOut(nil)
    }
}
