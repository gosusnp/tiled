# SPDX-License-Identifier: MIT
# Copyright (c) 2025 Jimmy Ma

build:
	make -C GosuTile build

run:
	make -C GosuTile run

watch-run:
	watchexec -r -e swift -w GosuTile/Sources make run
