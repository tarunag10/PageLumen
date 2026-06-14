.PHONY: help test build release lint clean

APP_NAME := PageLumen
SCHEME := PageLumen

help:
	@echo "Available targets:"
	@echo "  make test      - run swift test"
	@echo "  make build     - build the app (Debug)"
	@echo "  make release   - build the app (Release) and produce an archive"
	@echo "  make lint      - run swift test + release build"
	@echo "  make clean     - remove .build, dist, DerivedData"

test:
	swift test

build:
	swift build

release:
	./script/package_release.sh

lint:
	swift test
	./script/package_release.sh

clean:
	rm -rf .build dist DerivedData
