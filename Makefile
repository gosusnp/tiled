# SPDX-License-Identifier: MIT
# Copyright (c) 2025 Jimmy Ma

build:
	make -C Tiled build

run:
	make -C Tiled run

test:
	make -C Tiled test

test-with-coverage:
	make -C Tiled test-with-coverage

watch-run:
	watchexec -r -e swift -w Tiled/Sources make run

watch-test:
	watchexec -r -e swift -w Tiled/Sources -w Tiled/Tests make test
