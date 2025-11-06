// SPDX-License-Identifier: MIT
// Copyright (c) 2025 Jimmy Ma

import Cocoa
import Testing
@testable import Tiled

@Suite("FrameNavigationService Tests")
@MainActor
struct FrameNavigationServiceTests {
    let config: ConfigController
    let testFrame: CGRect
    let service: FrameNavigationService
    let mockFactory: MockFrameWindowFactory

    init() {
        self.config = ConfigController()
        self.testFrame = CGRect(x: 0, y: 0, width: 1920, height: 1080)
        self.service = FrameNavigationService()
        self.mockFactory = MockFrameWindowFactory()
    }

    private func createTestFrame(rect: CGRect = CGRect(x: 0, y: 0, width: 1920, height: 1080)) -> FrameController {
        FrameController(rect: rect, config: config, windowFactory: mockFactory)
    }

    // MARK: - Vertical Split Tests (creates left/right frames)

    @Test("Navigates right from left child after vertical split")
    func testNavigateRightFromLeftChild() throws {
        let root = createTestFrame()
        _ = try root.split(direction: .Vertical)
        let leftChild = root.children[0]
        let rightChild = root.children[1]

        let result = service.findAdjacentFrame(from: leftChild, direction: .right)
        #expect(result === rightChild)
    }

    @Test("Navigates left from right child after vertical split")
    func testNavigateLeftFromRightChild() throws {
        let root = createTestFrame()
        _ = try root.split(direction: .Vertical)
        let leftChild = root.children[0]
        let rightChild = root.children[1]

        let result = service.findAdjacentFrame(from: rightChild, direction: .left)
        #expect(result === leftChild)
    }

    @Test("Returns nil when navigating left from left child")
    func testNavigateLeftFromLeftChildReturnsNil() throws {
        let root = createTestFrame()
        _ = try root.split(direction: .Vertical)
        let leftChild = root.children[0]

        let result = service.findAdjacentFrame(from: leftChild, direction: .left)
        #expect(result == nil)
    }

    @Test("Returns nil when navigating right from right child")
    func testNavigateRightFromRightChildReturnsNil() throws {
        let root = createTestFrame()
        _ = try root.split(direction: .Vertical)
        let rightChild = root.children[1]

        let result = service.findAdjacentFrame(from: rightChild, direction: .right)
        #expect(result == nil)
    }

    // MARK: - Horizontal Split Tests (creates top/bottom frames)

    @Test("Navigates down from top child after horizontal split")
    func testNavigateDownFromTopChild() throws {
        let root = createTestFrame()
        _ = try root.split(direction: .Horizontal)
        let topChild = root.children[0]
        let bottomChild = root.children[1]

        let result = service.findAdjacentFrame(from: topChild, direction: .down)
        #expect(result === bottomChild)
    }

    @Test("Navigates up from bottom child after horizontal split")
    func testNavigateUpFromBottomChild() throws {
        let root = createTestFrame()
        _ = try root.split(direction: .Horizontal)
        let topChild = root.children[0]
        let bottomChild = root.children[1]

        let result = service.findAdjacentFrame(from: bottomChild, direction: .up)
        #expect(result === topChild)
    }

    @Test("Returns nil when navigating up from top child")
    func testNavigateUpFromTopChildReturnsNil() throws {
        let root = createTestFrame()
        _ = try root.split(direction: .Horizontal)
        let topChild = root.children[0]

        let result = service.findAdjacentFrame(from: topChild, direction: .up)
        #expect(result == nil)
    }

    @Test("Returns nil when navigating down from bottom child")
    func testNavigateDownFromBottomChildReturnsNil() throws {
        let root = createTestFrame()
        _ = try root.split(direction: .Horizontal)
        let bottomChild = root.children[1]

        let result = service.findAdjacentFrame(from: bottomChild, direction: .down)
        #expect(result == nil)
    }

    // MARK: - Nested Splits (V then H)

    @Test("Navigates right across nested split (V then H)")
    func testNavigateRightAcrossNestedVH() throws {
        // Split vertically: root -> left, right
        let root = createTestFrame()
        _ = try root.split(direction: .Vertical)
        let left = root.children[0]
        let right = root.children[1]

        // Split left horizontally: left -> topLeft, bottomLeft
        _ = try left.split(direction: .Horizontal)
        let topLeft = left.children[0]
        let bottomLeft = left.children[1]

        // From topLeft, navigate right -> should reach right
        let result = service.findAdjacentFrame(from: topLeft, direction: .right)
        #expect(result === right)

        // From bottomLeft, navigate right -> should reach right
        let resultFromBottom = service.findAdjacentFrame(from: bottomLeft, direction: .right)
        #expect(resultFromBottom === right)
    }

    // MARK: - Nested Splits (H then V)

