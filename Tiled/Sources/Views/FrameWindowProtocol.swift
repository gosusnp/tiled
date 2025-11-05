// SPDX-License-Identifier: MIT
// Copyright (c) 2025 Jimmy Ma

import Cocoa

@MainActor
protocol FrameWindowProtocol {
    func updateOverlay(tabs: [WindowTab])
    func clear()
    func setActive(_ isActive: Bool)
    func hide()
    func show()
    func close()
}
