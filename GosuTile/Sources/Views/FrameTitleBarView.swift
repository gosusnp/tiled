// SPDX-License-Identifier: MIT
// Copyright (c) 2025 Jimmy Ma

import Cocoa

// MARK: - Tabs
class FrameTitleBarTabView: NSView {
    private let title: String
    private let style: Style

    init(frame: NSRect, title: String, style: Style) {
        self.title = title
        self.style = style
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
    func setupTabs(tabs: [WindowTab]) {
        // Clear existing subviews
        self.subviews.forEach { $0.removeFromSuperview() }

        guard !tabs.isEmpty else { return }

        let tabWidth = self.bounds.width / CGFloat(tabs.count)
        let tabHeight = self.bounds.height

        for (index, tab) in tabs.enumerated() {
            let tabRect = NSRect(
                x: self.bounds.minX + CGFloat(index) * tabWidth,
                y: self.bounds.minY,
                width: tabWidth,
                height: tabHeight
            )

            let tab = FrameTitleBarTabView(
                frame: tabRect,
                title: tab.title,
                style: tab.style,
            )

            addSubview(tab)
        }
    }
}
