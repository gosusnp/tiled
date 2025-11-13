// SPDX-License-Identifier: MIT
// Copyright (c) 2025 Jimmy Ma

import Cocoa

// NOTE: This class manages the tab order and active window state for a frame's windows.
// Consider merging into FrameController in the future:
// - WindowStackController only serves FrameController (no independent purpose)
// - FrameController already owns WindowStackController instances
// - There's bidirectional coupling: windows have frame references, frames manipulate window state
// - The abstraction boundary feels artificial and doesn't provide real separation of concerns

@MainActor
class WindowStackController {
    private let styleProvider: StyleProvider
    private var windowIds: [WindowId] = []
    private(set) var activeIndex: Int = 0

    init(styleProvider: StyleProvider) {
        self.styleProvider = styleProvider
    }

    // Safe getters
    var count: Int {
        windowIds.count
    }

    var allWindowIds: [WindowId] {
        windowIds
    }

    var tabs: [WindowId] {
        windowIds
    }

    // Private accessor for active window ID
    private var activeWindowId: WindowId? {
        guard !windowIds.isEmpty && activeIndex < windowIds.count else { return nil }
        return windowIds[activeIndex]
    }

    // Query methods for active window
    func isActiveWindow(_ windowId: WindowId) -> Bool {
        guard !windowIds.isEmpty && activeIndex < windowIds.count else { return false }
        return windowIds[activeIndex] == windowId
    }

    func getActiveWindowId() -> WindowId? {
        return activeWindowId
    }

    // Window management
    func add(_ windowId: WindowId, shouldFocus: Bool = false) throws {
        // Validate no duplicates
        guard !windowIds.contains(where: { $0 == windowId }) else {
            throw WindowStackError.duplicateWindow
        }
        windowIds.append(windowId)
        if shouldFocus {
            activeIndex = windowIds.count - 1  // Make new window active
        }
    }

    func remove(_ windowId: WindowId) throws {
        guard let index = windowIds.firstIndex(where: { $0 == windowId }) else {
            throw WindowStackError.windowNotFound
        }
        windowIds.remove(at: index)

        // Update activeIndex if needed
        if activeIndex >= index && activeIndex > 0 {
            activeIndex -= 1
        }
    }

    func takeAll(from other: WindowStackController) throws {
        for windowId in other.allWindowIds {
            try self.add(windowId)
        }
        other.windowIds = []
        other.activeIndex = 0
    }

    // Window cycling
    func nextWindow() -> WindowId? {
        guard !windowIds.isEmpty else { return nil }

        // Move to next position
        activeIndex = (activeIndex + 1) % windowIds.count

        // Skip/remove invalid windows at current position until we find a valid one
        while !windowIds.isEmpty {
            // Ensure activeIndex is within bounds before accessing
            if activeIndex >= windowIds.count {
                activeIndex = activeIndex % windowIds.count
            }

            // Check if current window is valid
            if windowIds[activeIndex].isValid {
                break  // Found a valid window
            }

            // Invalid window, remove it
            windowIds.remove(at: activeIndex)
        }

        guard !windowIds.isEmpty && activeIndex < windowIds.count else { return nil }
        return windowIds[activeIndex]
    }

    func previousWindow() -> WindowId? {
        guard !windowIds.isEmpty else { return nil }

        // Move to previous position
        activeIndex = activeIndex == 0 ? windowIds.count - 1 : activeIndex - 1

        // Skip/remove invalid windows at current position until we find a valid one
        while !windowIds.isEmpty {
            // Ensure activeIndex is within bounds before accessing
            if activeIndex >= windowIds.count {
                activeIndex = windowIds.count - 1
            }

            // Check if current window is valid
            if windowIds[activeIndex].isValid {
                break  // Found a valid window
            }

            // Invalid window, remove it
            let removedIndex = activeIndex
            windowIds.remove(at: removedIndex)

            if windowIds.isEmpty {
                return nil
            }

            // After removing at removedIndex, we need to continue going backward
            // The element that was at removedIndex+1 is now at removedIndex
            // But we want to go backward, so we need to check the previous element
            if removedIndex == 0 {
                // We just removed the first element, so go to the end
                activeIndex = windowIds.count - 1
            } else {
                // Otherwise, go to the element before where we just removed
                activeIndex = removedIndex - 1
            }
        }

        guard !windowIds.isEmpty && activeIndex < windowIds.count else { return nil }
        return windowIds[activeIndex]
    }

    // Window shifting
    func shiftActiveLeft() {
        guard activeIndex > 0 else { return }
        windowIds.swapAt(activeIndex, activeIndex - 1)
        activeIndex -= 1
    }

    func shiftActiveRight() {
        guard activeIndex < windowIds.count - 1 else { return }
        windowIds.swapAt(activeIndex, activeIndex + 1)
        activeIndex += 1
    }
}

enum WindowStackError: Error {
    case duplicateWindow
    case windowNotFound
}
