import CoreGraphics
import Foundation

/// A connected display as Core sees it. All rects are in points, in the display's own
/// coordinate space with the origin at its top-left corner and y growing downward.
public struct DisplayGeometry: Equatable, Sendable {
    public var id: String
    public var size: CGSize
    /// Usable area (excluding the menu bar and Dock), in display-local top-left coordinates.
    public var usable: CGRect
    public var isMain: Bool

    public init(id: String, size: CGSize, usable: CGRect, isMain: Bool) {
        self.id = id
        self.size = size
        self.usable = usable
        self.isMain = isMain
    }
}

/// Where a square is actually shown right now.
public struct ResolvedPlacement: Equatable, Sendable {
    public var displayID: String
    /// Top-left of the square in the display's local top-left coordinates.
    public var origin: CGPoint
    /// True when the saved display is missing or the saved position had to be clamped.
    public var adjusted: Bool
}

/// Restoration and fallback rules (Decision #26). Resolving never rewrites the stored placement.
public enum PlacementResolver {
    public static func resolve(_ placement: Placement, squareSize: Double, displays: [DisplayGeometry]) -> ResolvedPlacement? {
        if let display = displays.first(where: { $0.id == placement.displayID }) {
            let origin = CGPoint(x: placement.x, y: placement.y)
            let clampedOrigin = clamp(origin, squareSize: squareSize, into: display.usable)
            return ResolvedPlacement(displayID: display.id, origin: clampedOrigin, adjusted: clampedOrigin != origin)
        }
        guard let main = displays.first(where: \.isMain) ?? displays.first else { return nil }
        let relX = placement.displayWidth > 0 ? placement.x / placement.displayWidth : 0
        let relY = placement.displayHeight > 0 ? placement.y / placement.displayHeight : 0
        let origin = CGPoint(x: relX * main.size.width, y: relY * main.size.height)
        return ResolvedPlacement(displayID: main.id, origin: clamp(origin, squareSize: squareSize, into: main.usable), adjusted: true)
    }

    /// Keeps a square fully inside `rect`. If the square is larger than the rect, it pins to the top-left.
    public static func clamp(_ origin: CGPoint, squareSize: Double, into rect: CGRect) -> CGPoint {
        let maxX = max(rect.minX, rect.maxX - squareSize)
        let maxY = max(rect.minY, rect.maxY - squareSize)
        return CGPoint(x: min(max(origin.x, rect.minX), maxX), y: min(max(origin.y, rect.minY), maxY))
    }

    /// Placement for a square the user dropped at `origin` on `display`, clamped to the usable area.
    public static func placementForDrop(origin: CGPoint, squareSize: Double, on display: DisplayGeometry) -> Placement {
        let o = clamp(origin, squareSize: squareSize, into: display.usable)
        return Placement(displayID: display.id, x: o.x, y: o.y, displayWidth: display.size.width, displayHeight: display.size.height)
    }
}

/// Snap to Grid (Decision #40): pure cell assignment on each square's own display.
public enum GridLayout {
    public static let gap: Double = 8

    /// Returns new placements for every square whose display is connected. Squares on a
    /// missing display are left out (they are never moved to another display). If a display
    /// has fewer cells than squares, the squares that find no free cell are left out too.
    public static func snap(_ squares: [Square], squareSize: Double, displays: [DisplayGeometry], gap: Double = GridLayout.gap) -> [UUID: Placement] {
        var result: [UUID: Placement] = [:]
        let step = squareSize + gap
        for display in displays {
            let onDisplay = squares.filter { $0.placement.displayID == display.id }
            guard !onDisplay.isEmpty else { continue }
            let cols = max(1, Int(((display.usable.width + gap) / step).rounded(.down)))
            let rows = max(1, Int(((display.usable.height + gap) / step).rounded(.down)))
            var taken = Set<Int>()
            for square in onDisplay {
                guard let current = PlacementResolver.resolve(square.placement, squareSize: squareSize, displays: [display]) else { continue }
                let fx = (current.origin.x - display.usable.minX) / step
                let fy = (current.origin.y - display.usable.minY) / step
                var best: (index: Int, distance: Double)?
                for r in 0..<rows {
                    for c in 0..<cols where !taken.contains(r * cols + c) {
                        let d = (Double(c) - fx) * (Double(c) - fx) + (Double(r) - fy) * (Double(r) - fy)
                        if best == nil || d < best!.distance { best = (r * cols + c, d) }
                    }
                }
                guard let chosen = best else { continue }
                taken.insert(chosen.index)
                let c = chosen.index % cols, r = chosen.index / cols
                result[square.id] = Placement(
                    displayID: display.id,
                    x: display.usable.minX + Double(c) * step,
                    y: display.usable.minY + Double(r) * step,
                    displayWidth: display.size.width,
                    displayHeight: display.size.height
                )
            }
        }
        return result
    }
}

/// Where new squares go: near the center of the main display, cascading so a new square
/// does not sit exactly on top of an existing one.
public enum NewSquarePlacement {
    public static let cascade: Double = 20

    public static func forNewSquare(existing: [Square], squareSize: Double, displays: [DisplayGeometry]) -> Placement? {
        guard let main = displays.first(where: \.isMain) ?? displays.first else { return nil }
        var origin = CGPoint(x: main.usable.midX - squareSize / 2, y: main.usable.midY - squareSize / 2)
        let occupied = Set(existing.filter { $0.placement.displayID == main.id }.map { CGPoint(x: $0.placement.x, y: $0.placement.y) }.map(key))
        var tries = 0
        while occupied.contains(key(origin)) && tries < 50 {
            origin.x += cascade
            origin.y += cascade
            tries += 1
        }
        return PlacementResolver.placementForDrop(origin: origin, squareSize: squareSize, on: main)
    }

    /// A duplicate sits offset from its source so it does not stack invisibly on it.
    public static func forDuplicate(of source: Square, squareSize: Double, displays: [DisplayGeometry]) -> Placement {
        guard let resolved = PlacementResolver.resolve(source.placement, squareSize: squareSize, displays: displays),
              let display = displays.first(where: { $0.id == resolved.displayID }) else {
            var p = source.placement
            p.x += cascade
            p.y += cascade
            return p
        }
        var origin = CGPoint(x: resolved.origin.x + cascade, y: resolved.origin.y + cascade)
        if origin.x + squareSize > display.usable.maxX || origin.y + squareSize > display.usable.maxY {
            origin = CGPoint(x: resolved.origin.x - cascade, y: resolved.origin.y - cascade)
        }
        return PlacementResolver.placementForDrop(origin: origin, squareSize: squareSize, on: display)
    }

    private static func key(_ p: CGPoint) -> String { "\(Int(p.x.rounded())),\(Int(p.y.rounded()))" }
}
