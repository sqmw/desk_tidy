FVM ?= fvm
FLUTTER := $(FVM) flutter
PUB := $(FLUTTER) pub

PY := python

PACKAGE_VERSION := $(shell $(PY) - <<'PY'
import pathlib, re, sys
text = pathlib.Path('pubspec.yaml').read_text()
match = re.search(r'^version:\\s*(\\S+)', text, re.MULTILINE)
print(match.group(1) if match else '0.0.1+0')
PY)

PACKAGE_VERSION_SHORT := $(shell $(PY) - <<'PY'
import pathlib, re, sys
text = pathlib.Path('pubspec.yaml').read_text()
match = re.search(r'^version:\\s*(\\S+)', text, re.MULTILINE)
if match:
    print(match.group(1).split('+')[0])
else:
    print('0.0.1')
PY)

BUILD_DIR ?= build/windows/x64/runner/Release
INSTALLER_DIR ?= build/installer
INNO_SCRIPT ?= installers/desk_tidy.iss
INNO_SETUP ?= iscc

.PHONY: help setup deps run analyze test fmt clean clean-all build-windows-release package count-loc

help:
	@echo "Targets:"
	@echo "  setup             Install Dart/Flutter deps (runs pub get via fvm)"
	@echo "  run               Launch the app on the connected Windows device/emulator"
	@echo "  analyze           Run the static analyzer"
	@echo "  test              Execute the Flutter test suite"
	@echo "  fmt               Format Dart sources under lib/, bin/, and test/"
	@echo "  clean             Clean Flutter build artifacts"
	@echo "  clean-all         Clean and remove macOS caches ($$FLUTTER_HOME etc.)"
	@echo "  build-windows-release"
	@echo "                    Produce the Windows release bundle"
	@echo "  package           Build release bundle then run Inno Setup (respecting version overrides)"
	@echo "  count-loc         Count Dart LOC under lib/ (uses bin/count_lib_loc.dart)"

setup:
	$(PUB) get

deps: setup

run:
	$(FLUTTER) run -d windows

analyze:
	$(FLUTTER) analyze

test:
	$(FLUTTER) test

fmt:
	$(FVM) dart format lib bin test

clean:
	$(FLUTTER) clean

clean-all: clean
	$(FLUTTER) precache --clear

build-windows-release:
	$(FLUTTER) build windows --release

package: build-windows-release
	$(INNO_SETUP) $(INNO_SCRIPT) /dMyAppVersion=$(PACKAGE_VERSION_SHORT) /dMyBuildDir=$(BUILD_DIR) /dMyOutputDir=$(INSTALLER_DIR)

count-loc:
	$(FVM) dart run bin/count_lib_loc.dart
