import AppKit
import ColorSync
import YoinkCore

/// Bridges NSScreen to Core's display-local, top-left coordinates. AppKit global coordinates
/// have a bottom-left origin on the primary display and can be negative on other displays.
@MainActor
enum ScreenMap {
    /// Persistent identity: the display UUID from ColorSync, stable across reboots and
    /// reconnection, unlike `CGDirectDisplayID` or `NSScreen` order.
    static func id(for screen: NSScreen) -> String {
        guard let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else { return "unknown" }
        let displayID = CGDirectDisplayID(number.uint32Value)
        if let uuid = CGDisplayCreateUUIDFromDisplayID(displayID)?.takeRetainedValue(),
           let string = CFUUIDCreateString(nil, uuid) as String? {
            return string
        }
        return "display-\(displayID)"
    }

    static func geometry(for screen: NSScreen) -> DisplayGeometry {
        let f = screen.frame
        let v = screen.visibleFrame
        let usable = CGRect(x: v.minX - f.minX, y: f.maxY - v.maxY, width: v.width, height: v.height)
        return DisplayGeometry(id: id(for: screen), size: f.size, usable: usable, isMain: screen == NSScreen.screens.first)
    }

    static var displays: [DisplayGeometry] { NSScreen.screens.map(geometry(for:)) }

    static func screen(withID id: String) -> NSScreen? {
        NSScreen.screens.first { self.id(for: $0) == id }
    }

    /// Window frame for a square whose top-left sits at `origin` on `screen`.
    static func frame(origin: CGPoint, size: Double, on screen: NSScreen) -> NSRect {
        let f = screen.frame
        return NSRect(x: f.minX + origin.x, y: f.maxY - origin.y - size, width: size, height: size)
    }

    /// The screen a frame mostly overlaps, and the frame's top-left on it.
    static func locate(_ frame: NSRect) -> (screen: NSScreen, origin: CGPoint)? {
        let screens = NSScreen.screens
        guard !screens.isEmpty else { return nil }
        let best = screens.max { a, b in
            area(a.frame.intersection(frame)) < area(b.frame.intersection(frame))
        } ?? screens[0]
        let screen = area(best.frame.intersection(frame)) > 0 ? best : nearest(to: frame, in: screens)
        return (screen, CGPoint(x: frame.minX - screen.frame.minX, y: screen.frame.maxY - frame.maxY))
    }

    private static func area(_ r: NSRect) -> CGFloat { r.isNull ? 0 : r.width * r.height }

    private static func nearest(to frame: NSRect, in screens: [NSScreen]) -> NSScreen {
        let c = CGPoint(x: frame.midX, y: frame.midY)
        return screens.min { a, b in
            hypot(a.frame.midX - c.x, a.frame.midY - c.y) < hypot(b.frame.midX - c.x, b.frame.midY - c.y)
        } ?? screens[0]
    }
}
