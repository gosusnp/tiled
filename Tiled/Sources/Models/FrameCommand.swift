// SPDX-License-Identifier: MIT
// Copyright (c) 2025 Jimmy Ma

import Foundation
import ApplicationServices

/// Commands that mutate frame state through the command queue.
enum FrameCommand {
    // Frame operations
    case splitVertically
    case splitHorizontally
    case closeFrame

    // Navigation
    case navigateLeft
    case navigateRight
    case navigateUp
    case navigateDown

    // Window movement
    case moveWindowLeft
    case moveWindowRight
    case moveWindowUp
    case moveWindowDown

    // Window cycling
    case cycleWindowForward
    case cycleWindowBackward

    // Window reordering
    case shiftWindowLeft
    case shiftWindowRight

    // Window management
    case addWindow(WindowControllerProtocol)
    case removeWindow(WindowControllerProtocol)
    case focusWindow(WindowControllerProtocol)

    // Window lifecycle events
    case windowAppeared(WindowControllerProtocol, WindowId)
    case windowDisappeared(WindowId)
}
