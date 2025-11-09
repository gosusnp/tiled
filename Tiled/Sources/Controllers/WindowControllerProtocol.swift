// SPDX-License-Identifier: MIT
// Copyright (c) 2025 Jimmy Ma

import Cocoa

/// Protocol for window manipulation operations.
/// This allows for testing with mocks that don't actually move real windows.
protocol WindowControllerProtocol: AnyObject {
    var windowId: WindowId { get }

    /// Raise the window to the front and focus it
    func raise()

    /// Reposition the window to a specific frame (move and resize atomically)
    func reposition(to rect: CGRect) throws
}
