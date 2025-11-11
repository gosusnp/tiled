// SPDX-License-Identifier: MIT
// Copyright (c) 2025 Jimmy Ma

import Foundation

// MARK: - Space

/// Represents a macOS Space/Desktop.
/// Each Space has an invisible marker window that allows detection via CGWindow API.
struct Space {
    /// Unique identifier for this Space
    let id: UUID

    /// Window number of the invisible marker window for this Space
    let markerWindowNumber: Int

    init(id: UUID = UUID(), markerWindowNumber: Int) {
        self.id = id
        self.markerWindowNumber = markerWindowNumber
    }
}
