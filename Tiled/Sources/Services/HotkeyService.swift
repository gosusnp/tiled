// SPDX-License-Identifier: MIT
// Copyright (c) 2025 Jimmy Ma

import Cocoa
import Carbon

class HotkeyService: @unchecked Sendable {
    enum Key: Equatable {
        case character(String)
        case keyCode(Int64)

        static func from(event: CGEvent) -> Key? {
            let keyCode = event.getIntegerValueField(.keyboardEventKeycode)

            // Try to get character representation
            if let nsEvent = NSEvent(cgEvent: event),
               let chars = nsEvent.charactersIgnoringModifiers?.lowercased(),
               !chars.isEmpty {
                return .character(chars)
            }

            return .keyCode(keyCode)
        }
    }

    struct Shortcut: Sendable {
        let steps: [(key: Key, modifiers: CGEventFlags)]
        let action: @Sendable () -> Void
        let description: String
    }

    let logger: Logger
    private(set) var shortcuts: [Shortcut] = []

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var contextPointer: UnsafeMutablePointer<DispatchQueue>?
    private let queue = DispatchQueue(label: "com.hotkey.sequence", qos: .userInteractive)
    private var sequenceBuffer: [(key: Key, modifiers: CGEventFlags)] = []
    private var sequenceTimer: DispatchSourceTimer?
    private let sequenceTimeout: TimeInterval = 1.5
    private let relevantModifiers: CGEventFlags = [.maskCommand, .maskShift, .maskAlternate, .maskControl]

    init(logger: Logger) {
        self.logger = logger
        setupEventTap()
    }

    deinit {
        // Cleanup is handled via stopMonitoring() which should be called explicitly
        // or triggered through HotkeyController's deinit
    }

    // MARK: - Shortcut Management
    func addShortcut(steps: [(key: Key, modifiers: CGEventFlags)],
                     description: String,
                     action: @escaping @Sendable () -> Void) {
        self.logger.debug("Bound: \(description)")
        self.shortcuts.append(Shortcut(steps: steps, action: action, description: description))
    }

    // MARK: - Event Tap Setup
    private func setupEventTap() {
        let eventMask = (1 << CGEventType.keyDown.rawValue)

        // Create a context that holds our queue for thread-safe access
        let context = UnsafeMutablePointer<DispatchQueue>.allocate(capacity: 1)
        context.initialize(to: queue)

        guard let eventTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(eventMask),
            callback: { (proxy, type, event, refcon) -> Unmanaged<CGEvent>? in
                guard let refcon = refcon else { return Unmanaged.passRetained(event) }

                let queue = refcon.assumingMemoryBound(to: DispatchQueue.self).pointee

                // Handle on our serial queue to avoid data races
                var shouldBlock = false
                queue.sync {
                    shouldBlock = HotkeyService.handleEventStatic(type: type, event: event)
                }

                return shouldBlock ? nil : Unmanaged.passRetained(event)
            },
            userInfo: UnsafeMutableRawPointer(context)
        ) else {
            self.logger.error(
                "Failed to create event tap. Make sure Accessibility permissions are granted."
            )
            context.deinitialize(count: 1)
            context.deallocate()
            return
        }

        self.eventTap = eventTap
        self.contextPointer = context

        let runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: eventTap, enable: true)

        self.runLoopSource = runLoopSource

        // Set up shared state accessor
        HotkeyService.sharedLock.lock()
        HotkeyService.shared = self
        HotkeyService.sharedLock.unlock()

        self.logger.debug("Event tap created successfully")
    }

    // MARK: - Static handler for C callback
    nonisolated private static let sharedLock = NSLock()
    nonisolated(unsafe) private static var shared: HotkeyService?

    nonisolated private static func handleEventStatic(type: CGEventType, event: CGEvent) -> Bool {
        guard type == .keyDown else { return false }

        sharedLock.lock()
        let observer = shared
        sharedLock.unlock()

        guard let observer = observer else { return false }

        return observer.handleEventSync(event: event)
    }

    private func handleEventSync(event: CGEvent) -> Bool {
        guard let key = Key.from(event: event) else {
            return false
        }

        let modifiers = event.flags.intersection(relevantModifiers)

        // Add to sequence buffer
        sequenceBuffer.append((key, modifiers))

        // Reset timer
        resetTimer()

        // Check if any shortcut matches
        if let matchedShortcut = findMatchingShortcut() {
            Task { @MainActor in
                matchedShortcut.action()
            }
            scheduleResetSequence()
            return true // Block the event
        }

        // Check if current sequence could be a prefix of any shortcut
        if isValidPrefix() {
            return true // Block the event, waiting for more keys
        }

        // Not a valid sequence, reset and pass through
        scheduleResetSequence()
        return false
    }

    private func resetTimer() {
        sequenceTimer?.cancel()

        let timer = DispatchSource.makeTimerSource(queue: queue)
        timer.schedule(deadline: .now() + sequenceTimeout)
        timer.setEventHandler { [weak self] in
            self?.resetSequence()
        }
        timer.resume()
        sequenceTimer = timer
    }

    private func stepMatches(_ step: (key: Key, modifiers: CGEventFlags), bufferStep: (key: Key, modifiers: CGEventFlags)) -> Bool {
        if step.key != bufferStep.key {
            return false
        }

        let requiredModifiers = step.modifiers.intersection(relevantModifiers)
        let actualModifiers = bufferStep.modifiers.intersection(relevantModifiers)

        return requiredModifiers == actualModifiers
    }

    private func findMatchingShortcut() -> Shortcut? {
        return shortcuts.first { shortcut in
            guard shortcut.steps.count == sequenceBuffer.count else { return false }

            for (index, step) in shortcut.steps.enumerated() {
                if !self.stepMatches(step, bufferStep: self.sequenceBuffer[index]) {
                    return false
                }
            }
            return true
        }
    }

    private func isValidPrefix() -> Bool {
        return shortcuts.contains { shortcut in
            guard shortcut.steps.count >= sequenceBuffer.count else { return false }

            for (index, bufferStep) in sequenceBuffer.enumerated() {
                if !self.stepMatches(shortcut.steps[index], bufferStep: bufferStep) {
                    return false
                }
            }
            return true
        }
    }

    private func resetSequence() {
        sequenceBuffer.removeAll()
        sequenceTimer?.cancel()
        sequenceTimer = nil
    }

    private func scheduleResetSequence() {
        let weakSelf: HotkeyService? = self
        queue.async {
            guard let self = weakSelf else { return }
            self.resetSequence()
        }
    }

    func stopMonitoring() {
        queue.sync {
            if let eventTap = eventTap {
                CGEvent.tapEnable(tap: eventTap, enable: false)
                CFMachPortInvalidate(eventTap)
                self.eventTap = nil
            }

            if let runLoopSource = runLoopSource {
                CFRunLoopRemoveSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
                self.runLoopSource = nil
            }

            // Clean up context pointer
            if let context = contextPointer {
                context.deinitialize(count: 1)
                context.deallocate()
                self.contextPointer = nil
            }

            sequenceTimer?.cancel()
            sequenceTimer = nil
        }

        // Clean up shared reference
        HotkeyService.sharedLock.lock()
        HotkeyService.shared = nil
        HotkeyService.sharedLock.unlock()
    }
}
