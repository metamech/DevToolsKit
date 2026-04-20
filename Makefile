.PHONY: build test lint demo frameworks frameworks-clean frameworks-licensingseat

build:
	swift build

test:
	swift test

lint:
	swift-format lint --recursive Sources/ Tests/
	swiftlint lint

demo:
	cd Examples/DevToolsKitDemo && swift run

# ---------------------------------------------------------------------------
# XCFrameworks
# ---------------------------------------------------------------------------
# Produces prebuilt XCFrameworks for every DevToolsKit product. See
# Scripts/build-xcframeworks.swift and README "Building xcframeworks".
# DevToolsKitLicensingSeat.xcframework statically bundles LicenseSeat (#74) —
# consumers must NOT separately link a LicenseSeat.xcframework (duplicate
# symbols). See Licenses/LicenseSeat-LICENSE.txt for attribution.

frameworks:
	swift Scripts/build-xcframeworks.swift --all

frameworks-clean:
	rm -rf Frameworks
	rm -rf .build

# Build only DevToolsKitLicensingSeat.xcframework — the #74 smoke-test entry
# point, bundles LicenseSeat statically.
frameworks-licensingseat:
	swift Scripts/build-xcframeworks.swift --product DevToolsKitLicensingSeat

# Per-product helper: `make frameworks-foo` → builds product "Foo". Pattern
# rule delegates to the script's --product filter. Product names are the
# lower-cased suffix after "DevToolsKit"; the script accepts the exact product
# name declared in Package.swift, so callers pass that explicitly instead.
#
# Example: make frameworks-PRODUCT PRODUCT=DevToolsKitLogging
frameworks-PRODUCT:
	@if [ -z "$(PRODUCT)" ]; then \
		echo "Usage: make frameworks-PRODUCT PRODUCT=<product-name>"; \
		exit 1; \
	fi
	swift Scripts/build-xcframeworks.swift --product $(PRODUCT)
