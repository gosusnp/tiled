// SPDX-License-Identifier: MIT
// Copyright (c) 2025 Jimmy Ma

import Foundation
@testable import Tiled

/// Test factory that creates mock windows
@MainActor
class MockFrameWindowFactory: FrameWindowFactory {
    func createFrameWindow(geometry: FrameGeometry) -> FrameWindowProtocol {
        return MockFrameWindow()
    }
}
