// SPDX-License-Identifier: MIT
// Copyright (c) 2025 Jimmy Ma

import Cocoa

@MainActor
class WindowStackController {
    private let styleProvider: StyleProvider
    private var windows: [WindowControllerProtocol] = []
    private(set) var activeIndex: Int = 0

    init(styleProvider: StyleProvider) {
        self.styleProvider = styleProvider
    }

    // Safe getters
    var activeWindow: WindowControllerProtocol? {
        guard !windows.isEmpty && activeIndex < windows.count else { return nil }
        return windows[activeIndex]
    }

    var count: Int {
        windows.count
    }

    var all: [WindowControllerProtocol] {
        windows
    }

    var tabs: [WindowTab] {
        self.all.enumerated().map { (index, window) in
            let isActive = index == self.activeIndex
            return WindowTab(
                title: window.title,
                isActive: isActive,
            )
        }
    }

    // Window management
    func add(_ window: WindowControllerProtocol, shouldFocus: Bool = false) throws {
        // Validate no duplicates
        guard !windows.contains(where: { $0 === window }) else {
            throw WindowStackError.duplicateWindow
        }
        windows.append(window)
        if shouldFocus {
            activeIndex = windows.count - 1  // Make new window active
        }
    }

    func remove(_ window: WindowControllerProtocol) -> Bool {
        guard let index = windows.firstIndex(where: { $0 === window }) else {
            return false
        }
        windows.remove(at: index)

        // Update activeIndex if needed
        if activeIndex >= windows.count && !windows.isEmpty {
            activeIndex = windows.count - 1
        } else if activeIndex > index {
            activeIndex -= 1
        }
        return true
    }

    func takeAll(from other: WindowStackController) throws {
        for window in other.all {
            try self.add(window)
        }
        other.windows = []
        other.activeIndex = 0
    }

    // Window cycling
    func nextWindow() {
        guard !windows.isEmpty else { return }
        activeIndex = (activeIndex + 1) % windows.count
        activeWindow?.raise()
    }

    func previousWindow() {
        guard !windows.isEmpty else { return }
        activeIndex = activeIndex == 0 ? windows.count - 1 : activeIndex - 1
        activeWindow?.raise()
    }
}

enum WindowStackError: Error {
    case duplicateWindow
}
