// SPDX-License-Identifier: MIT
// Copyright (c) 2025 Jimmy Ma

import Cocoa

// MARK: - Tabs
class FrameTitleBarTabView: NSView {
    private let title: String
    private let isActive: Bool
    private let styleProvider: StyleProvider

    private var style: Style {
        styleProvider.getStyle(isActive: isActive)
    }

    init(frame: NSRect, title: String, isActive: Bool, styleProvider: StyleProvider) {
        self.title = title
        self.isActive = isActive
        self.styleProvider = styleProvider
        super.init(frame: frame)

        self.wantsLayer = true
        setupAppearance()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupAppearance() {
        // Tab background colors
        self.layer?.backgroundColor = style.backgroundColor.cgColor

        // Rounded top corners
        self.layer?.cornerRadius = style.cornerRadius
        self.layer?.maskedCorners = style.cornerMask

        // Border
        self.layer?.borderWidth = style.borderWidth
        self.layer?.borderColor = style.borderColor.cgColor
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        // Draw title text
        let attributes: [NSAttributedString.Key: Any] = [
            .font: self.style.font,
            .foregroundColor: self.style.foregroundColor,
        ]

        let attributedTitle = NSAttributedString(string: self.title, attributes: attributes)
        let textSize = attributedTitle.size()

        // Center text in tab
        let textRect = NSRect(
            x: (self.bounds.width - textSize.width) / 2,
            y: (self.bounds.height - textSize.height) / 2,
            width: textSize.width,
            height: textSize.height,
        )

        attributedTitle.draw(in: textRect)
    }
}

class FrameTitleBarView: NSView {
    private let geometry: FrameGeometry
    private let styleProvider: StyleProvider

    init(geometry: FrameGeometry, styleProvider: StyleProvider) {
        self.geometry = geometry
        self.styleProvider = styleProvider
        super.init(frame: .zero)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func setupTabs(tabs: [WindowTab]) {
        // Clear existing subviews
        self.subviews.forEach { $0.removeFromSuperview() }

        let tabsToDisplay = !tabs.isEmpty ? tabs : [WindowTab(title: "", isActive: false)]
        let tabCount = CGFloat(tabsToDisplay.count)

        guard tabCount > 0 else { return }

        let totalWidth = self.geometry.titleBarRect.width
        guard totalWidth > 0 else { return }

        let tabWidth = totalWidth / tabCount
        let tabHeight = self.geometry.titleBarHeight

        for (index, tab) in tabsToDisplay.enumerated() {
            let tabRect = NSRect(
                x: CGFloat(index) * tabWidth,
                y: 0,
                width: tabWidth,
                height: tabHeight
            )

            let tabView = FrameTitleBarTabView(
                frame: tabRect,
                title: tab.title,
                isActive: tab.isActive,
                styleProvider: styleProvider
            )

            addSubview(tabView)
        }
    }
}
