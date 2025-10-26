// SPDX-License-Identifier: MIT
// Copyright (c) 2025 Jimmy Ma
// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "GosuTile",
    platforms: [
        .macOS(.v15),
    ],
    targets: [
        .executableTarget(name: "GosuTile"),
    ]
)
