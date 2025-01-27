// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "AsyncUndoManager",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
        .visionOS(.v1),
    ],
    products: [
        .library(
            name: "AsyncUndoManager",
            targets: ["AsyncUndoManager"]),
    ],
    targets: [
        .target(
            name: "AsyncUndoManager"),
        .testTarget(
            name: "AsyncUndoManagerTests",
            dependencies: ["AsyncUndoManager"]
        ),
    ]
)
