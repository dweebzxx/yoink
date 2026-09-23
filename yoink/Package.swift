// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "yoink",
    platforms: [.macOS(.v14)],
    targets: [
        // Product state, validation, persistence, undo, grid, history. Foundation only, never AppKit.
        .target(name: "YoinkCore"),
        // AppKit app (squares, previews, menu bar, hotkeys) with SwiftUI only inside Settings.
        .executableTarget(name: "yoink", dependencies: ["YoinkCore"]),
        .testTarget(
            name: "YoinkCoreTests",
            dependencies: ["YoinkCore"],
            resources: [.copy("Fixtures")]
        ),
    ]
)
