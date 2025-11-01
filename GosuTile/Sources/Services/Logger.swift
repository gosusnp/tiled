// SPDX-License-Identifier: MIT
// Copyright (c) 2025 Jimmy Ma

import os

// MARK: - Logger
class Logger {
    let logger = os.Logger(subsystem: "com.snp.GosuTile", category: "main")

    init() {}

    // Control console output during development
    private static let consoleOutput: Bool = {
        #if DEBUG
        return true
        #else
        return ProcessInfo.processInfo.environment["CONSOLE_LOGGING"] != nil
        #endif
    }()

    func debug(_ message: String) {
        if Self.consoleOutput {
            print("debug: \(message)")
        }
        logger.debug("\(message)")
    }

    func error(_ message: String) {
        if Self.consoleOutput {
            print("error: \(message)")
        }
        logger.error("\(message)")
    }

    func info(_ message: String) {
        if Self.consoleOutput {
            print(message)
        }
        logger.info("\(message)")
    }

    func warning(_ message: String) {
        if Self.consoleOutput {
            print("warn: \(message)")
        }
        logger.warning("\(message)")
    }
}
