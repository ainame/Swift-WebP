SHELL := /bin/sh

.PHONY: format lint

SWIFT_FORMAT_PATHS := Sources Tests Package.swift Benchmark Demo Scripts

format:
	swift format --in-place --recursive $(SWIFT_FORMAT_PATHS)

lint:
	swift format lint --strict --recursive $(SWIFT_FORMAT_PATHS)
