.PHONY: help test build release lint quality fixtures release-manifest privacy-matrix coverage release-preflight clean

APP_NAME := PageLumen
SCHEME := PageLumen

help:
	@echo "Available targets:"
	@echo "  make test      - run swift test"
	@echo "  make build     - build the app (Debug)"
	@echo "  make release   - build the app (Release) and produce an archive"
	@echo "  make lint      - run swift test + release build"
	@echo "  make quality   - run local privacy, artifact, and whitespace gates"
	@echo "  make fixtures  - validate the versioned fixture and AI evaluation manifests"
	@echo "  make release-manifest - validate the unsigned CI/release evidence contract"
	@echo "  make coverage  - run tests with LLVM coverage and write a risk report"
	@echo "  make release-preflight - check local archive/signing prerequisites"
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

quality:
	./script/quality_gates.sh

offline-dependencies:
	./script/validate_offline_dependencies.sh

fixtures:
	./script/validate_fixture_corpus.sh

release-manifest:
	./script/validate_release_manifest.sh

privacy-matrix:
	./script/validate_privacy_matrix.sh

coverage:
	./script/coverage_report.sh

release-preflight:
	./script/release_preflight.sh

clean:
	rm -rf .build dist DerivedData
