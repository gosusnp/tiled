# SPDX-License-Identifier: MIT
# Copyright (c) 2025 Jimmy Ma

build:
	make -C GosuTile build

run:
	make -C GosuTile run

test:
	make -C GosuTile test

watch-run:
	watchexec -r -e swift -w GosuTile/Sources make run

watch-test:
	watchexec -r -e swift -w GosuTile/Sources -w GosuTile/Tests make test
