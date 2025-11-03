// SPDX-License-Identifier: MIT
// Copyright (c) 2025 Jimmy Ma

enum NavigationDirection {
    case left
    case right
    case up
    case down
}

@MainActor
class FrameNavigationService {
    /// Finds the adjacent frame in the specified direction using tree traversal.
    /// Returns nil if no adjacent frame exists (at boundary).
    func findAdjacentFrame(from frame: FrameController, direction: NavigationDirection) -> FrameController? {
        // Walk up the tree to find an ancestor split in the appropriate direction
        var current = frame

        while let parent = current.parent {
            let childIndex = getChildIndex(of: current, in: parent)
            guard childIndex >= 0 else { return nil }

            // Check the parent's split direction
            guard let parentSplitDirection = parent.splitDirection else { return nil }

            // Determine if we can navigate in this direction from this ancestor
            let canNavigate = shouldNavigate(direction: direction, childIndex: childIndex, parentSplitDirection: parentSplitDirection)

            if canNavigate {
                // Enter the opposite subtree
                let oppositeChild = parent.children[1 - childIndex]
                // Descend to leaf
                return descendToLeaf(from: oppositeChild)
            }

            // Continue walking up
            current = parent
        }

        // No suitable ancestor found (at boundary)
        return nil
    }

    /// Determines which child index the frame is in its parent.
    /// Returns -1 if frame is not found in parent's children.
    private func getChildIndex(of frame: FrameController, in parent: FrameController) -> Int {
        if parent.children.count >= 2 {
            if parent.children[0] === frame {
                return 0
            } else if parent.children[1] === frame {
                return 1
            }
        }
        return -1
    }

    /// Determines if we can navigate in the given direction given our position as a child and parent's split direction.
    /// For binary splits:
    /// - Child 0 is left/top, Child 1 is right/bottom
    /// - Vertical split: child 0 is left, child 1 is right (side-by-side)
    /// - Horizontal split: child 0 is top, child 1 is bottom (stacked)
    private func shouldNavigate(direction: NavigationDirection, childIndex: Int, parentSplitDirection: Direction) -> Bool {
        switch direction {
        case .left:
            // Need vertical split and be on the right (child 1)
            return parentSplitDirection == .Vertical && childIndex == 1
        case .right:
            // Need vertical split and be on the left (child 0)
            return parentSplitDirection == .Vertical && childIndex == 0
        case .up:
            // Need horizontal split and be on the bottom (child 1)
            return parentSplitDirection == .Horizontal && childIndex == 1
        case .down:
            // Need horizontal split and be on the top (child 0)
            return parentSplitDirection == .Horizontal && childIndex == 0
        }
    }

    /// Recursively descends the tree to find a leaf frame (frame with no children).
    /// Always takes the first child (leftmost/topmost).
    private func descendToLeaf(from frame: FrameController) -> FrameController {
        if frame.children.isEmpty {
            return frame
        }
        return descendToLeaf(from: frame.children[0])
    }
}
