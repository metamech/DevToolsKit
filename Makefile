.PHONY: build test lint demo

build:
	swift build

test:
	swift test

lint:
	swift-format lint --recursive Sources/ Tests/
	swiftlint lint

demo:
	cd Examples/DevToolsKitDemo && swift run
