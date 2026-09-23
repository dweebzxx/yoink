import CoreGraphics

/// Click versus drag on a square (Decision #30). Points are in screen coordinates.
public struct PointerTracker: Sendable {
    public static let dragThreshold: Double = 4

    public enum Release: Equatable, Sendable {
        case copy
        case endDrag
        case nothing
    }

    public let start: CGPoint
    public let locked: Bool
    public private(set) var isDragging = false

    public init(start: CGPoint, locked: Bool) {
        self.start = start
        self.locked = locked
    }

    /// Returns true when the square should follow the pointer (unlocked and past the threshold).
    public mutating func moved(to point: CGPoint) -> Bool {
        guard !locked else { return false }
        if !isDragging, hypot(point.x - start.x, point.y - start.y) >= Self.dragThreshold {
            isDragging = true
        }
        return isDragging
    }

    /// A drag never copies. Otherwise a release over the square copies, and a release
    /// outside it does nothing.
    public func release(insideSquare: Bool) -> Release {
        if isDragging { return .endDrag }
        return insideSquare ? .copy : .nothing
    }
}
