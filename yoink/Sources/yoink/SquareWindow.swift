import AppKit
import QuartzCore
import YoinkCore

/// One borderless, non-activating floating panel per square (Decisions #4, #5). It never
/// becomes key or main, so hover and click leave the frontmost app active.
final class SquarePanel: NSPanel {
    init(size: CGFloat) {
        super.init(contentRect: NSRect(x: 0, y: 0, width: size, height: size), styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        isFloatingPanel = true
        level = .floating
        hidesOnDeactivate = false
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        isRestorable = false
        isReleasedWhenClosed = false
        isMovable = false
        animationBehavior = .none
        // Default single-Space behavior (Decision #29): never all Spaces or full-screen auxiliary.
        collectionBehavior = [.ignoresCycle]
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

@MainActor
protocol SquareViewDelegate: AnyObject {
    func squareHover(_ view: SquareView, inside: Bool)
    func squarePressBegan(_ view: SquareView)
    func squareDragBegan(_ view: SquareView)
    func squareDragEnded(_ view: SquareView)
    func squareClicked(_ view: SquareView)
    func squareContextMenu(_ view: SquareView, event: NSEvent)
}

/// Draws the square art, the label, and the transient checkmark. The whole bounds keep a
/// barely visible fill so clicks never pass through transparent pixels at low opacity.
final class SquareView: NSView {
    let squareID: UUID
    weak var delegate: SquareViewDelegate?

    private let content = CALayer()
    private let art = CALayer()
    private let labelLayer = CATextLayer()
    private let checkLayer = CALayer()
    private var tracker: PointerTracker?
    private var pressWindowOrigin = NSPoint.zero
    private var pressMouse = NSPoint.zero
    private var feedbackGeneration = 0

    private(set) var label = ""
    private(set) var locked = false
    private(set) var opacity: CGFloat = 0.85
    private(set) var isDragging = false

    init(squareID: UUID, size: CGFloat) {
        self.squareID = squareID
        super.init(frame: NSRect(x: 0, y: 0, width: size, height: size))
        wantsLayer = true
        layer?.backgroundColor = NSColor(white: 1, alpha: 0.02).cgColor
        layer?.addSublayer(content)
        content.addSublayer(art)
        content.addSublayer(labelLayer)
        content.addSublayer(checkLayer)
        art.contentsGravity = .resizeAspect
        checkLayer.contents = Art.checkmark
        checkLayer.contentsGravity = .resizeAspect
        checkLayer.isHidden = true
        labelLayer.alignmentMode = .center
        labelLayer.foregroundColor = Art.burntOrange700.cgColor
        labelLayer.truncationMode = .none
        addTrackingArea(NSTrackingArea(rect: .zero, options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect], owner: self))
        setAccessibilityElement(true)
        setAccessibilityRole(.button)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override var isFlipped: Bool { true }

    func configure(label: String, text: String, locked: Bool, opacity: CGFloat) {
        self.label = label
        self.locked = locked
        self.opacity = opacity
        setAccessibilityLabel(label)
        setAccessibilityHelp(text)
        layoutLayers()
    }

    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        layoutLayers()
    }

    private func layoutLayers() {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        let b = bounds
        let scale = window?.backingScaleFactor ?? NSScreen.main?.backingScaleFactor ?? 2
        content.frame = b
        art.frame = b
        art.contents = locked ? (Art.squareLocked ?? Art.square) : Art.square
        art.opacity = Float(opacity)
        art.isHidden = isDragging
        // The label stays readable at low opacity (Visual spec: readable at 30%).
        let labelAlpha = Float(0.5 + 0.5 * opacity)
        let pointSize = Art.labelPointSize(for: label, squareSize: b.width)
        let font = Art.labelFont(size: pointSize)
        labelLayer.font = font
        labelLayer.fontSize = pointSize
        labelLayer.string = label
        labelLayer.contentsScale = scale
        let lineHeight = ceil(font.ascender - font.descender)
        let center = CGPoint(x: b.width * Art.faceCenter.x, y: b.height * Art.faceCenter.y)
        labelLayer.frame = CGRect(x: 0, y: center.y - lineHeight / 2, width: b.width, height: lineHeight)
            .offsetBy(dx: center.x - b.width / 2, dy: 0)
        labelLayer.opacity = labelAlpha
        labelLayer.isHidden = isDragging || !checkLayer.isHidden
        let checkSize = b.width * 0.56
        checkLayer.frame = CGRect(x: center.x - checkSize / 2, y: center.y - checkSize / 2, width: checkSize, height: checkSize)
        checkLayer.opacity = labelAlpha
        CATransaction.commit()
    }

    func setDragging(_ dragging: Bool) {
        isDragging = dragging
        layoutLayers()
    }

    // MARK: Feedback (Decision #33)

    func showCheckmark(shake: Bool) {
        feedbackGeneration += 1
        let generation = feedbackGeneration
        checkLayer.isHidden = false
        layoutLayers()
        if shake {
            let animation = CAKeyframeAnimation(keyPath: "transform.translation.x")
            animation.values = [0, -4, 4, -3, 3, -1.5, 0]
            animation.duration = 0.36
            animation.timingFunction = CAMediaTimingFunction(name: .easeOut)
            content.add(animation, forKey: "shake")
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in
            guard let self, self.feedbackGeneration == generation else { return }
            self.checkLayer.isHidden = true
            self.layoutLayers()
        }
    }

    // MARK: Mouse (Decision #30)

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func mouseEntered(with event: NSEvent) { delegate?.squareHover(self, inside: true) }
    override func mouseExited(with event: NSEvent) { delegate?.squareHover(self, inside: false) }

    override func mouseDown(with event: NSEvent) {
        if event.modifierFlags.contains(.control) {
            delegate?.squareContextMenu(self, event: event)
            return
        }
        pressMouse = NSEvent.mouseLocation
        pressWindowOrigin = window?.frame.origin ?? .zero
        tracker = PointerTracker(start: pressMouse, locked: locked)
        delegate?.squarePressBegan(self)
    }

    override func mouseDragged(with event: NSEvent) {
        guard var t = tracker else { return }
        let mouse = NSEvent.mouseLocation
        let follows = t.moved(to: mouse)
        tracker = t
        guard follows, let window else { return }
        if !isDragging {
            setDragging(true)
            delegate?.squareDragBegan(self)
        }
        window.setFrameOrigin(NSPoint(x: pressWindowOrigin.x + mouse.x - pressMouse.x, y: pressWindowOrigin.y + mouse.y - pressMouse.y))
    }

    override func mouseUp(with event: NSEvent) {
        guard let t = tracker else { return }
        tracker = nil
        let inside = window?.frame.contains(NSEvent.mouseLocation) ?? false
        switch t.release(insideSquare: inside) {
        case .copy: delegate?.squareClicked(self)
        case .endDrag:
            setDragging(false)
            delegate?.squareDragEnded(self)
        case .nothing: break
        }
    }

    override func rightMouseDown(with event: NSEvent) {
        delegate?.squareContextMenu(self, event: event)
    }

    override func accessibilityPerformPress() -> Bool {
        delegate?.squareClicked(self)
        return true
    }
}
