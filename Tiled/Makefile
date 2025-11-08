# SPDX-License-Identifier: MIT
# Copyright (c) 2025 Jimmy Ma

SWIFT_TEST_OPTIONS=--disable-xctest --enable-swift-testing

build:
	swift build

run:
	swift run

test:
	swift test $(SWIFT_TEST_OPTIONS)

test-with-coverage:
	swift test $(SWIFT_TEST_OPTIONS) --enable-code-coverage

test-integration:
	swift test $(SWIFT_TEST_OPTIONS) --filter "TiledIntegrationTests"

test-unit:
	swift test $(SWIFT_TEST_OPTIONS) --filter "TiledTests"