    @Test("Navigates down across nested split (H then V)")
    func testNavigateDownAcrossNestedHV() throws {
        // Split horizontally: root -> top, bottom
        let root = createTestFrame()
        _ = try root.split(direction: .Horizontal)
        let top = root.children[0]
        let bottom = root.children[1]

        // Split top vertically: top -> topLeft, topRight
        _ = try top.split(direction: .Vertical)
        let topLeft = top.children[0]
        let topRight = top.children[1]

        // From topLeft, navigate down -> should reach bottom
        let result = service.findAdjacentFrame(from: topLeft, direction: .down)
        #expect(result === bottom)

        // From topRight, navigate down -> should reach bottom
        let resultFromRight = service.findAdjacentFrame(from: topRight, direction: .down)
        #expect(resultFromRight === bottom)
    }

    // MARK: - Complex 4-Way Split

    @Test("Navigates in 4-way split (V then H on both sides)")
    func testNavigateIn4WaySplit() throws {
        // V: root -> left, right
        let root = createTestFrame()
        _ = try root.split(direction: .Vertical)
        let left = root.children[0]
        let right = root.children[1]

        // H on left: left -> topLeft, bottomLeft
        _ = try left.split(direction: .Horizontal)
        let topLeft = left.children[0]
        let bottomLeft = left.children[1]

        // H on right: right -> topRight, bottomRight
        _ = try right.split(direction: .Horizontal)
        let topRight = right.children[0]
        let bottomRight = right.children[1]

        // Test: topLeft right -> topRight (descend to first leaf in right subtree)
        let result1 = service.findAdjacentFrame(from: topLeft, direction: .right)
        #expect(result1 === topRight)

        // Test: topLeft down -> bottomLeft
        #expect(service.findAdjacentFrame(from: topLeft, direction: .down) === bottomLeft)

        // Test: topRight left -> topLeft (descend to first leaf in left subtree)
        let result3 = service.findAdjacentFrame(from: topRight, direction: .left)
        #expect(result3 === topLeft)

        // Test: bottomRight up -> topRight
        #expect(service.findAdjacentFrame(from: bottomRight, direction: .up) === topRight)

        // Test: bottomLeft right -> topRight (descend to first leaf in right subtree)
        let result5 = service.findAdjacentFrame(from: bottomLeft, direction: .right)
        #expect(result5 === topRight)
    }

    // MARK: - Orthogonal Navigation (should return nil)

    @Test("Returns nil when navigating orthogonally to split direction")
    func testOrthogonalNavigationReturnsNil() throws {
        let root = createTestFrame()
        _ = try root.split(direction: .Vertical)
        let left = root.children[0]
        let right = root.children[1]

        // Vertical split, try to navigate up/down
        #expect(service.findAdjacentFrame(from: left, direction: .up) == nil)
        #expect(service.findAdjacentFrame(from: left, direction: .down) == nil)
        #expect(service.findAdjacentFrame(from: right, direction: .up) == nil)
        #expect(service.findAdjacentFrame(from: right, direction: .down) == nil)
    }

    // MARK: - Deep Nesting

    @Test("Navigates through deeply nested frame tree")
    func testNavigateThroughDeeplyNestedTree() throws {
        // Create: root -> (left1, right1) [vertical]
        let root = createTestFrame()
        _ = try root.split(direction: .Vertical)
        let left1 = root.children[0]
        let right1 = root.children[1]

        // Create: left1 -> (topLeft1, bottomLeft1) [horizontal]
        _ = try left1.split(direction: .Horizontal)
        let topLeft1 = left1.children[0]
        let bottomLeft1 = left1.children[1]

        // Create: topLeft1 -> (topLeftLeft, topLeftRight) [vertical]
        _ = try topLeft1.split(direction: .Vertical)
        let topLeftLeft = topLeft1.children[0]
        let topLeftRight = topLeft1.children[1]

        // From topLeftLeft, navigate right should reach topLeftRight
        #expect(service.findAdjacentFrame(from: topLeftLeft, direction: .right) === topLeftRight)

        // From topLeftRight, navigate right should skip over and reach right1
        let resultRight = service.findAdjacentFrame(from: topLeftRight, direction: .right)
        #expect(resultRight === right1)
    }

    // MARK: - No-op Navigations

    @Test("Root frame returns nil for all directions")
    func testRootFrameNavigationReturnsNil() throws {
        let root = createTestFrame()

        #expect(service.findAdjacentFrame(from: root, direction: .left) == nil)
        #expect(service.findAdjacentFrame(from: root, direction: .right) == nil)
        #expect(service.findAdjacentFrame(from: root, direction: .up) == nil)
        #expect(service.findAdjacentFrame(from: root, direction: .down) == nil)
    }
}
