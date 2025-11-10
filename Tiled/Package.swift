// SPDX-License-Identifier: MIT
// Copyright (c) 2025 Jimmy Ma
// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "Tiled",
    platforms: [
        .macOS(.v15),
    ],
    targets: [
        .executableTarget(
            name: "Tiled",
            path: "Sources"
        ),
        .testTarget(
            name: "TiledTests",
            dependencies: ["Tiled"],
            path: "Tests/TiledTests"
        ),
        .testTarget(
            name: "TiledIntegrationTests",
            dependencies: ["Tiled"],
            path: "Tests/TiledIntegrationTests"
        ),
    ],
    swiftLanguageModes: [.v6]
)

// Configure product name
package.products = [
    .executable(name: "Tile.d", targets: ["Tiled"])
]
