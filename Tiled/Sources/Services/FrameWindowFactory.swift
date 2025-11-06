// SPDX-License-Identifier: MIT
// Copyright (c) 2025 Jimmy Ma

import Cocoa

/// Factory for creating FrameWindow instances
@MainActor
protocol FrameWindowFactory {
    func createFrameWindow(geometry: FrameGeometry) -> FrameWindowProtocol
}

/// Production factory that creates real UI windows
@MainActor
class RealFrameWindowFactory: FrameWindowFactory {
    private let styleProvider: StyleProvider

    init(styleProvider: StyleProvider = StyleProvider()) {
        self.styleProvider = styleProvider
    }

    func createFrameWindow(geometry: FrameGeometry) -> FrameWindowProtocol {
        return FrameWindow(geo: geometry, styleProvider: styleProvider)
    }
}
