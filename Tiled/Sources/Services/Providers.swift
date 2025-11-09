// SPDX-License-Identifier: MIT
// Copyright (c) 2025 Jimmy Ma

import Cocoa
import ApplicationServices

// MARK: - Workspace Provider Protocol

/// Protocol for accessing workspace and running applications
/// Allows mocking NSWorkspace for testing
protocol WorkspaceProvider {
    /// Get list of currently running applications
    var runningApplications: [NSRunningApplication] { get }

    /// Get the frontmost (currently focused) application
    var frontmostApplication: NSRunningApplication? { get }
}

// MARK: - Real Implementation

/// Default implementation using NSWorkspace
class RealWorkspaceProvider: WorkspaceProvider {
    var runningApplications: [NSRunningApplication] {
        NSWorkspace.shared.runningApplications
    }

    var frontmostApplication: NSRunningApplication? {
        NSWorkspace.shared.frontmostApplication
    }
}

